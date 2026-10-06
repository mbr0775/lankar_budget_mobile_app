import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/books_design.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/dimensional_design.dart';
import '../../widgets/profile_design.dart';
import '../../widgets/home/home_motion.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

final profileAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (build ${info.buildNumber})';
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _confirming = false;
  bool _signingOut = false;

  Future<void> _confirmSignOut() async {
    if (_confirming || _signingOut) return;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          icon: Icon(
            Icons.logout_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 30,
          ),
          title: const Text('Sign out of Lankar?'),
          content: const Text(
            'You can sign back in whenever you need your cash books.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay signed in'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _signingOut = true);
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (error, stack) {
      AppErrors.report('Sign out', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Could not sign out. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _confirming = false;
          _signingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isLoggedInProvider);
    final scheme = Theme.of(context).colorScheme;
    if (!signedIn) {
      return DimensionalPage(
        title: 'Profile',
        children: [
          const DimensionalHeading(
            title: 'Your space in Lankar',
            subtitle: 'Keep your account and preferences together.',
          ),
          const SizedBox(height: 28),
          const Center(child: ProfileMedallion(initials: 'L')),
          const SizedBox(height: 28),
          BooksEmptyState(
            title: 'You are signed out',
            message:
                'Sign in to manage your profile, sync your cash books, and access your preferences.',
            actionLabel: 'Sign in to Lankar',
            onAction: () => context.go(AppRoutes.login),
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go(AppRoutes.signup),
            child: const Text('Create account'),
          ),
        ],
      );
    }
    final settings = ref.watch(settingsProvider);
    final name = ref.watch(userFullNameProvider);
    final email = ref.watch(currentUserProvider)?.email ?? '';
    final version = ref.watch(profileAppVersionProvider);
    final dark = scheme.brightness == Brightness.dark;
    return DimensionalPage(
      title: 'Profile',
      children: [
        const DimensionalHeading(
          title: 'Make it yours',
          subtitle: 'Your account, your preferences, your pace.',
        ),
        const SizedBox(height: 24),
        HomeReveal(
          child: ProfileIdentityCard(name: name, email: email),
        ),
        const SizedBox(height: 26),
        _section(context, 'Preferences'),
        const SizedBox(height: 12),
        HomeReveal(
          order: 1,
          child: DepthAction(
            title: '${settings.currency.name} (${settings.currencySymbol})',
            subtitle: 'Active currency',
            icon: Icons.currency_exchange_rounded,
            onTap: () => CurrencyPickerWidget.show(context),
          ),
        ),
        const SizedBox(height: 14),
        HomeReveal(
          order: 2,
          child: DepthAction(
            title: dark ? 'Dark appearance' : 'Light appearance',
            subtitle: 'Tap to switch your theme',
            icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            color: const Color(0xFF7664B8),
            onTap: () async {
              try {
                await ref
                    .read(settingsProvider.notifier)
                    .setDarkMode(!settings.isDarkMode);
              } catch (error, stack) {
                AppErrors.report('Change appearance', error, stack);
                if (context.mounted) AppFeedback.error(context, error);
              }
            },
          ),
        ),
        const SizedBox(height: 28),
        _section(context, 'Account'),
        const SizedBox(height: 12),
        DepthAction(
          title: 'Go Premium',
          subtitle: 'Explore more ways to manage your money',
          icon: Icons.workspace_premium_rounded,
          color: const Color(0xFFB7802E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
          ),
        ),
        const SizedBox(height: 14),
        DepthAction(
          title: 'Settings',
          subtitle: 'Account, sync, and app preferences',
          icon: Icons.settings_rounded,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
        const SizedBox(height: 28),
        _section(context, 'About Lankar'),
        const SizedBox(height: 12),
        const DepthAction(
          title: 'Privacy policy',
          icon: Icons.privacy_tip_outlined,
          color: Color(0xFF387BA4),
          onTap: null,
        ),
        const SizedBox(height: 14),
        DepthAction(
          title: 'App version',
          subtitle: version.when(
            data: (value) => value,
            loading: () => 'Loading version...',
            error: (_, _) => 'Version unavailable',
          ),
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF6D879A),
          onTap: null,
        ),
        const SizedBox(height: 26),
        DepthAction(
          title: _signingOut ? 'Signing out...' : 'Sign out',
          subtitle: 'See you again soon',
          icon: Icons.logout_rounded,
          color: const Color(0xFFC34B56),
          onTap: _signingOut || _confirming ? null : _confirmSignOut,
          trailing: _signingOut
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      ],
    );
  }

  Widget _section(BuildContext context, String title) => Text(
    title,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: -.3,
    ),
  );
}
