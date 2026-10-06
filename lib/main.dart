// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/hive_service.dart';
import 'services/hybrid_storage_service.dart';
import 'services/auth_callback_handler.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'providers/settings_provider.dart';
import 'navigation/app_router.dart';
import 'widgets/app_feedback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // AuthCallbackHandler verifies and routes both PKCE and legacy email links.
    authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
  );

  // Capture recovery callbacks before local storage and sync initialization.
  final container = ProviderContainer();
  final callbacks = AuthCallbackHandler(
    Supabase.instance.client.auth,
    container.read(authRefreshProvider),
  );
  await callbacks.initialize();

  await HiveService().initialize();

  // ✅ FIX: Initialize HybridStorageService to start connectivity + sync
  await HybridStorageService().initialize();

  runApp(
    UncontrolledProviderScope(container: container, child: const LankarApp()),
  );
}

class LankarApp extends ConsumerWidget {
  const LankarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: AppFeedback.messengerKey,
      builder: (context, child) => AuthFeedbackListener(child: child!),
      title: 'Lankar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
