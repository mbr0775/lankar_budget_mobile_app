// lib/navigation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home/home_screen.dart';
import '../screens/books/book_list_screen.dart';
import '../screens/reports/reports_tab_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'app_bottom_nav.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          TickerMode(enabled: selectedIndex == 0, child: const HomeScreen()),
          TickerMode(
            enabled: selectedIndex == 1,
            child: const BookListScreen(),
          ),
          TickerMode(
            enabled: selectedIndex == 2,
            child: const ReportsTabScreen(),
          ),
          TickerMode(
            enabled: selectedIndex == 3,
            child: const AnalyticsScreen(),
          ),
          TickerMode(enabled: selectedIndex == 4, child: const ProfileScreen()),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: selectedIndex,
        onTap: (i) => ref.read(selectedTabProvider.notifier).state = i,
      ),
    );
  }
}
