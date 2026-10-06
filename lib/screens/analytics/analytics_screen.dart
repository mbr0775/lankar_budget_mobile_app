import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../navigation/main_shell.dart' show selectedTabProvider;
import '../../providers/analytics_provider.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/analytics_data.dart';
import '../../utils/constants.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/analytics_design.dart';
import '../../widgets/books_design.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../widgets/dimensional_design.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  bool _refreshing = false;
  Future<void> _refresh() async {
    if (_refreshing || !ref.read(isLoggedInProvider)) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(booksProvider.notifier).loadBooks();
      if (mounted) ref.invalidate(analyticsEntriesProvider);
    } catch (error, stack) {
      AppErrors.report('Refresh analytics', error, stack);
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isLoggedInProvider);
    final books = ref.watch(booksProvider);
    final entries = signedIn ? ref.watch(analyticsEntriesProvider) : null;
    final settings = ref.watch(settingsProvider);
    final scheme = Theme.of(context).colorScheme;
    return DimensionalPage(
      title: 'Analytics',
      onRefresh: _refresh,
      actions: [
        IconButton(
          tooltip: 'Change currency',
          icon: const Icon(Icons.currency_exchange_rounded),
          onPressed: () => CurrencyPickerWidget.show(context),
        ),
        IconButton(
          tooltip: 'Refresh analytics',
          onPressed: _refreshing || !signedIn ? null : _refresh,
          icon: _refreshing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
      children: [
        const DimensionalHeading(
          title: 'Money in motion',
          subtitle: 'Explore the patterns across your cash books.',
        ),
        const SizedBox(height: 22),
        if (!signedIn)
          BooksEmptyState(
            title: 'Sign in for analytics',
            message: 'See your spending, savings, and trends together.',
            actionLabel: 'Sign in to Lankar',
            icon: Icons.donut_large_rounded,
            onAction: () => context.go(AppRoutes.login),
          )
        else if (books.hasError)
          AppErrorView(error: books.error!, onRetry: _refresh)
        else if (books.isLoading && !books.hasValue ||
            entries!.isLoading && !entries.hasValue)
          const Padding(
            padding: EdgeInsets.all(56),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (entries.hasError)
          AppErrorView(error: entries.error!, onRetry: _refresh)
        else if (books.valueOrNull?.isEmpty ?? true)
          BooksEmptyState(
            title: 'Start with a cash book',
            message:
                'Your entries will turn into charts and spending insights here.',
            actionLabel: 'Go to cash books',
            icon: Icons.auto_stories_rounded,
            onAction: () => ref.read(selectedTabProvider.notifier).state = 1,
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final period in AnalyticsPeriod.values)
                ChoiceChip(
                  key: ValueKey(period),
                  label: Text(period.label),
                  selected: _period == period,
                  onSelected: (_) => setState(() => _period = period),
                  showCheckmark: false,
                  selectedColor: scheme.primary,
                  backgroundColor: scheme.surface,
                  side: BorderSide(
                    color: _period == period
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: .6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelStyle: TextStyle(
                    color: _period == period
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  elevation: 0,
                  pressElevation: 0,
                ),
            ],
          ),
          const SizedBox(height: 22),
          AnalyticsDashboard(
            data: AnalyticsSnapshot(
              entries: entries.valueOrNull ?? [],
              period: _period,
              now: DateTime.now(),
            ),
            symbol: settings.currencySymbol,
            rate: settings.exchangeRate,
            bookCount: books.valueOrNull!.length,
          ),
        ],
      ],
    );
  }
}
