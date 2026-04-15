// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/sync_indicator_widget.dart';
import '../../widgets/home/total_balance_card.dart';
import '../../widgets/home/quick_actions_row.dart';
import '../../widgets/home/home_books_section.dart';
import '../../widgets/home/premium_banner.dart';
import '../../widgets/home/monthly_summary_card.dart';
import '../../navigation/main_shell.dart';

final allEntriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final booksState = ref.watch(booksProvider);
  final books      = booksState.asData?.value ?? [];
  if (books.isEmpty) return [];

  final hive = HiveService();
  final all  = <Map<String, dynamic>>[];
  await Future.wait(books.map((book) async {
    final entries = await hive.getEntries(book['id'] as String);
    all.addAll(entries);
  }));

  all.sort((a, b) {
    final da = DateTime.tryParse(
            a['entry_date'] as String? ?? a['created_at'] as String? ?? '') ??
        DateTime(2000);
    final db = DateTime.tryParse(
            b['entry_date'] as String? ?? b['created_at'] as String? ?? '') ??
        DateTime(2000);
    return db.compareTo(da);
  });
  return all;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings        = ref.watch(settingsProvider);
    final booksAsync      = ref.watch(booksProvider);
    final allEntriesAsync = ref.watch(allEntriesProvider);
    final isLoggedIn      = ref.watch(isLoggedInProvider);
    final firstName       = ref.watch(userDisplayNameProvider);
    final symbol          = settings.currencySymbol;
    final rate            = settings.exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLoggedIn ? 'Hello, $firstName! 👋' : 'Welcome to Lankar 👋',
              style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              isLoggedIn ? 'Welcome to Lankar' : 'Sign in to manage your cash',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          // ── Show Login button when logged out ─────────────────────────
          if (!isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => context.go(AppRoutes.login),
                icon: const Icon(Icons.login, size: 16, color: primaryRed),
                label: const Text('Login',
                    style: TextStyle(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: primaryRed.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                ),
              ),
            ),
          // ── Show currency + sync when logged in ───────────────────────
          if (isLoggedIn) ...[
            IconButton(
              icon: const Icon(Icons.attach_money, color: Colors.black87),
              onPressed: () => CurrencyPickerWidget.show(context),
            ),
            const SyncIndicator(),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: booksAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: primaryRed)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (books) {
          final totalBalance = books.fold<double>(
            0,
            (sum, b) => sum + ((b['balance'] as num?)?.toDouble() ?? 0),
          );
          final allEntries = allEntriesAsync.asData?.value ?? [];

          // ── Logged out state ────────────────────────────────────────────
          if (!isLoggedIn) {
            return _LoggedOutView(
              onLogin: () => context.go(AppRoutes.login),
            );
          }

          // ── Logged in state ─────────────────────────────────────────────
          return RefreshIndicator(
            color: primaryRed,
            onRefresh: () async {
              await ref.read(booksProvider.notifier).loadBooks();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TotalBalanceCard(
                  displayBalance: totalBalance / rate,
                  symbol:         symbol,
                  bookCount:      books.length,
                ),
                const SizedBox(height: 24),
                QuickActionsRow(
                  onBooksTap: () =>
                      ref.read(selectedTabProvider.notifier).state = 1,
                  onReportsTap: () {
                    if (books.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Create a book first to view reports.'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    } else {
                      ref.read(selectedTabProvider.notifier).state = 1;
                    }
                  },
                ),
                const SizedBox(height: 24),
                allEntriesAsync.when(
                  loading: () => const _ChartSkeleton(),
                  error:   (_, __) => const SizedBox.shrink(),
                  data:    (_) => MonthlySummaryCard(
                    allEntries:     allEntries,
                    currencySymbol: symbol,
                    exchangeRate:   rate,
                  ),
                ),
                const SizedBox(height: 24),
                HomeBooksSection(
                  books:         books,
                  symbol:        symbol,
                  rate:          rate,
                  onBookChanged: () =>
                      ref.read(booksProvider.notifier).loadBooks(),
                ),
                const SizedBox(height: 24),
                const PremiumBanner(),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Logged-out placeholder ─────────────────────────────────────────────────

class _LoggedOutView extends StatelessWidget {
  final VoidCallback onLogin;
  const _LoggedOutView({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_circle_outlined,
                  size: 50, color: primaryRed),
            ),
            const SizedBox(height: 24),
            const Text('You\'re not signed in',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 10),
            Text(
              'Sign in to view your books, track expenses and sync your data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton + Bone widgets ────────────────────────────────────────────────

class _ChartSkeleton extends StatefulWidget {
  const _ChartSkeleton();
  @override
  State<_ChartSkeleton> createState() => _ChartSkeletonState();
}

class _ChartSkeletonState extends State<_ChartSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final o = 0.04 + _anim.value * 0.06;
        return Container(
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _Bone(width: 34, height: 34, radius: 10, opacity: o),
                const SizedBox(width: 10),
                _Bone(width: 130, height: 14, radius: 6, opacity: o),
                const Spacer(),
                _Bone(width: 90, height: 20, radius: 8, opacity: o),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Bone(height: 48, radius: 12, opacity: o)),
                const SizedBox(width: 10),
                Expanded(child: _Bone(height: 48, radius: 12, opacity: o)),
              ]),
              const SizedBox(height: 14),
              Expanded(child: _Bone(width: double.infinity, radius: 12, opacity: o)),
            ],
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final double opacity;
  const _Bone({this.width, this.height, required this.radius, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}