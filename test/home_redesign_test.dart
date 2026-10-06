import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lankar/navigation/main_shell.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/providers/books_provider.dart';
import 'package:lankar/providers/settings_provider.dart';
import 'package:lankar/screens/home/home_screen.dart';
import 'package:lankar/services/hive_service.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/widgets/home/home_motion.dart';
import 'package:lankar/widgets/home/monthly_summary_card.dart';

final _now = DateTime.now();
final _books = <Map<String, dynamic>>[
  {
    'id': 'b1',
    'name': 'Everyday spending',
    'balance': 3420.5,
    'created_at': _now.toIso8601String(),
  },
  {
    'id': 'b2',
    'name': 'Savings & goals',
    'balance': 5100.0,
    'created_at': _now.toIso8601String(),
  },
  {
    'id': 'b3',
    'name': 'Travel fund',
    'balance': 875.0,
    'created_at': _now.toIso8601String(),
  },
];
final _entries = <Map<String, dynamic>>[
  for (final day in [2, 9, 17, 24]) ...[
    {
      'amount': 1400.0 + day * 10,
      'is_income': true,
      'entry_date': DateTime(_now.year, _now.month, day).toIso8601String(),
    },
    {
      'amount': 480.0 + day * 8,
      'is_income': false,
      'entry_date': DateTime(_now.year, _now.month, day).toIso8601String(),
    },
  ],
];

class _PreviewBooks extends BooksNotifier {
  _PreviewBooks(this.books) : super(HybridStorageService(), null);
  final List<Map<String, dynamic>> books;
  @override
  Future<void> loadBooks() async {
    state = AsyncValue.data(books);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;
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
    hiveDirectory = await Directory.systemTemp.createTemp('lankar-home-test-');
    Hive.init(hiveDirectory.path);
    HiveService().syncQueueBox = await Hive.openBox<Map>('home-preview-sync');
  });
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({PrefKeys.selectedCurrency: 1}),
  );
  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  Widget app({
    bool dark = false,
    bool reduced = true,
    double scale = 1,
    bool active = true,
    bool empty = false,
    bool signedIn = true,
    bool entryError = false,
  }) => ProviderScope(
    overrides: [
      isLoggedInProvider.overrideWithValue(signedIn),
      userDisplayNameProvider.overrideWithValue('Nimal'),
      booksProvider.overrideWith((_) => _PreviewBooks(empty ? [] : _books)),
      allEntriesProvider.overrideWith((_) async {
        if (entryError) throw const SocketException('test error');
        return empty ? [] : _entries;
      }),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      themeAnimationDuration: Duration.zero,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(scale),
        ),
        child: TickerMode(
          enabled: active,
          child: RepaintBoundary(
            key: const ValueKey('home-preview'),
            child: child!,
          ),
        ),
      ),
      home: const HomeScreen(),
    ),
  );

  Future<void> show(
    WidgetTester tester, {
    bool dark = false,
    bool reduced = true,
    double scale = 1,
    bool empty = false,
    bool signedIn = true,
    bool entryError = false,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        dark: dark,
        reduced: reduced,
        scale: scale,
        empty: empty,
        signedIn: signedIn,
        entryError: entryError,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(HomeScreen)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('home-preview')),
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
    'home renders real balances, navigates shortcuts, and fits both themes',
    (tester) async {
      await show(tester);
      expect(find.text('Hello, Nimal.'), findsOneWidget);
      expect(find.textContaining('9,395.50'), findsOneWidget);
      expect(find.textContaining('6,120.00'), findsNWidgets(2));
      await capture(tester, 'home');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      await tester.tap(find.text('Reports'));
      await tester.pump();
      expect(container.read(selectedTabProvider), 2);
      await tester.tap(find.text('Books'));
      await tester.pump();
      expect(container.read(selectedTabProvider), 1);
      await tester.scrollUntilVisible(find.text('Your cash books'), 180);
      await tester.pumpAndSettle();
      await capture(tester, 'home-books');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, dark: true);
      await capture(tester, 'home-dark');
      await tester.tap(find.text('Currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LKR'));
      await tester.pumpAndSettle();
      final darkContainer = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(darkContainer.read(settingsProvider).currency, Currency.LKR);
      expect(find.textContaining('Rs '), findsWidgets);
      await tester.tap(find.byTooltip('Change currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      expect(find.textContaining('9,395.50'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Your cash books'), 180);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small home with larger text, empty data, and errors stays usable',
    (tester) async {
      await show(tester, size: const Size(320, 640), scale: 1.6, empty: true);
      await capture(tester, 'home-large-text');
      await tester.scrollUntilVisible(
        find.text('Start your first cash book'),
        160,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Start your first cash book'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(container.read(selectedTabProvider), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, entryError: true);
      expect(find.text('Unavailable'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('Try again'),
        160,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection problem'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(
        tester,
        signedIn: false,
        size: const Size(320, 640),
        scale: 1.6,
      );
      await tester.scrollUntilVisible(find.text('Sign in to Lankar'), 120);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sculpture moves, respects reduced motion, and pauses in inactive tabs',
    (tester) async {
      await show(tester, reduced: false);
      final transformFinder = find.descendant(
        of: find.byType(GrowthSculpture),
        matching: find.byType(Transform),
      );
      List<double> pose() =>
          List.of(tester.widget<Transform>(transformFinder).transform.storage);
      final initial = pose();
      await tester.pump(const Duration(milliseconds: 500));
      expect(pose(), isNot(initial));
      await tester.pumpWidget(app(reduced: false, active: false));
      await tester.pump();
      final paused = pose();
      await tester.pump(const Duration(milliseconds: 500));
      expect(pose(), paused);
      await tester.pumpWidget(app(reduced: true));
      await tester.pump();
      final reduced = pose();
      await tester.pump(const Duration(milliseconds: 500));
      expect(pose(), reduced);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cash flow keeps daily weekly monthly, month navigation, and bar selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlySummaryCard(
                allEntries: _entries,
                currencySymbol: r'$',
                exchangeRate: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekly'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      for (final mode in ['Daily', 'Monthly', 'Weekly']) {
        await tester.tap(find.byTooltip('Change chart view'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(mode).last);
        await tester.pumpAndSettle();
        expect(find.text(mode), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final paint = find
          .descendant(
            of: find.byType(MonthlySummaryCard),
            matching: find.byType(CustomPaint),
          )
          .last;
      await tester.tapAt(tester.getCenter(paint));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
