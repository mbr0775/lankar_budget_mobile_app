import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import '../utils/report_data.dart';
import 'cash_book_design.dart';
import 'home/home_motion.dart';

class ReportHeading extends StatelessWidget {
  const ReportHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  );
}

class ReportsOverview extends StatelessWidget {
  const ReportsOverview({
    super.key,
    required this.entries,
    required this.symbol,
    required this.rate,
  });
  final List<Map<String, dynamic>> entries;
  final String symbol;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final income = reportTotal(entries, true) / rate;
    final expense = reportTotal(entries, false) / rate;
    final recent = sortedReportEntries(entries).take(10).toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeReveal(
          child: CashBalanceCard(
            income: income,
            expense: expense,
            symbol: symbol,
            count: entries.length,
          ),
        ),
        const SizedBox(height: 20),
        HomeReveal(
          order: 1,
          child: _CashFlow(income: income, expense: expense, symbol: symbol),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent transactions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length}',
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          entries.length > 10
              ? 'Latest 10 entries. The PDF includes your full history.'
              : 'Your latest entries, newest first.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          ReportPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: scheme.primary,
                  size: 28,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No transactions yet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add income or an expense in this cash book to see its activity here.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          )
        else
          ...recent.map(
            (entry) =>
                ReportTransaction(entry: entry, symbol: symbol, rate: rate),
          ),
      ],
    );
  }
}

class ReportPanel extends StatelessWidget {
  const ReportPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
      ),
      child: child,
    );
  }
}

class _CashFlow extends StatelessWidget {
  const _CashFlow({
    required this.income,
    required this.expense,
    required this.symbol,
  });
  final double income;
  final double expense;
  final String symbol;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final maxAmount = math.max(income, expense);
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cash flow',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Income and expenses, side by side.',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 22),
          for (final flow in [(true, income), (false, expense)]) ...[
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    flow.$1 ? 'Income' : 'Expense',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$symbol ${formatCurrency(flow.$2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label:
                  '${flow.$1 ? 'Income' : 'Expense'} $symbol ${formatCurrency(flow.$2)}',
              child: LinearProgressIndicator(
                value: maxAmount <= 0
                    ? 0
                    : (flow.$2 / maxAmount).clamp(0.0, 1.0),
                minHeight: 9,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: scheme.outlineVariant.withValues(alpha: .3),
                color: flow.$1
                    ? (dark ? const Color(0xFF7DDCB6) : cashIncomeColor)
                    : (dark ? const Color(0xFFFFB4BC) : cashExpenseColor),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            income > 0
                ? '${(expense / income * 100).toStringAsFixed(1)}% of income spent'
                : 'No income recorded',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ReportTransaction extends StatelessWidget {
  const ReportTransaction({
    super.key,
    required this.entry,
    required this.symbol,
    required this.rate,
  });
  final Map<String, dynamic> entry;
  final String symbol;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final income = entry['is_income'] == true;
    final color = income
        ? (dark ? const Color(0xFF7DDCB6) : cashIncomeColor)
        : (dark ? const Color(0xFFFFB4BC) : cashExpenseColor);
    final date = reportDate(entry);
    final amount = Text(
      '${income ? '+' : '-'} $symbol ${formatCurrency((entry['amount'] as num).toDouble() / rate)}',
      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reportDescription(entry),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${income ? 'Income' : 'Expense'} - ${date == null ? 'Date unavailable' : getFormattedDate(date.toIso8601String())}',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ReportPanel(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(12) > 15;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        income
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      Flexible(child: amount),
                    ],
                  ],
                ),
                if (compact)
                  Padding(
                    padding: const EdgeInsets.only(left: 52, top: 12),
                    child: amount,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ReportExportCard extends StatelessWidget {
  const ReportExportCard({
    super.key,
    required this.exporting,
    required this.onShare,
    this.onSave,
  });
  final bool exporting;
  final VoidCallback onShare;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: scheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Take your report with you',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Export a PDF with your balance, totals, and full transaction history.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (exporting) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Preparing your PDF...',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final share = ElevatedButton.icon(
                onPressed: exporting ? null : onShare,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share PDF'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              );
              final save = OutlinedButton.icon(
                onPressed: exporting ? null : onSave,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Save PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              );
              if (onSave == null) {
                return SizedBox(width: double.infinity, child: share);
              }
              if (constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(12) > 15) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: share),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: save),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: share),
                  const SizedBox(width: 12),
                  Expanded(child: save),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
