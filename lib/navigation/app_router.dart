// lib/navigation/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/books/cash_entry_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/subscription_screen.dart';
import '../utils/constants.dart';
import 'package:flutter/material.dart';
import 'main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(
        Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) {
      // ✅ Read session directly from Supabase — most reliable source
      final session    = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;

      final loc = state.matchedLocation;

      // Never interfere with splash — it navigates itself
      if (loc == AppRoutes.splash) return null;

      final isAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.signup ||
          loc == AppRoutes.forgotPass ||
          loc == AppRoutes.onboarding;

      // Not logged in and trying to access protected route → login
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;

      // ✅ Logged in and on auth route → home
      // This only fires when session ACTUALLY exists (after successful login)
      if (isLoggedIn && isAuthRoute) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPass,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const MainShell(),
      ),
      GoRoute(
        path: '/book/:bookId',
        builder: (_, state) => CashEntryScreen(
          bookId:   state.pathParameters['bookId']!,
          bookName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        builder: (_, __) => const SubscriptionScreen(),
      ),
    ],
  );
});

/// Listens to Supabase auth stream and triggers GoRouter re-evaluation
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}