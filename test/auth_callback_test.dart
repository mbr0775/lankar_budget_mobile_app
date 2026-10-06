import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lankar/navigation/app_router.dart';
import 'package:lankar/services/auth_service.dart';
import 'package:lankar/services/auth_callback_handler.dart';
import 'package:lankar/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = {
    'id': 'user-1',
    'aud': 'authenticated',
    'email': 'test@example.com',
    'created_at': '2026-01-01T00:00:00Z',
  };
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode('{"sub":"user-1","exp":2000000000}'))}.signature';
  final requests = <http.Request>[];
  bool rejectCallback = false;
  Completer<void>? tokenGate;
  Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        final isToken = request.url.path.endsWith('/token');
        if (isToken && tokenGate != null) await tokenGate!.future;
        return http.Response(
          jsonEncode(
            isToken
                ? (rejectCallback
                      ? {'code': 'invalid_grant', 'msg': 'private diagnostics'}
                      : {
                          'access_token': token,
                          'refresh_token': 'refresh',
                          'token_type': 'bearer',
                          'expires_in': 3600,
                          'user': user,
                        })
                : request.url.path.endsWith('/user') ||
                      request.url.path.endsWith('/signup')
                ? user
                : {},
          ),
          isToken && rejectCallback ? 400 : 200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initialize();
  });
  setUp(() {
    requests.clear();
    rejectCallback = false;
    tokenGate = null;
  });
  tearDownAll(() => Supabase.instance.dispose());

  test(
    'resending confirmation includes the registered mobile redirect',
    () async {
      await AuthService().resendConfirmation(' test@example.com ');
      final request = requests.last;
      expect(request.url.path, '/auth/v1/resend');
      expect(
        request.url.queryParameters['redirect_to'],
        SupabaseConfig.authRedirectUrl,
      );
      expect(
        jsonDecode(request.body),
        containsPair('email', 'test@example.com'),
      );
      expect(jsonDecode(request.body), containsPair('type', 'signup'));
    },
  );

  test(
    'recovery survives refresh and user-update events until sign-out',
    () async {
      final events = StreamController<AuthState>(sync: true);
      final refresh = GoRouterRefreshStream(events.stream);
      events.add(AuthState(AuthChangeEvent.passwordRecovery, null));
      events.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
      expect(refresh.isPasswordRecovery, isTrue);
      events.add(AuthState(AuthChangeEvent.userUpdated, null));
      expect(refresh.isPasswordRecovery, isTrue);
      events.add(AuthState(AuthChangeEvent.signedOut, null));
      expect(refresh.isPasswordRecovery, isFalse);
      refresh.dispose();
      await events.close();
    },
  );

  testWidgets('cold-start recovery opens password form instead of Home', (
    tester,
  ) async {
    final container = ProviderContainer();
    final refresh = container.read(authRefreshProvider);
    final handler = AuthCallbackHandler(Supabase.instance.client.auth, refresh);
    await tester.runAsync(() async {
      await AuthService().resetPassword('test@example.com');
      final request = requests.last;
      expect(
        request.url.queryParameters['redirect_to'],
        SupabaseConfig.passwordResetRedirectUrl,
      );
      expect(jsonDecode(request.body)['code_challenge'], isNotEmpty);
      await handler.handleLink(
        Uri.parse(
          '${SupabaseConfig.passwordResetRedirectUrl}?code=verified-code',
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });
    expect(refresh.isPasswordRecovery, isTrue);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.updatePassword,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'newPassword123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newPassword123');
    await tester.ensureVisible(find.text('Update Password'));
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.login);
    expect(Supabase.instance.client.auth.currentSession, isNull);
    expect(
      requests.where(
        (request) =>
            request.method == 'PUT' && request.url.path.endsWith('/user'),
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    handler.dispose();
    await tester.runAsync(
      () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
    );
  });

  test(
    'PKCE recovery verifier survives closing and restarting the app',
    () async {
      await AuthService().resetPassword('test@example.com');
      await Supabase.instance.dispose();
      await initialize();
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final handler = AuthCallbackHandler(
        Supabase.instance.client.auth,
        refresh,
      );
      // A prior email can still return to the original login callback host.
      await handler.handleLink(
        Uri.parse('${SupabaseConfig.authRedirectUrl}?code=cold-code'),
      );
      expect(refresh.isPasswordRecovery, isTrue);
      expect(AuthService().currentSession, isNotNull);
      final request = requests.last;
      expect(request.url.queryParameters['grant_type'], 'pkce');
      expect(jsonDecode(request.body)['code_verifier'], isNotEmpty);
      handler.dispose();
      refresh.dispose();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    },
  );

  test(
    'legacy recovery token links are verified and identified with the default PKCE client',
    () async {
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final handler = AuthCallbackHandler(
        Supabase.instance.client.auth,
        refresh,
      );
      final link = Uri.parse(
        '${SupabaseConfig.authRedirectUrl}#access_token=$token&refresh_token=legacy-refresh&type=recovery',
      );
      await handler.handleLink(link);
      expect(refresh.isPasswordRecovery, isTrue);
      expect(AuthService().currentSession, isNotNull);
      expect(requests.last.url.queryParameters['grant_type'], 'refresh_token');
      final count = requests.length;
      await handler.handleLink(link);
      expect(
        requests.length,
        count,
        reason: 'Native initial link and stream can deliver the same URL.',
      );
      handler.dispose();
      refresh.dispose();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    },
  );

  test(
    'a callback address without credentials cannot authorize recovery',
    () async {
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final handler = AuthCallbackHandler(
        Supabase.instance.client.auth,
        refresh,
      );
      await handler.handleLink(
        Uri.parse(SupabaseConfig.passwordResetRedirectUrl),
      );
      expect(refresh.hasLinkError, isTrue);
      expect(refresh.isPasswordRecovery, isFalse);
      expect(AuthService().currentSession, isNull);
      expect(requests, isEmpty);
      handler.dispose();
      refresh.dispose();
    },
  );

  test(
    'rejected legacy recovery credentials never show the password form',
    () async {
      rejectCallback = true;
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final handler = AuthCallbackHandler(
        Supabase.instance.client.auth,
        refresh,
      );
      await handler.handleLink(
        Uri.parse(
          '${SupabaseConfig.passwordResetRedirectUrl}#access_token=invalid&refresh_token=invalid',
        ),
      );
      expect(refresh.hasLinkError, isTrue);
      expect(refresh.isPasswordRecovery, isFalse);
      expect(AuthService().currentSession, isNull);
      handler.dispose();
      refresh.dispose();
    },
  );

  test('signup confirmation stays separate from password recovery', () async {
    await AuthService().signUp(
      email: 'test@example.com',
      password: 'password123',
    );
    final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
    final handler = AuthCallbackHandler(Supabase.instance.client.auth, refresh);
    await handler.handleLink(
      Uri.parse('${SupabaseConfig.authRedirectUrl}?code=signup-code'),
    );
    expect(AuthService().currentSession, isNotNull);
    expect(refresh.isPasswordRecovery, isFalse);
    expect(refresh.hasLinkError, isFalse);
    handler.dispose();
    refresh.dispose();
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
  });

  test(
    'recovery waits for server verification before allowing a password change',
    () async {
      await AuthService().resetPassword('test@example.com');
      tokenGate = Completer<void>();
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final handler = AuthCallbackHandler(
        Supabase.instance.client.auth,
        refresh,
      );
      final exchange = handler.handleLink(
        Uri.parse(
          '${SupabaseConfig.passwordResetRedirectUrl}?code=waiting-code',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(refresh.isOpeningAuthLink, isTrue);
      expect(refresh.isPasswordRecovery, isFalse);
      expect(AuthService().currentSession, isNull);
      tokenGate!.complete();
      await exchange;
      expect(refresh.isOpeningAuthLink, isFalse);
      expect(refresh.isPasswordRecovery, isTrue);
      handler.dispose();
      refresh.dispose();
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    },
  );

  test('a PKCE link after app storage was cleared presents an error', () async {
    final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
    final handler = AuthCallbackHandler(Supabase.instance.client.auth, refresh);
    await handler.handleLink(
      Uri.parse(
        '${SupabaseConfig.passwordResetRedirectUrl}?code=missing-verifier',
      ),
    );
    expect(refresh.hasLinkError, isTrue);
    expect(refresh.isPasswordRecovery, isFalse);
    expect(AuthService().currentSession, isNull);
    expect(requests, isEmpty);
    handler.dispose();
    refresh.dispose();
  });

  testWidgets(
    'expired link displays a recoverable screen instead of failing silently',
    (tester) async {
      final events = StreamController<AuthState>(sync: true);
      final refresh = GoRouterRefreshStream(events.stream);
      final container = ProviderContainer(
        overrides: [authRefreshProvider.overrideWithValue(refresh)],
      );
      events.addError(
        const AuthException('private backend text', code: 'otp_expired'),
      );
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This link could not be opened.'), findsOneWidget);
      expect(find.textContaining('private backend text'), findsNothing);
      router.go(AppRoutes.forgotPass);
      await tester.pumpAndSettle();
      expect(find.text('Send Reset Link'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await tester.runAsync(() async {
        refresh.dispose();
        await events.close();
      });
    },
  );
}
