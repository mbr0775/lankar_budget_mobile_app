import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lankar/providers/analytics_provider.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/providers/books_provider.dart';
import 'package:lankar/providers/settings_provider.dart';
import 'package:lankar/screens/analytics/analytics_screen.dart';
import 'package:lankar/screens/profile/profile_screen.dart';
import 'package:lankar/screens/profile/settings_screen.dart';
import 'package:lankar/screens/profile/subscription_screen.dart';
import 'package:lankar/services/auth_service.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/analytics_data.dart';
import 'package:lankar/utils/app_errors.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/widgets/analytics_design.dart';
import 'package:lankar/widgets/app_feedback.dart';
import 'package:lankar/widgets/dimensional_design.dart';
import 'package:lankar/widgets/home/home_motion.dart';

class _Books extends BooksNotifier {
  _Books({this.empty = false}) : super(HybridStorageService(), null);
  final bool empty;
  @override
  Future<void> loadBooks() async => state = AsyncValue.data(
    empty
        ? []
        : [
            {'id': 'b1', 'name': 'Everyday'},
          ],
  );
}

class _Auth extends AuthNotifier {
  _Auth() : super(AuthService());
  int signOuts = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> signOut() async {
    signOuts++;
    await gate?.future;
    if (fail) {
      throw const AppFailure(
        'Sync before signing out',
        'Your entries are still on this device.',
      );
    }
  }
}

List<Map<String, dynamic>> _records() {
  final now = DateTime.now();
  String date(int months, int day) =>
      DateTime(now.year, now.month - months, day, 10).toIso8601String();
  return [
    {
      'id': 'salary',
      'amount': 2000,
      'is_income': true,
      'description': 'Salary',
      'entry_date': date(0, 1),
    },
    {
      'id': 'meal',
      'amount': 80,
      'is_income': false,
      'description': 'Lunch',
      'entry_date': date(0, 1),
    },
    {
      'id': 'taxi',
      'amount': 120,
      'is_income': false,
      'description': 'Taxi ride',
      'entry_date': date(0, 1),
    },
    {
      'id': 'internet',
      'amount': 50,
      'is_income': false,
      'description': 'Internet bill',
      'entry_date': date(0, 1),
    },
    {
      'id': 'last-income',
      'amount': 1800,
      'is_income': true,
      'description': 'Salary',
      'entry_date': date(1, 1),
    },
    {
      'id': 'last-expense',
      'amount': 500,
      'is_income': false,
      'description': 'Shopping',
      'entry_date': date(1, 1),
    },
    {
      'id': 'older-income',
      'amount': 1800,
      'is_income': true,
      'description': 'Salary',
      'entry_date': date(2, 1),
    },
  ];
}

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
  Future<void> show(
    WidgetTester tester, {
    bool profile = false,
    bool dark = false,
    bool reduced = true,
    double scale = 1,
    Size size = const Size(390, 844),
    bool signedIn = true,
    bool emptyBooks = false,
    bool fail = false,
    bool longName = false,
    List<Map<String, dynamic>>? entries,
  }) async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.selectedCurrency: 1,
      PrefKeys.isDarkMode: dark,
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final user = User.fromJson({
      'id': 'u1',
      'aud': 'authenticated',
      'email': longName
          ? 'nimal.perera.long.account@example.com'
          : 'nimal@example.com',
      'created_at': '2026-01-01T00:00:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {
        'full_name': longName
            ? 'Nimal Alexander Wijesinghe Perera'
            : 'Nimal Perera',
      },
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(signedIn),
          currentUserProvider.overrideWithValue(signedIn ? user : null),
          booksProvider.overrideWith((ref) => _Books(empty: emptyBooks)),
          analyticsEntriesProvider.overrideWith(
            (ref) => fail
                ? Stream.error(const SocketException('fixture'))
                : Stream.value(entries ?? _records()),
          ),
          authNotifierProvider.overrideWith((ref) => _Auth()),
          profileAppVersionProvider.overrideWith(
            (ref) async => '1.0.0 (build 1)',
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(settingsProvider);
            return MaterialApp(
              scaffoldMessengerKey: AppFeedback.messengerKey,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              themeAnimationDuration: Duration.zero,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: reduced,
                  textScaler: TextScaler.linear(scale),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('dimensional-preview'),
                  child: child!,
                ),
              ),
              home: profile ? const ProfileScreen() : const AnalyticsScreen(),
            );
          },
        ),
      ),
    );
    if (reduced) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('dimensional-preview')),
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
    'analytics totals, period filters, currency conversion and monthly details work',
    (tester) async {
      await show(tester);
      expect(find.textContaining('1,750.00'), findsOneWidget);
      await capture(tester, 'analytics-3d');
      await tester.tap(find.byKey(const ValueKey(AnalyticsPeriod.year)));
      await tester.pumpAndSettle();
      final dashboard = tester.widget<AnalyticsDashboard>(
        find.byType(AnalyticsDashboard),
      );
      expect(dashboard.data.period, AnalyticsPeriod.year);
      expect(dashboard.data.income, greaterThanOrEqualTo(2000));
      await tester.tap(find.byTooltip('Change currency'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QAR'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnalyticsDashboard>(find.byType(AnalyticsDashboard))
            .symbol,
        'QR',
      );
      await reveal(tester, find.text('Monthly totals'));
      await tester.tap(find.text('Monthly totals'));
      await tester.pumpAndSettle();
      final trends = tester.widget<AnalyticsTrends>(
        find.byType(AnalyticsTrends),
      );
      expect(trends.months.length, 12);
      expect(trends.months.last.income, 2000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'analytics handles signed-out, empty, expense-only and retry states',
    (tester) async {
      await show(tester, signedIn: false);
      expect(find.text('Sign in to Lankar'), findsOneWidget);
      expect(find.byType(AnalyticsDashboard), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, emptyBooks: true);
      expect(find.text('Start with a cash book'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, entries: []);
      await reveal(tester, find.text('No expenses in this period.'));
      expect(
        find.text('Add income to calculate your savings rate.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, entries: [_records()[1]]);
      expect(find.textContaining('-80.00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, fail: true);
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile shows identity, switches currency and appearance, and opens account pages',
    (tester) async {
      await show(tester, profile: true);
      expect(find.text('Nimal Perera'), findsOneWidget);
      expect(find.text('nimal@example.com'), findsOneWidget);
      await capture(tester, 'profile-3d');
      await reveal(tester, find.text('Light appearance'));
      await tester.tap(find.text('Light appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Dark appearance'), findsOneWidget);
      await reveal(tester, find.text(r'USD ($)'));
      await tester.tap(find.text(r'USD ($)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LKR'));
      await tester.pumpAndSettle();
      expect(find.text('LKR (Rs)'), findsOneWidget);
      await reveal(tester, find.text('Settings'));
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Go Premium'));
      await tester.tap(find.text('Go Premium'));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile cancels sign-out, blocks repeat attempts, and keeps failures actionable',
    (tester) async {
      await show(tester, profile: true);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
      final auth = container.read(authNotifierProvider.notifier) as _Auth;
      await reveal(tester, find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();
      expect(auth.signOuts, 0);
      auth.fail = true;
      auth.gate = Completer<void>();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(auth.signOuts, 1);
      expect(find.text('Signing out...'), findsOneWidget);
      final action = tester.widget<DepthAction>(
        find.ancestor(
          of: find.text('Signing out...'),
          matching: find.byType(DepthAction),
        ),
      );
      expect(action.onTap, isNull);
      auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Sync before signing out'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '3d screens fit dark, wide, enlarged text and long profile names',
    (tester) async {
      await show(tester, dark: true);
      await capture(tester, 'analytics-3d-dark');
      await reveal(tester, find.text('Where your money goes'));
      await capture(tester, 'analytics-3d-categories');
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, dark: true, scale: 1.6, size: const Size(320, 640));
      await reveal(tester, find.text('Savings rate'));
      await capture(tester, 'analytics-3d-large-text');
      await reveal(tester, find.text('Monthly totals'));
      await tester.tap(find.text('Monthly totals'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(
        tester,
        profile: true,
        dark: true,
        scale: 1.6,
        longName: true,
        size: const Size(320, 640),
      );
      await capture(tester, 'profile-3d-large-text');
      await reveal(tester, find.text('Sign out'));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Stay signed in'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, profile: true, dark: true);
      await capture(tester, 'profile-3d-dark');
      await tester.pumpWidget(const SizedBox.shrink());
      await show(tester, size: const Size(720, 1000));
      await capture(tester, 'analytics-3d-wide');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await show(
        tester,
        profile: true,
        signedIn: false,
        scale: 1.6,
        size: const Size(320, 640),
      );
      expect(find.text('You are signed out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('analytics controls work while the 3d artwork is animated', (
    tester,
  ) async {
    await show(tester, reduced: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GrowthSculpture), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(AnalyticsPeriod.year)));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<AnalyticsDashboard>(find.byType(AnalyticsDashboard))
          .data
          .period,
      AnalyticsPeriod.year,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
