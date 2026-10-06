import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/analytics_data.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/report_data.dart';
import 'cash_book_design.dart';
import 'dimensional_design.dart';
import 'home/home_motion.dart';

const _categoryColors = <String, Color>{
  'Food & dining': Color(0xFF2998C3),
  'Transport': Color(0xFF7766BC),
  'Shopping': Color(0xFFE2994F),
  'Utilities': Color(0xFF379F87),
  'Health': Color(0xFFD66D87),
  'Housing': Color(0xFF4E77BD),
  'Entertainment': Color(0xFF9F78AF),
  'Other': Color(0xFF6D879A),
};
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class AnalyticsDashboard extends StatelessWidget {
  const AnalyticsDashboard({
    super.key,
    required this.data,
    required this.symbol,
    required this.rate,
    required this.bookCount,
  });
  final AnalyticsSnapshot data;
  final String symbol;
  final double rate;
  final int bookCount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HomeReveal(
        child: AnalyticsSummary(
          data: data,
          symbol: symbol,
          rate: rate,
          bookCount: bookCount,
        ),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, constraints) {
          final totals = [
            _Metric(
              label: 'Income',
              value: data.income / rate,
              symbol: symbol,
              color: cashIncomeColor,
              icon: Icons.south_west_rounded,
            ),
            _Metric(
              label: 'Expenses',
              value: data.expense / rate,
              symbol: symbol,
              color: cashExpenseColor,
              icon: Icons.north_east_rounded,
            ),
          ];
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(12) > 17) {
            return Column(
              children: [totals[0], const SizedBox(height: 14), totals[1]],
            );
          }
          return Row(
            children: [
              Expanded(child: totals[0]),
              const SizedBox(width: 14),
              Expanded(child: totals[1]),
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      AnalyticsSavingsPanel(data: data),
      const SizedBox(height: 24),
      AnalyticsCategories(data: data, symbol: symbol, rate: rate),
      const SizedBox(height: 24),
      AnalyticsTrends(months: data.months, symbol: symbol, rate: rate),
      const SizedBox(height: 26),
      _Insights(data: data, symbol: symbol, rate: rate),
    ],
  );
}

class AnalyticsSummary extends StatelessWidget {
  const AnalyticsSummary({
    super.key,
    required this.data,
    required this.symbol,
    required this.rate,
    required this.bookCount,
  });
  final AnalyticsSnapshot data;
  final String symbol;
  final double rate;
  final int bookCount;
  @override
  Widget build(BuildContext context) => RaisedPanel(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [brandNavy, Color(0xFF195879), primaryBlue],
    ),
    padding: const EdgeInsets.all(24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NET SAVINGS',
              style: TextStyle(
                color: Color(0xFFC9E9F8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              label:
                  'Net savings $symbol ${formatCurrency(data.savings / rate)}',
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$symbol ${formatCurrency(data.savings / rate)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data.period.label,
              style: const TextStyle(color: Color(0xFFC9E9F8), fontSize: 12),
            ),
            const SizedBox(height: 18),
            Text(
              '$bookCount ${bookCount == 1 ? 'cash book' : 'cash books'} / ${data.filtered.length} ${data.filtered.length == 1 ? 'entry' : 'entries'}',
              style: const TextStyle(
                color: Color(0xFFC9E9F8),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(12) > 15) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: GrowthSculpture(size: 84),
              ),
              summary,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: summary),
            const SizedBox(width: 12),
            const GrowthSculpture(size: 112),
          ],
        );
      },
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.symbol,
    required this.color,
    required this.icon,
  });
  final String label;
  final double value;
  final String symbol;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RaisedPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DepthIcon(icon: icon, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol ${formatCurrency(value)}',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsSavingsPanel extends StatelessWidget {
  const AnalyticsSavingsPanel({super.key, required this.data});
  final AnalyticsSnapshot data;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = data.savingsRate;
    final color = percent != null && percent >= 0
        ? (scheme.brightness == Brightness.dark
              ? const Color(0xFF7DDCB6)
              : cashIncomeColor)
        : scheme.error;
    return RaisedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Savings rate',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  percent == null ? '--' : '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: color,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: percent == null ? 0 : (percent / 100).clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: scheme.outlineVariant.withValues(alpha: .35),
          ),
          const SizedBox(height: 12),
          Text(
            percent == null
                ? 'Add income to calculate your savings rate.'
                : data.savings < 0
                ? 'Expenses exceed income for this period.'
                : 'The share of your income left after expenses.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsCategories extends StatelessWidget {
  const AnalyticsCategories({
    super.key,
    required this.data,
    required this.symbol,
    required this.rate,
  });
  final AnalyticsSnapshot data;
  final String symbol;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = data.categories.entries.toList();
    final total = data.expense;
    final legend = Column(
      children: [
        for (final category in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: _categoryColors[category.key],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$symbol ${formatCurrency(category.value / rate)}',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(total <= 0 ? 0 : category.value / total * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final ring = Semantics(
      label: 'Total spending $symbol ${formatCurrency(total / rate)}',
      excludeSemantics: true,
      child: SizedBox(
        width: 174,
        height: 182,
        child: CustomPaint(
          painter: _CategoryRingPainter(
            values: categories.map((entry) => entry.value).toList(),
            colors: categories
                .map((entry) => _categoryColors[entry.key]!)
                .toList(),
          ),
          child: Center(
            child: SizedBox(
              width: 105,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SPENDING',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$symbol ${formatCurrencyCompact(total / rate)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return RaisedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Where your money goes',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grouped from transaction descriptions.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          if (categories.isEmpty)
            Row(
              children: [
                const DepthIcon(icon: Icons.donut_large_rounded),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No expenses in this period.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          if (categories.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 440 ||
                    MediaQuery.textScalerOf(context).scale(12) > 15) {
                  return Column(
                    children: [
                      Center(child: ring),
                      const SizedBox(height: 24),
                      legend,
                    ],
                  );
                }
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 30),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryRingPainter extends CustomPainter {
  const _CategoryRingPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2 - 4);
    final radius = size.width / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 13),
        width: size.width - 15,
        height: size.height - 20,
      ),
      Paint()
        ..color = const Color(0xFF102E45).withValues(alpha: .13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final gap = math.min(.035, sweep * .2);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect.shift(const Offset(0, 7)),
        start + gap / 2,
        sweep - gap,
        false,
        paint..color = Color.lerp(colors[i], Colors.black, .32)!,
      );
      canvas.drawArc(
        rect,
        start + gap / 2,
        sweep - gap,
        false,
        paint
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(colors[i], Colors.white, .32)!, colors[i]],
          ).createShader(rect),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryRingPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class AnalyticsTrends extends StatelessWidget {
  const AnalyticsTrends({
    super.key,
    required this.months,
    required this.symbol,
    required this.rate,
  });
  final List<AnalyticsMonth> months;
  final String symbol;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final incomeColor = dark ? const Color(0xFF7DDCB6) : cashIncomeColor;
    final expenseColor = dark ? const Color(0xFFFFB4BC) : cashExpenseColor;
    final maxValue = months.fold<double>(
      0,
      (value, month) =>
          math.max(value, math.max(month.income, month.expense) / rate),
    );
    final chartMax = math.max(1.0, maxValue * 1.2);
    return RaisedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The bigger picture',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Last 12 months / $symbol',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              for (final item in [
                ('Income', incomeColor),
                ('Expenses', expenseColor),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 4,
                      decoration: BoxDecoration(
                        color: item.$2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.$1,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 230,
            child: LineChart(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              LineChartData(
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: chartMax,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: chartMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: .4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: chartMax / 4,
                      getTitlesWidget: (value, meta) => Text(
                        formatCurrencyCompact(value),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 ||
                            i >= months.length ||
                            ![0, 5, 11].contains(i)) {
                          return const SizedBox.shrink();
                        }
                        final date = months[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            '${_months[date.month - 1]} ${date.year % 100}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: true),
                lineBarsData: [
                  for (final income in [true, false])
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < months.length; i++)
                          FlSpot(
                            i.toDouble(),
                            (income ? months[i].income : months[i].expense) /
                                rate,
                          ),
                      ],
                      color: income ? incomeColor : expenseColor,
                      barWidth: 3,
                      isCurved: false,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: income,
                        color: incomeColor.withValues(alpha: .07),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Monthly totals',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              children: [
                for (final month in months.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_months[month.date.month - 1]} ${month.date.year}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          children: [
                            Text(
                              'In: $symbol ${formatCurrency(month.income / rate)}',
                              style: TextStyle(
                                color: incomeColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Out: $symbol ${formatCurrency(month.expense / rate)}',
                              style: TextStyle(
                                color: expenseColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({
    required this.data,
    required this.symbol,
    required this.rate,
  });
  final AnalyticsSnapshot data;
  final String symbol;
  final double rate;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insights =
        <({String title, String text, IconData icon, Color color})>[];
    if (data.categories.isNotEmpty) {
      final top = data.categories.entries.first;
      insights.add((
        title: 'Your largest category',
        text:
            '${top.key} accounts for ${(top.value / data.expense * 100).toStringAsFixed(0)}% of spending this period.',
        icon: Icons.donut_large_rounded,
        color: primaryBlue,
      ));
    }
    if (data.previousExpense > 0) {
      final change =
          (data.expense - data.previousExpense) / data.previousExpense * 100;
      insights.add((
        title: 'Spending comparison',
        text:
            '${change.abs().toStringAsFixed(1)}% ${change >= 0 ? 'more' : 'less'} spent than in the previous full ${data.period.name}.',
        icon: Icons.compare_arrows_rounded,
        color: const Color(0xFF7664B8),
      ));
    }
    for (final expense in data.unusualExpenses.take(2)) {
      insights.add((
        title: 'An expense that stands out',
        text:
            '${reportDescription(expense)} / $symbol ${formatCurrency((expense['amount'] as num).toDouble() / rate)}',
        icon: Icons.search_rounded,
        color: const Color(0xFFB7802E),
      ));
    }
    if (data.projectedSavings != null) {
      insights.add((
        title: 'Savings trend estimate',
        text:
            '$symbol ${formatCurrency(data.projectedSavings! / rate)} over the next 12 months, estimated from your monthly history.',
        icon: Icons.timeline_rounded,
        color: cashIncomeColor,
      ));
    }
    if (insights.isEmpty) {
      insights.add((
        title: 'More entries, more insight',
        text:
            'Add transactions to your cash books to see spending patterns here.',
        icon: Icons.auto_awesome_rounded,
        color: primaryBlue,
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A closer look',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 14),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: RaisedPanel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DepthIcon(icon: insight.icon, color: insight.color, size: 34),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          insight.text,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
