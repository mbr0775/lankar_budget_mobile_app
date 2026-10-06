import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lankar/screens/auth/login_screen.dart';
import 'package:lankar/screens/auth/signup_screen.dart';
import 'package:lankar/screens/auth/onboarding_screen.dart';
import 'package:lankar/screens/auth/splash_screen.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/utils/constants.dart';
import 'package:lankar/widgets/auth_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final previewFont = Platform.environment['AUTH_PREVIEW_FONT'];
    if (previewFont != null) {
      final loader = FontLoader('Roboto')
        ..addFont(File(previewFont).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    bool dark = false,
    double scale = 1,
    bool reduced = true,
    double keyboard = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
        home: KeyedSubtree(key: UniqueKey(), child: screen),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/icon/app_icon.png'),
        tester.element(find.byType(MaterialApp)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('preview')),
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
    'login validates, reveals password, and renders in light and dark',
    (tester) async {
      await show(tester, const LoginScreen());
      await capture(tester, 'login');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await show(tester, const LoginScreen(), dark: true);
      await capture(tester, 'login-dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signup validates password confirmation and scrolls with keyboard',
    (tester) async {
      await show(tester, const SignupScreen());
      await capture(tester, 'signup');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test User');
      await tester.enterText(fields.at(1), 'test@example.com');
      await tester.enterText(fields.at(2), 'password123');
      await tester.enterText(fields.at(3), 'different123');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await show(
        tester,
        const SignupScreen(),
        size: const Size(320, 568),
        scale: 1.5,
        keyboard: 250,
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all onboarding pages render and completion persists and routes to login',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(
        initialLocation: AppRoutes.onboarding,
        routes: [
          GoRoute(
            path: AppRoutes.onboarding,
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, __) => const Scaffold(body: Text('Login destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(
              key: const ValueKey('preview'),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (int page = 0; page < 3; page++) {
        await capture(tester, 'onboarding-${page + 1}');
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(page == 2 ? 'Get started' : 'Continue'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Login destination'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          PrefKeys.seenOnboarding,
        ),
        isTrue,
      );
    },
  );

  testWidgets('small onboarding and animated artwork avoid layout overflow', (
    tester,
  ) async {
    await show(
      tester,
      const OnboardingScreen(),
      size: const Size(320, 568),
      scale: 1.5,
    );
    expect(tester.takeException(), isNull);
    for (int variant = 0; variant < 3; variant++) {
      await show(
        tester,
        Scaffold(body: FinanceScene(variant: variant)),
        reduced: false,
        scale: 1.5,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('splash renders and routes returning users to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({PrefKeys.seenOnboarding: true});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: AppRoutes.splash,
      routes: [
        GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Scaffold(body: Text('Login destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: RepaintBoundary(key: const ValueKey('preview'), child: child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await capture(tester, 'splash');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Login destination'), findsOneWidget);
  });
}
