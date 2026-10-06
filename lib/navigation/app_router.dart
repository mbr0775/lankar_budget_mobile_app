import '../utils/debug_log.dart';
// lib/navigation/app_router.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/update_password_screen.dart';
import '../screens/auth/confirm_email_screen.dart';

import '../screens/books/cash_entry_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/subscription_screen.dart';

import '../utils/constants.dart';
import 'main_shell.dart';

final authRefreshProvider = Provider<GoRouterRefreshStream>((ref) {
  final authRefresh = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );

  ref.onDispose(authRefresh.dispose);
  return authRefresh;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ref.watch(authRefreshProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,

    refreshListenable: authRefresh,

    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;

      final loggedIn = user != null;

      final location = state.matchedLocation;

      // Authentication callbacks take priority even during a cold start.
      if (authRefresh.isOpeningAuthLink) {
        return location == AppRoutes.authLinkOpening
            ? null
            : AppRoutes.authLinkOpening;
      }
      if (authRefresh.hasLinkError) {
        authRefresh.clearLinkError();
        return location == AppRoutes.authLinkError
            ? null
            : AppRoutes.authLinkError;
      }
      if (loggedIn && authRefresh.isPasswordRecovery) {
        return location == AppRoutes.updatePassword
            ? null
            : AppRoutes.updatePassword;
      }

      debugLog(
        "ROUTER => location=$location "
        "loggedIn=$loggedIn",
      );

      // Splash page
      if (location == AppRoutes.splash) {
        // already logged in
        if (loggedIn) {
          return AppRoutes.home;
        }

        return null;
      }

      final publicRoutes = [
        AppRoutes.login,

        AppRoutes.signup,

        AppRoutes.forgotPass,

        AppRoutes.onboarding,
        AppRoutes.confirmEmail,
        AppRoutes.authLinkError,
        AppRoutes.authLinkOpening,
      ];

      final isPublic = publicRoutes.contains(location);

      // User not logged in
      // protect private pages

      if (!loggedIn && !isPublic) {
        return AppRoutes.login;
      }

      // User logged in
      // remove auth pages

      if (loggedIn && isPublic && location != AppRoutes.authLinkError) {
        return AppRoutes.home;
      }

      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.authLinkOpening,
        builder: (_, __) => const Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Opening your email link…'),
                ],
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.confirmEmail,
        builder: (_, state) => ConfirmEmailScreen(
          email: state.extra is String ? state.extra as String : '',
        ),
      ),
      GoRoute(
        path: AppRoutes.authLinkError,
        builder: (_, __) => const AuthLinkErrorScreen(),
      ),
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),

      GoRoute(
        path: AppRoutes.onboarding,

        builder: (_, __) => const OnboardingScreen(),
      ),

      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),

      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignupScreen()),

      GoRoute(
        path: AppRoutes.forgotPass,

        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        path: AppRoutes.updatePassword,

        builder: (_, __) => const UpdatePasswordScreen(),
      ),

      GoRoute(path: AppRoutes.home, builder: (_, __) => const MainShell()),

      GoRoute(
        path: '/book/:bookId',

        builder: (_, state) {
          return CashEntryScreen(
            bookId: state.pathParameters['bookId']!,

            bookName: state.uri.queryParameters['name'] ?? '',
          );
        },
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _subscription = stream.listen(
      (state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _isPasswordRecovery = true;
        } else if (state.event == AuthChangeEvent.signedOut) {
          _isPasswordRecovery = false;
        }

        debugLog("AUTH EVENT => ${state.event}");

        notifyListeners();
      },

      onError: (error) {
        // Link errors must be visible, without exposing tokens or backend text.
        failAuthLink();
      },
    );
  }

  bool _isPasswordRecovery = false;
  bool _isOpeningAuthLink = false;
  bool get isOpeningAuthLink => _isOpeningAuthLink;
  void startAuthLink() {
    _isOpeningAuthLink = true;
    _hasLinkError = false;
    notifyListeners();
  }

  void completeAuthLink({required bool passwordRecovery}) {
    _isOpeningAuthLink = false;
    _hasLinkError = false;
    _isPasswordRecovery = passwordRecovery;
    notifyListeners();
  }

  void failAuthLink() {
    _isOpeningAuthLink = false;
    _isPasswordRecovery = false;
    _hasLinkError = true;
    notifyListeners();
  }

  bool _hasLinkError = false;
  bool get hasLinkError => _hasLinkError;
  void clearLinkError() => _hasLinkError = false;

  bool get isPasswordRecovery => _isPasswordRecovery;

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();

    super.dispose();
  }
}
