// lib/navigation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home/home_screen.dart';
import '../screens/books/book_list_screen.dart';
import '../screens/reports/reports_tab_screen.dart';
import '../screens/analytics/analytics_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../utils/constants.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: const [
          HomeScreen(),
          BookListScreen(),
          ReportsTabScreen(),
          AnalyticsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: selectedIndex,
        onTap: (i) => ref.read(selectedTabProvider.notifier).state = i,
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  static const _items = [
    _NavItemData(
      icon:       Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label:      'Home',
    ),
    _NavItemData(
      icon:       Icons.book_outlined,
      activeIcon: Icons.book_rounded,
      label:      'Books',
    ),
    _NavItemData(
      icon:       Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label:      'Reports',
    ),
    _NavItemData(
      icon:       Icons.donut_large_outlined,
      activeIcon: Icons.donut_large_rounded,
      label:      'Analytics',
    ),
    _NavItemData(
      icon:       Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label:      'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              return _NavItem(
                data:       _items[i],
                isSelected: selectedIndex == i,
                onTap:      () => onTap(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? primaryRed.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? data.activeIcon : data.icon,
                key: ValueKey(isSelected),
                color: isSelected ? primaryRed : Colors.grey[500],
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryRed : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}