import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lankar/navigation/app_router.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/screens/auth/login_screen.dart';
import 'package:lankar/services/auth_service.dart';
import 'package:lankar/services/hive_service.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/services/supabase_service.dart';
import 'package:lankar/utils/app_errors.dart';
import 'package:lankar/utils/app_theme.dart';
import 'package:lankar/widgets/app_feedback.dart';
import 'package:lankar/widgets/entry_dialog_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final user = {
    'id': 'user-1',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'test@example.com',
    'created_at': '2026-01-01T00:00:00Z',
  };
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.${base64Url.encode(utf8.encode('{"sub":"user-1","exp":2000000000}'))}.signature';
  final session = {
    'access_token': token,
    'refresh_token': 'refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': user,
  };
  late Directory directory;
  final hive = HiveService();
  final storage = HybridStorageService();
  String mode = 'normal';
  int profileWrites = 0;
  int writes = 0;
  http.BaseRequest? currentRequest;
  http.Response jsonResponse(Object body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
    request: currentRequest,
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('lankar_feedback_test_');
    Hive.init(directory.path);
    hive.booksBox = await Hive.openBox<Map>('books');
    hive.entriesBox = await Hive.openBox<Map>('entries');
    hive.syncQueueBox = await Hive.openBox<Map>('sync_queue');
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
        autoRefreshToken: false,
      ),
      httpClient: MockClient((request) async {
        currentRequest = request;
        final path = request.url.path;
        if (path.endsWith('/token')) {
          return mode == 'bad-login'
              ? jsonResponse({
                  'code': 'invalid_credentials',
                  'msg': 'raw private diagnostics',
                }, 400)
              : jsonResponse(session, 200);
        }
        if (path.endsWith('/signup')) return jsonResponse(user, 200);
        if (path.endsWith('/recover')) {
          return mode == 'reset-failed'
              ? jsonResponse({
                  'code': 'over_email_send_rate_limit',
                  'msg': 'private diagnostics',
                }, 429)
              : jsonResponse({}, 200);
        }
        if (path.endsWith('/profiles')) {
          profileWrites++;
          return jsonResponse({}, 200);
        }
        if (path.contains('/rest/v1/')) {
          writes++;
          if (mode == 'network-failed') {
            throw const SocketException('private host');
          }
          if (mode == 'denied') {
            return jsonResponse({
              'code': '42501',
              'message': 'private SQL details',
            }, 403);
          }
          if (request.method == 'POST') {
            return jsonResponse({
              'id': 'remote-entry',
              'book_id': 'book-1',
              'amount': 10,
              'is_income': true,
            }, 200);
          }
          return jsonResponse(
            request.headers['Accept']?.contains('object') == true
                ? {'id': 'book-1'}
                : [],
            200,
          );
        }
        return jsonResponse({}, 200);
      }),
    );
    SupabaseService().assignClient();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (_) async => 'none',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );
  });
  setUp(() async {
    mode = 'normal';
    profileWrites = 0;
    writes = 0;
    await hive.booksBox.clear();
    await hive.entriesBox.clear();
    await hive.syncQueueBox.clear();
  });
  tearDownAll(() async {
    storage.dispose();
    await Supabase.instance.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'errors are safe, actionable, and only connection failures can save offline',
    () {
      expect(
        AppErrors.from(
          const AuthException('secret', code: 'invalid_credentials'),
        ).message,
        contains('email and password'),
      );
      expect(
        AppErrors.from(
          const AuthException('secret', code: 'email_not_confirmed'),
        ).title,
        'Confirm your email',
      );
      expect(
        AppErrors.from(const AuthException('secret', statusCode: '429')).title,
        'Please wait a moment',
      );
      expect(
        AppErrors.from(PlatformException(code: 'sign_in_canceled')).kind,
        FailureKind.cancelled,
      );
      expect(
        AppErrors.canSaveOffline(const SocketException('secret host')),
        isTrue,
      );
      expect(
        AppErrors.canSaveOffline(
          const PostgrestException(message: 'secret SQL', code: '42501'),
        ),
        isFalse,
      );
      expect(
        AppErrors.from(Exception('secret token')).message,
        isNot(contains('secret')),
      );
    },
  );

  test(
    'signup confirmation emits a notice without an unauthenticated profile write',
    () async {
      final notices = <AuthNotice>[];
      final sub = AuthService().notices.listen(notices.add);
      final result = await AuthService().signUp(
        email: 'test@example.com',
        password: 'password123',
        fullName: 'Test User',
      );
      await Future<void>.delayed(Duration.zero);
      expect(result.session, isNull);
      expect(notices, [AuthNotice.confirmEmail]);
      expect(profileWrites, 0);
      await sub.cancel();
    },
  );

  test(
    'reset errors propagate through the provider and never emit success',
    () async {
      mode = 'reset-failed';
      final notices = <AuthNotice>[];
      final sub = AuthService().notices.listen(notices.add);
      final container = ProviderContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      await expectLater(
        notifier.resetPassword('test@example.com'),
        throwsA(isA<AuthException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authNotifierProvider).hasError, isTrue);
      expect(notices, isEmpty);
      mode = 'normal';
      await notifier.resetPassword('test@example.com');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authNotifierProvider).hasError, isFalse);
      expect(notices, [AuthNotice.passwordReset]);
      container.dispose();
      await sub.cancel();
    },
  );

  test(
    'sign-out preserves pending data and an authenticated session',
    () async {
      await AuthService().signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      await hive.syncQueueBox.put('pending', {
        'id': 'pending',
        'operation': 'create_book',
      });
      final container = ProviderContainer();
      final notifier = container.read(authNotifierProvider.notifier);
      await expectLater(notifier.signOut(), throwsA(isA<AppFailure>()));
      expect(hive.syncQueueBox.length, 1);
      expect(AuthService().currentSession, isNotNull);
      container.dispose();
    },
  );

  test(
    'exhausted sync operations survive startup and manual retry reports real completion',
    () async {
      await AuthService().signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      await hive.booksBox.put('book-1', {
        'id': 'book-1',
        'name': 'Test',
        'synced': false,
      });
      await hive.syncQueueBox.put('pending', {
        'id': 'pending',
        'operation': 'update_book',
        'data': {'id': 'book-1', 'name': 'Test', 'balance': 0},
        'timestamp': '2026-01-01T00:00:00Z',
        'retries': 3,
      });
      await storage.initialize();
      expect(hive.syncQueueBox.length, 1);
      expect(await storage.syncWithSupabase(), isFalse);
      expect(writes, 0);
      mode = 'denied';
      expect(await storage.syncWithSupabase(retryFailed: true), isFalse);
      expect(hive.syncQueueBox.length, 1);
      mode = 'normal';
      expect(await storage.syncWithSupabase(retryFailed: true), isTrue);
      expect(hive.syncQueueBox.length, 0);
    },
  );

  test(
    'rejected entry writes propagate; connection failures save locally',
    () async {
      await AuthService().signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      await storage.syncWithSupabase();
      mode = 'denied';
      await expectLater(
        storage.createEntry(
          bookId: 'book-1',
          amount: 10,
          description: 'Test',
          isIncome: true,
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(hive.entriesBox.length, 0);
      expect(hive.syncQueueBox.length, 0);
      mode = 'network-failed';
      final entry = await storage.createEntry(
        bookId: 'book-1',
        amount: 10,
        description: 'Test',
        isIncome: true,
      );
      expect(entry?['synced'], isFalse);
      expect(hive.syncQueueBox.length, 1);
    },
  );

  test(
    'a cache failure after a remote insert does not create a second entry',
    () async {
      await AuthService().signIn(
        email: 'test@example.com',
        password: 'password123',
      );
      await storage.syncWithSupabase();
      await hive.entriesBox.close();
      try {
        final entry = await storage.createEntry(
          bookId: 'book-1',
          amount: 10,
          description: 'Test',
          isIncome: true,
        );
        expect(entry?['id'], 'remote-entry');
        expect(entry?['synced'], isTrue);
        expect(writes, 1);
        expect(hive.syncQueueBox.length, 0);
      } finally {
        hive.entriesBox = await Hive.openBox<Map>('entries');
      }
    },
  );

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: AppFeedback.messengerKey,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: AuthFeedbackListener(child: child!),
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'login success survives an auth-triggered route replacement exactly once',
    (tester) async {
      await tester.runAsync(
        () => Supabase.instance.client.auth.signOut(scope: SignOutScope.local),
      );
      final refresh = GoRouterRefreshStream(AuthService().authStateChanges);
      final router = GoRouter(
        initialLocation: '/login',
        refreshListenable: refresh,
        redirect: (context, state) =>
            AuthService().isLoggedIn && state.matchedLocation == '/login'
            ? '/home'
            : null,
        routes: [
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(refresh.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          scaffoldMessengerKey: AppFeedback.messengerKey,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: AuthFeedbackListener(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byType(FeedbackCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed entry save preserves the form and retry succeeds without duplicate submissions',
    (tester) async {
      final pending = Completer<bool>();
      int calls = 0;
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EntryDialogWidget(
                    isIncome: true,
                    currencySymbol: 'Rs',
                    exchangeRate: 1,
                    isSyncPending: () => true,
                    onSave:
                        ({
                          required double amount,
                          required String description,
                          required bool isIncome,
                          required DateTime entryDate,
                          String? entryId,
                        }) async {
                          calls++;
                          return calls == 1 ? false : pending.future;
                        },
                  ),
                ),
                child: const Text('Open entry'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open entry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '100');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Keep this description',
      );
      await tester.ensureVisible(find.text('Add Cash In'));
      await tester.tap(find.text('Add Cash In'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryDialogWidget), findsOneWidget);
      expect(find.text('Entry not saved'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        'Keep this description',
      );
      await tester.ensureVisible(find.text('Add Cash In'));
      await tester.tap(find.text('Add Cash In'));
      await tester.pump();
      expect(calls, 2);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Open entry'),
            )
            .onPressed,
        isNotNull,
      );
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(EntryDialogWidget), findsNothing);
      expect(find.text('Income added'), findsOneWidget);
      expect(
        find.text(
          'Saved on this device. It will sync when a connection is available.',
        ),
        findsOneWidget,
      );
      expect(calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
