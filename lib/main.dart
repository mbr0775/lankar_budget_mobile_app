// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/hive_service.dart';
import 'services/hybrid_storage_service.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';
import 'providers/settings_provider.dart';
import 'navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url:     SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await HiveService().initialize();

  // ✅ FIX: Initialize HybridStorageService to start connectivity + sync
  await HybridStorageService().initialize();

  runApp(const ProviderScope(child: LankarApp()));
}

class LankarApp extends ConsumerWidget {
  const LankarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router   = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lankar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}