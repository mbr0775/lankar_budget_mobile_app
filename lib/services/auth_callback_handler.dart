import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../navigation/app_router.dart';
import '../utils/constants.dart';

/// One owner for native callbacks, including links from older email requests.
/// Routing waits for server verification; a callback address alone is not auth.
class AuthCallbackHandler {
  AuthCallbackHandler(this.auth, this.refresh);
  final GoTrueClient auth;
  final GoRouterRefreshStream refresh;
  StreamSubscription<Uri>? _subscription;
  String? _lastLink;
  DateTime? _lastDelivery;
  Future<void>? _pending;
  bool _disposed = false;

  Future<void> initialize() async {
    final links = AppLinks();
    _subscription = links.uriLinkStream.listen(
      (uri) => unawaited(handleLink(uri)),
      onError: (Object error) => refresh.failAuthLink(),
    );
    // Explicitly handle cold starts too. The stream can repeat the initial URI.
    try {
      final initial = await links.getInitialLink();
      if (initial != null) await handleLink(initial);
    } catch (_) {
      if (!_disposed) refresh.failAuthLink();
    }
  }

  Future<void> handleLink(Uri uri) {
    final login = Uri.parse(SupabaseConfig.authRedirectUrl);
    final recovery = Uri.parse(SupabaseConfig.passwordResetRedirectUrl);
    if (uri.scheme != login.scheme ||
        (uri.host != login.host && uri.host != recovery.host)) {
      return Future<void>.value();
    }
    if (_disposed) return Future<void>.value();
    // Native initial-link and stream delivery can repeat within one launch.
    // Later taps must still be verified, so expired/used links can show an error.
    final now = DateTime.now();
    if (_lastLink == uri.toString() &&
        (refresh.isOpeningAuthLink ||
            now.difference(_lastDelivery!) < const Duration(seconds: 2))) {
      return _pending ?? Future<void>.value();
    }
    _lastLink = uri.toString();
    _lastDelivery = now;
    // Serialize exchanges so two delivered links cannot overwrite each other's
    // verification/routing state. Await duplicate initial/stream delivery too.
    final previous = _pending;
    final next = previous == null
        ? _verifyLink(uri)
        : previous.then((_) => _verifyLink(uri));
    _pending = next;
    return next;
  }

  Future<void> _verifyLink(Uri uri) async {
    if (_disposed) return;
    final recovery = Uri.parse(SupabaseConfig.passwordResetRedirectUrl);
    refresh.startAuthLink();
    try {
      final fragment = uri.fragment.isEmpty
          ? <String, String>{}
          : Uri.splitQueryString(uri.fragment);
      if (uri.queryParameters.containsKey('error') ||
          uri.queryParameters.containsKey('error_description') ||
          fragment.containsKey('error') ||
          fragment.containsKey('error_description')) {
        throw const AuthException('Email link could not be verified.');
      }
      bool isRecovery =
          uri.host == recovery.host || fragment['type'] == 'recovery';
      if (uri.queryParameters['code']?.isNotEmpty == true) {
        final response = await auth.getSessionFromUrl(uri);
        isRecovery = isRecovery || response.redirectType == 'passwordRecovery';
      } else if (fragment['refresh_token']?.isNotEmpty == true &&
          fragment['access_token']?.isNotEmpty == true) {
        // The default PKCE observer ignores legacy token-fragment links.
        // Exchange their refresh token with the server before using a session.
        await auth.setSession(fragment['refresh_token']!);
      } else {
        throw const AuthException(
          'Email link has no verification credentials.',
        );
      }
      if (auth.currentSession == null) {
        throw AuthSessionMissingException();
      }
      if (!_disposed) refresh.completeAuthLink(passwordRecovery: isRecovery);
    } catch (_) {
      _lastLink =
          null; // Allow another tap after a transient connection failure.
      if (!_disposed) refresh.failAuthLink();
    }
  }

  void dispose() {
    _disposed = true;
    _subscription?.cancel();
  }
}
