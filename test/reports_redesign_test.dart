import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lankar/navigation/main_shell.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/providers/books_provider.dart';
import 'package:lankar/providers/entries_provider.dart';
import 'package:lankar/screens/books/cash_entry_screen.dart';
import 'package:lankar/screens/reports/reports_screen.dart';
import 'package:lankar/screens/reports/reports_tab_screen.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/utils/report_data.dart';
import 'package:lankar/widgets/app_feedback.dart';
import 'package:lankar/widgets/reports_design.dart';

List<Map<String, dynamic>> records(String id) => id == 'b2'
    ? [
        {
          'id': 'expense',
          'amount': 250,
          'description': 'Travel tickets',
          'is_income': false,
          'entry_date': '2026-10-01T10:00:00',
        },
      ]
    : [
        {
          'id': 'salary',
          'amount': 1500,
          'description': 'Salary',
          'is_income': true,
          'entry_date': '2026-10-01T09:00:00',
        },
        {
          'id': 'food',
          'amount': 85.5,
          'description': 'Groceries',
          'is_income': false,
          'entry_date': '2026-10-03T10:00:00',
        },
        {
          'id': 'undated',
          'amount': 10,
          'description': '',
          'is_income': false,
          'entry_date': 'invalid',
        },
      ];

class _Books extends BooksNotifier {
  _Books(this.records, {this.fail = false})
    : super(HybridStorageService(), null);
  List<Map<String, dynamic>> records;
  bool fail;
  @override
  Future<void> loadBooks() async {
    state = fail
        ? AsyncValue.error(const SocketException('fixture'), StackTrace.current)
        : AsyncValue.data(List.of(records));
  }
}

class _Entries extends EntriesNotifier {
  _Entries(this.records, {this.fail = false})
    : super(HybridStorageService(), null) {
    loadEntries();
  }
  List<Map<String, dynamic>> records;
  bool fail;
  int loads = 0;
  @override
  Future<void> loadEntries() async {
    loads++;
    state = fail
        ? AsyncValue.error(const SocketException('fixture'), StackTrace.current)
        : AsyncValue.data(List.of(records));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory exportDirectory;
  int shareCalls = 0;
  bool failShare = false;
  int saveCalls = 0;
  bool failSave = false;
  bool cancelSave = false;
  Completer<void>? shareGate;
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
    exportDirectory = await Directory.systemTemp.createTemp(
      'lankar-report-tests-',
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({PrefKeys.selectedCurrency: 1});
    shareCalls = 0;
    failShare = false;
    saveCalls = 0;
    failSave = false;
    cancelSave = false;
    shareGate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.tokilo.lankar/reports'),
          (call) async {
            expect(call.method, 'savePdf');
            saveCalls++;
            if (failSave) throw PlatformException(code: 'save_failed');
            if (cancelSave) return null;
            final arguments = Map<String, dynamic>.from(call.arguments as Map);
            final file = File('${exportDirectory.path}/${arguments['name']}');
            await file.writeAsBytes(arguments['bytes'] as List<int>);
            return 'content://documents/report.pdf';
          },
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => exportDirectory.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          (call) async {
            shareCalls++;
            await shareGate?.future;
            if (failShare) throw PlatformException(code: 'fixture');
            return 'success';
          },
        );
  });
  tearDownAll(() async => exportDirectory.delete(recursive: true));

  Future<void> show(
    WidgetTester tester, {
    bool detail = false,
    bool cash = false,
    bool dark = false,
    double scale = 1,
    Size size = const Size(390, 844),
    bool signedIn = true,
    bool empty = false,
    bool entryError = false,
    bool bookError = false,
    List<Map<String, dynamic>>? entries,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = entries ?? records('b1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(signedIn),
          booksProvider.overrideWith(
            (ref) => _Books(
              empty
                  ? []
                  : [
                      {'id': 'b1', 'name': 'Everyday spending'},
                      {'id': 'b2', 'name': 'Travel fund'},
                    ],
              fail: bookError,
            ),
          ),
          entriesProvider.overrideWith(
            (ref, id) =>
                _Entries(id == 'b1' ? data : records(id), fail: entryError),
          ),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: AppFeedback.messengerKey,
          theme: dark ? AppTheme.dark : AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(
              key: const ValueKey('reports-preview'),
              child: child!,
            ),
          ),
          home: cash
              ? const CashEntryScreen(
                  bookId: 'b1',
                  bookName: 'Everyday spending',
                )
              : detail
              ? ReportsScreen(
                  bookId: 'b1',
                  bookName: 'Everyday spending',
                  totalIn: 1500,
                  totalOut: 95.5,
                  balance: 1404.5,
                  entries: data,
                  currencySymbol: r'$',
                )
              : const ReportsTabScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String name) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('reports-preview')),
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
    'reports tab selects, refreshes and switches books with accurate totals',
    (tester) async {
      await show(tester);
      expect(find.text('Choose a book to explore'), findsOneWidget);
      await choose(tester, 'Everyday spending');
      expect(find.textContaining('1,404.50'), findsOneWidget);
      expect(find.text('6.4% of income spent'), findsOneWidget);
      await capture(tester, 'reports-modern');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReportsTabScreen)),
      );
      final notifier =
          container.read(entriesProvider('b1').notifier) as _Entries;
      await tester.tap(find.byTooltip('Refresh reports'));
      await tester.pumpAndSettle();
      expect(notifier.loads, 2);
      await choose(tester, 'Travel fund');
      expect(find.textContaining('-250.00'), findsOneWidget);
      expect(find.text('No income recorded'), findsOneWidget);
      expect(
        tester
            .widget<ReportsOverview>(find.byType(ReportsOverview))
            .entries
            .single['id'],
        'expense',
      );
      final books = container.read(booksProvider.notifier) as _Books;
      books.records = [books.records.first];
      await books.loadBooks();
      await tester.pumpAndSettle();
      expect(find.text('Choose a book to explore'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cash book opens its report and currency conversion stays precise',
    (tester) async {
      await show(tester, cash: true);
      await tester.tap(find.byTooltip('View book report'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(find.textContaining('1,404.50'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      await tester.tap(find.byTooltip('Report currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QAR'));
      await tester.pumpAndSettle();
      expect(find.textContaining('QR 5,120.31'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to cash book'));
      await tester.pumpAndSettle();
      expect(find.byType(CashEntryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signed-out, empty books and data failures offer recovery', (
    tester,
  ) async {
    await show(tester, signedIn: false);
    expect(find.text('Sign in to Lankar'), findsOneWidget);
    expect(find.byType(ReportsOverview), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, empty: true);
    await tester.tap(find.text('Go to cash books'));
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(ReportsTabScreen)),
      ).read(selectedTabProvider),
      1,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, bookError: true);
    expect(find.text('Try again'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReportsTabScreen)),
    );
    (container.read(booksProvider.notifier) as _Books).fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, entryError: true);
    await choose(tester, 'Everyday spending');
    expect(find.text('Try again'), findsOneWidget);
    final entries =
        ProviderScope.containerOf(
              tester.element(find.byType(ReportsTabScreen)),
            ).read(entriesProvider('b1').notifier)
            as _Entries;
    entries.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportsOverview), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, dark, wide and large-text layouts fit without overflow', (
    tester,
  ) async {
    await show(tester, detail: true, entries: []);
    expect(find.text('No transactions yet'), findsOneWidget);
    await capture(tester, 'report-empty');
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, detail: true, dark: true);
    await capture(tester, 'report-modern-dark');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, dark: true, scale: 1.6, size: const Size(320, 640));
    await choose(tester, 'Everyday spending');
    await capture(tester, 'reports-large-text');
    await tester.drag(find.byType(ListView).first, const Offset(0, -1300));
    await tester.pumpAndSettle();
    await capture(tester, 'reports-large-text-history');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await show(tester, detail: true, size: const Size(720, 1000));
    await capture(tester, 'report-modern-wide');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history is newest first with unknown dates last and no input mutation',
    (tester) async {
      final data = records('b1');
      await show(tester, detail: true, entries: data);
      expect(
        tester
            .widgetList<ReportTransaction>(find.byType(ReportTransaction))
            .map((tile) => tile.entry['id']),
        ['food', 'salary', 'undated'],
      );
      expect(data.first['id'], 'salary');
      expect(
        reportFilename('Everyday/Spending:2026'),
        'Everyday_Spending_2026_report.pdf',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PDF export blocks duplicates and restores controls after sharing fails',
    (tester) async {
      await show(tester, detail: true);
      await tester.scrollUntilVisible(
        find.text('Share PDF'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      shareGate = Completer<void>();
      failShare = true;
      await tester.runAsync(() async {
        await tester.tap(find.text('Share PDF'));
        for (var attempt = 0; attempt < 100 && shareCalls == 0; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pump();
      expect(shareCalls, 1);
      expect(
        tester
            .widget<ReportExportCard>(find.byType(ReportExportCard))
            .exporting,
        true,
      );
      final buttons = tester.widgetList<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(buttons.every((button) => button.onPressed == null), true);
      shareGate!.complete();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReportExportCard>(find.byType(ReportExportCard))
            .exporting,
        false,
      );
      expect(find.byType(FeedbackCard), findsWidgets);
      final file = File('${exportDirectory.path}/Everyday spending_report.pdf');
      await tester.runAsync(() async {
        expect(await file.exists(), true);
        expect((await file.readAsBytes()).take(4), [37, 80, 68, 70]);
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'tab shares a PDF with full multi-page history and the detail report saves',
    (tester) async {
      final history = [
        for (var i = 0; i < 120; i++)
          {
            'id': 'history-$i',
            'amount': 10,
            'is_income': i.isEven,
            'description': 'Transaction $i',
            'entry_date': '2026-10-01T09:00:00',
          },
      ];
      await show(tester, entries: history);
      await choose(tester, 'Everyday spending');
      await tester.scrollUntilVisible(
        find.text('Share PDF'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final file = File('${exportDirectory.path}/Everyday spending_report.pdf');
      await tester.runAsync(() async {
        await tester.tap(find.text('Share PDF'));
        for (var attempt = 0; attempt < 100 && shareCalls == 0; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(shareCalls, 1);
        final bytes = await file.readAsBytes();
        expect(
          RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
          greaterThan(1),
        );
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ReportExportCard>(find.byType(ReportExportCard))
            .exporting,
        false,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, detail: true);
      await tester.scrollUntilVisible(
        find.text('Save PDF'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await file.delete();
        await tester.tap(find.text('Save PDF'));
        for (
          var attempt = 0;
          attempt < 100 && !await file.exists();
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect((await file.readAsBytes()).take(4), [37, 80, 68, 70]);
      });
      await tester.pumpAndSettle();
      expect(find.text('Report saved'), findsOneWidget);
      expect(saveCalls, 1);
      expect(shareCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android save cancellation and failure restore export controls', (
    tester,
  ) async {
    for (final cancelled in [true, false]) {
      cancelSave = cancelled;
      failSave = !cancelled;
      await show(tester, detail: true);
      await tester.scrollUntilVisible(
        find.text('Save PDF'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final previousCalls = saveCalls;
      await tester.runAsync(() async {
        await tester.tap(find.text('Save PDF'));
        for (
          var attempt = 0;
          attempt < 100 && saveCalls == previousCalls;
          attempt++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(saveCalls, previousCalls + 1);
      expect(find.text('Report saved'), findsNothing);
      expect(
        tester
            .widget<ReportExportCard>(find.byType(ReportExportCard))
            .exporting,
        false,
      );
      expect(
        find.byType(FeedbackCard),
        cancelled ? findsNothing : findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
