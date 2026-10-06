import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/auth_design.dart' show BrandLockup;
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/sync_indicator_widget.dart';
import '../../widgets/home/home_motion.dart';
import '../../widgets/home/total_balance_card.dart';
import '../../widgets/home/quick_actions_row.dart';
import '../../widgets/home/home_books_section.dart';
import '../../widgets/home/premium_banner.dart';
import '../../widgets/home/monthly_summary_card.dart';
import '../../navigation/main_shell.dart';

final allEntriesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final books = ref.watch(booksProvider).asData?.value ?? [];
      if (books.isEmpty) return [];
      final batches = await Future.wait(
        books.map((book) => HiveService().getEntries(book['id'] as String)),
      );
      final entries = batches.expand((batch) => batch).toList();
      DateTime date(Map<String, dynamic> entry) =>
          DateTime.tryParse(
            entry['entry_date'] as String? ??
                entry['created_at'] as String? ??
                '',
          ) ??
          DateTime(2000);
      entries.sort((a, b) => date(b).compareTo(date(a)));
      return entries;
    });

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final booksAsync = ref.watch(booksProvider);
    final entriesAsync = ref.watch(allEntriesProvider);
    final signedIn = ref.watch(isLoggedInProvider);
    final firstName = ref.watch(userDisplayNameProvider);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rate = settings.exchangeRate;
    final symbol = settings.currencySymbol;
    void openBooks() => ref.read(selectedTabProvider.notifier).state = 1;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [const Color(0xFF0C1E2C), const Color(0xFF102A3C)]
                  : [
                      const Color(0xFFF2F8FC),
                      const Color(0xFFE9F3FA),
                      const Color(0xFFF7FAFD),
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: !signedIn
                    ? _LoggedOutView(onLogin: () => context.go(AppRoutes.login))
                    : booksAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => AppErrorView(
                          error: error,
                          onRetry: () =>
                              ref.read(booksProvider.notifier).loadBooks(),
                        ),
                        data: (books) {
                          final balance = books.fold<double>(
                            0,
                            (sum, book) =>
                                sum +
                                ((book['balance'] as num?)?.toDouble() ?? 0),
                          );
                          final now = DateTime.now();
                          double monthIncome = 0, monthExpense = 0;
                          for (final entry
                              in entriesAsync.asData?.value ??
                                  <Map<String, dynamic>>[]) {
                            final date = DateTime.tryParse(
                              entry['entry_date'] as String? ??
                                  entry['created_at'] as String? ??
                                  '',
                            );
                            if (date == null ||
                                date.year != now.year ||
                                date.month != now.month) {
                              continue;
                            }
                            final amount =
                                (entry['amount'] as num?)?.toDouble() ?? 0;
                            if (entry['is_income'] == true) {
                              monthIncome += amount;
                            } else {
                              monthExpense += amount;
                            }
                          }
                          return RefreshIndicator(
                            onRefresh: () async {
                              await ref
                                  .read(booksProvider.notifier)
                                  .loadBooks();
                              ref.invalidate(allEntriesProvider);
                            },
                            child: ListView(
                              key: const PageStorageKey('home-dashboard'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                18,
                                20,
                                32,
                              ),
                              children: [
                                HomeReveal(
                                  child: Row(
                                    children: [
                                      const BrandLockup(
                                        size: 46,
                                        showName: false,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'YOUR MONEY, IN FOCUS',
                                              style: TextStyle(
                                                fontSize: 9,
                                                letterSpacing: 1.4,
                                                fontWeight: FontWeight.w700,
                                                color: scheme.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Hello, $firstName.',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -.8,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filledTonal(
                                        tooltip: 'Change currency',
                                        onPressed: () =>
                                            CurrencyPickerWidget.show(context),
                                        icon: const Icon(
                                          Icons.currency_exchange_rounded,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    Text(
                                      'A little clarity. A lot of possibility.',
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SyncIndicator(),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                HomeReveal(
                                  order: 1,
                                  child: TotalBalanceCard(
                                    displayBalance: balance / rate,
                                    symbol: symbol,
                                    bookCount: books.length,
                                    monthIncome: entriesAsync.hasValue
                                        ? monthIncome / rate
                                        : null,
                                    monthExpense: entriesAsync.hasValue
                                        ? monthExpense / rate
                                        : null,
                                    activityLoading: entriesAsync.isLoading,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                HomeReveal(
                                  order: 2,
                                  child: QuickActionsRow(
                                    onBooksTap: openBooks,
                                    onReportsTap: () =>
                                        ref
                                                .read(
                                                  selectedTabProvider.notifier,
                                                )
                                                .state =
                                            2,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                HomeReveal(
                                  order: 3,
                                  child: entriesAsync.when(
                                    loading: () => Container(
                                      height: 240,
                                      decoration: BoxDecoration(
                                        color: scheme.surface,
                                        borderRadius: BorderRadius.circular(28),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    error: (error, _) => AppErrorView(
                                      error: error,
                                      onRetry: () async {
                                        ref.invalidate(allEntriesProvider);
                                        await ref.read(
                                          allEntriesProvider.future,
                                        );
                                      },
                                    ),
                                    data: (entries) => MonthlySummaryCard(
                                      allEntries: entries,
                                      currencySymbol: symbol,
                                      exchangeRate: rate,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                HomeReveal(
                                  order: 4,
                                  child: HomeBooksSection(
                                    books: books,
                                    symbol: symbol,
                                    rate: rate,
                                    onSeeAll: openBooks,
                                    onBookChanged: () => ref
                                        .read(booksProvider.notifier)
                                        .loadBooks(),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const HomeReveal(
                                  order: 5,
                                  child: PremiumBanner(),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoggedOutView extends StatelessWidget {
  const _LoggedOutView({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: HomeReveal(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLockup(),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: brandNavy,
                borderRadius: BorderRadius.circular(36),
              ),
              padding: const EdgeInsets.all(20),
              child: const GrowthSculpture(size: 160),
            ),
            const SizedBox(height: 30),
            const Text(
              'Your money.\nA clearer picture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                letterSpacing: -1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to track your spending, grow your savings, and keep your cash books together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onLogin,
                child: const Text('Sign in to Lankar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
