import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lankar/providers/entries_provider.dart';
import 'package:lankar/screens/books/cash_entry_screen.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/widgets/entry_card_widget.dart';
import 'package:lankar/widgets/entry_dialog_widget.dart';

class _Entries extends EntriesNotifier {
  _Entries(List<Map<String, dynamic>> records)
    : super(HybridStorageService(), null) {
    state = AsyncValue.data(records);
  }
}

List<Map<String, dynamic>> _records() => [
  {
    'id': 'salary',
    'amount': 1500.0,
    'description': 'Salary',
    'is_income': true,
    'entry_date': '2026-10-05T09:00:00',
    'synced': true,
  },
  {
    'id': 'groceries',
    'amount': 85.5,
    'description': 'Groceries',
    'is_income': false,
    'entry_date': '2026-10-05T10:00:00',
    'synced': false,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = Platform.environment['AUTH_PREVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({PrefKeys.selectedCurrency: 1}),
  );

  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    Size size = const Size(390, 844),
    bool empty = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entriesProvider.overrideWith(
            (ref, id) => _Entries(empty ? [] : _records()),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: const ValueKey('cash-preview'),
              child: child!,
            ),
          ),
          home: const CashEntryScreen(
            bookId: 'b1',
            bookName: 'Everyday spending',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('cash-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/design-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'filters and search keep balance totals and edit the selected entry',
    (tester) async {
      await show(tester);
      expect(find.textContaining('1,414.50'), findsOneWidget);
      await capture(tester, 'cash-book-modern');
      await tester.ensureVisible(find.text('Expense'));
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<EntryCardWidget>(find.byType(EntryCardWidget))
            .single
            .entry['id'],
        'groceries',
      );
      expect(find.textContaining('1,414.50'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.enterText(
        find.byKey(const ValueKey('entry-search')),
        'SALARY',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<EntryCardWidget>(find.byType(EntryCardWidget))
            .single
            .entry['id'],
        'salary',
      );
      await tester.ensureVisible(find.text('Salary'));
      await tester.tap(find.text('Salary'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryDialogWidget), findsOneWidget);
      expect(
        tester
            .widget<EntryDialogWidget>(find.byType(EntryDialogWidget))
            .existingEntry!['id'],
        'salary',
      );
      await tester.tap(find.byTooltip('Close entry form'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cash action buttons open the correct forms and empty state stays usable',
    (tester) async {
      await show(tester, empty: true);
      expect(find.text('Start your story'), findsOneWidget);
      for (final income in [true, false]) {
        await tester.tap(find.text(income ? 'Cash in' : 'Cash out'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EntryDialogWidget>(find.byType(EntryDialogWidget))
              .isIncome,
          income,
        );
        await tester.tap(find.byTooltip('Close entry form'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'light, dark, narrow and enlarged text layouts have no overflow',
    (tester) async {
      await show(tester, dark: true);
      await capture(tester, 'cash-book-modern-dark');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, dark: true, scale: 1.6, size: const Size(320, 640));
      await capture(tester, 'cash-book-modern-large-text');
      await tester.scrollUntilVisible(
        find.text('Groceries'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, size: const Size(720, 1000));
      await capture(tester, 'cash-book-modern-wide');
      expect(tester.takeException(), isNull);
    },
  );
}
