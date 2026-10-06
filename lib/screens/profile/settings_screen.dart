// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../services/hybrid_storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) return;
    final storage = HybridStorageService();
    if (storage.isSyncing) {
      AppFeedback.info(
        context,
        'Sync in progress',
        'Your changes are already being synced.',
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final complete = await storage.syncWithSupabase(retryFailed: true);
      if (!mounted) return;
      if (complete) {
        AppFeedback.success(
          context,
          'All changes synced',
          'Your cash books are up to date.',
        );
      } else {
        AppFeedback.error(
          context,
          storage.lastSyncFailure ??
              const AppFailure(
                'Some changes still need to sync',
                'Your pending changes are kept on this device. Check your connection and retry.',
              ),
        );
      }
    } catch (error, stack) {
      AppErrors.report('Settings sync', error, stack);
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final fullName = ref.watch(userFullNameProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ── Top App Bar (home screen style) ──────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your preferences',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Account info (only when logged in) ───────────────────
                  if (isLoggedIn) ...[
                    _SectionHeader(title: 'ACCOUNT'),
                    const SizedBox(height: 10),
                    _SettingsCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar circle with first letter
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [primaryBlue, secondaryBlue],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    fullName.isNotEmpty
                                        ? fullName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Appearance ────────────────────────────────────────────
                  _SectionHeader(title: 'APPEARANCE'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _ToggleTile(
                        icon: settings.isDarkMode
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        title: 'Dark mode',
                        subtitle: 'Switch app theme',
                        value: settings.isDarkMode,
                        onChanged: (v) => notifier.setDarkMode(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Currency ──────────────────────────────────────────────
                  _SectionHeader(title: 'CURRENCY'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: Currency.values.map((currency) {
                      final isSelected = settings.currency == currency;
                      return Column(
                        children: [
                          _CurrencyTile(
                            currency: currency,
                            isSelected: isSelected,
                            onTap: () => notifier.setCurrency(currency),
                          ),
                          if (currency != Currency.values.last)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Data & Sync ───────────────────────────────────────────
                  _SectionHeader(title: 'DATA & SYNC'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      _ActionTile(
                        icon: Icons.sync,
                        iconColor: const Color(0xFF185FA5),
                        title: _syncing ? 'Syncing...' : 'Sync now',
                        subtitle: 'Manually push local changes',
                        onTap: !isLoggedIn || _syncing ? null : _syncNow,
                        showArrow: false,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ActionTile(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: const Color(0xFF0F6E56),
                        title: 'Privacy policy',
                        subtitle: 'Read our privacy policy',
                        onTap: () {},
                        showArrow: true,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ActionTile(
                        icon: Icons.info_outline,
                        iconColor: Colors.blueGrey,
                        title: 'App version',
                        subtitle: '1.0.0 (build 1)',
                        onTap: null,
                        showArrow: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Auth button ───────────────────────────────────────────
                  // Shows "Sign Out" when logged in, "Login" when logged out
                  _SectionHeader(title: isLoggedIn ? 'SESSION' : 'GET STARTED'),
                  const SizedBox(height: 10),
                  _SettingsCard(
                    children: [
                      isLoggedIn
                          ? _ActionTile(
                              icon: Icons.logout,
                              iconColor: Colors.red,
                              title: 'Sign Out',
                              subtitle: 'You will be logged out of Lankar',
                              labelColor: Colors.red,
                              onTap: () => _confirmSignOut(context, ref),
                              showArrow: false,
                            )
                          : _ActionTile(
                              icon: Icons.login,
                              iconColor: primaryBlue,
                              title: 'Login',
                              subtitle: 'Sign in to sync your data',
                              labelColor: primaryBlue,
                              onTap: () => context.go(AppRoutes.login),
                              showArrow: true,
                            ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (error, stack) {
      AppErrors.report('Sign out', error, stack);
      AppFeedback.globalError(
        error,
        fallback: 'Could not sign out. Please try again.',
      );
    }
  }
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF6C757D),
      letterSpacing: 1.1,
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primaryBlue, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: primaryBlue,
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? labelColor;
  final VoidCallback? onTap;
  final bool showArrow;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.labelColor,
    required this.onTap,
    required this.showArrow,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: labelColor ?? const Color(0xFF212529),
      ),
    ),
    subtitle: Text(
      subtitle,
      style: TextStyle(color: Colors.grey[500], fontSize: 12),
    ),
    trailing: showArrow
        ? Icon(Icons.chevron_right, color: Colors.grey[400])
        : null,
    onTap: onTap,
  );
}

class _CurrencyTile extends StatelessWidget {
  final Currency currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyTile({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbols[currency]!;
    final name = currency.toString().split('.').last;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: primaryBlue, size: 22),
          ],
        ),
      ),
    );
  }
}
