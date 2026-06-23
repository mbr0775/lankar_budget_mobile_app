import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import '../../providers/books_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/hive_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ── Period filter ─────────────────────────────────────────────────────────────
enum _Period { week, month, quarter, year }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.week:    return 'This Week';
      case _Period.month:   return 'This Month';
      case _Period.quarter: return 'This Quarter';
      case _Period.year:    return 'This Year';
    }
  }
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  _Period _period = _Period.month;
  List<Map<String, dynamic>> _allEntries = [];
  bool _loading = true;
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  StreamSubscription? _entriesSub;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _loadAll();
    _entriesSub = HiveService().entriesBox.watch().listen((_) => _loadAll());
  }

  @override
  void dispose() {
    _entriesSub?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final books = ref.read(booksProvider).asData?.value ?? [];
    final hive  = HiveService();
    final all   = <Map<String, dynamic>>[];
    for (final b in books) {
      all.addAll(await hive.getEntries(b['id'] as String));
    }
    if (mounted) {
      setState(() { _allEntries = all; _loading = false; });
      _animCtrl.forward(from: 0);
    }
  }

  // ── Filter entries by selected period ────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    final now  = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime cutoff;
    switch (_period) {
      case _Period.week:    cutoff = today.subtract(const Duration(days: 7));  break;
      case _Period.month:   cutoff = DateTime(now.year, now.month, 1);         break;
      case _Period.quarter: cutoff = DateTime(now.year, now.month - 2, 1);     break;
      case _Period.year:    cutoff = DateTime(now.year, 1, 1);                 break;
    }
    return _allEntries.where((e) {
      final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
      final d  = DateTime.tryParse(ds);
      return d != null && !d.isBefore(cutoff);
    }).toList();
  }

  double get _income  => _filtered
      .where((e) => e['is_income'] == true)
      .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

  double get _expense => _filtered
      .where((e) => e['is_income'] == false)
      .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());

  double get _savings => _income - _expense;
  double get _savingsRate => _income > 0 ? (_savings / _income * 100) : 0;

  // ── Category breakdown (keyword matching) ────────────────────────────────
  Map<String, double> get _categories {
    final map = <String, double>{};
    for (final e in _filtered.where((e) => e['is_income'] == false)) {
      final cat = _categorise(e['description'] as String? ?? '');
      final amt = (e['amount'] as num).toDouble();
      map[cat] = (map[cat] ?? 0) + amt;
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    return sorted;
  }

  // ── Monthly trends for the last 12 months ────────────────────────────────
  List<Map<String, double>> get _monthlyTrends {
    final now = DateTime.now();
    final trends = <Map<String, double>>[];
    for (int i = 11; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 1).subtract(const Duration(days: 1));
      final monthEntries = _allEntries.where((e) {
        final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
        final d = DateTime.tryParse(ds);
        return d != null && !d.isBefore(monthStart) && !d.isAfter(monthEnd);
      }).toList();
      final income = monthEntries.where((e) => e['is_income'] == true).fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
      final expense = monthEntries.where((e) => e['is_income'] == false).fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
      trends.add({'income': income, 'expense': expense, 'month': monthStart.month.toDouble(), 'year': monthStart.year.toDouble()});
    }
    return trends;
  }

  // ── Anomaly detection: expenses significantly above average ──────────────
  List<Map<String, dynamic>> get _anomalies {
    if (_filtered.isEmpty) return [];
    final expenses = _filtered.where((e) => e['is_income'] == false).map((e) => (e['amount'] as num).toDouble()).toList();
    if (expenses.length < 3) return [];
    final mean = expenses.reduce((a, b) => a + b) / expenses.length;
    final variance = expenses.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) / expenses.length;
    final stdDev = math.sqrt(variance);
    final threshold = mean + 2 * stdDev;
    return _filtered.where((e) => e['is_income'] == false && (e['amount'] as num).toDouble() > threshold).toList();
  }

  // ── Predictive savings for the year ───────────────────────────────────────
  double get _predictedYearlySavings {
    final trends = _monthlyTrends;
    if (trends.length < 3) return _savings * 12;
    // Simple linear regression on savings
    final savingsData = trends.map((t) => t['income']! - t['expense']!).toList();
    final n = savingsData.length;
    final x = List.generate(n, (i) => i.toDouble());
    final y = savingsData;
    final sumX = x.reduce((a, b) => a + b);
    final sumY = y.reduce((a, b) => a + b);
    final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
    final sumXX = x.map((xi) => xi * xi).reduce((a, b) => a + b);
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    // Predict for the next 12 months from now
    final futureSavings = List.generate(12, (i) => intercept + slope * (n + i));
    return futureSavings.reduce((a, b) => a + b);
  }

  String _categorise(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('food') || d.contains('meal') || d.contains('restaurant') ||
        d.contains('lunch') || d.contains('dinner') || d.contains('breakfast') ||
        d.contains('coffee') || d.contains('cafe'))   return 'Food & Dining';
    if (d.contains('fuel') || d.contains('petrol') || d.contains('gas') ||
        d.contains('transport') || d.contains('taxi') || d.contains('uber') ||
        d.contains('bus') || d.contains('metro'))      return 'Transport';
    if (d.contains('shop') || d.contains('cloth') || d.contains('purchase') ||
        d.contains('buy') || d.contains('amazon'))     return 'Shopping';
    if (d.contains('bill') || d.contains('electric') || d.contains('water') ||
        d.contains('utility') || d.contains('internet')) return 'Utilities';
    if (d.contains('health') || d.contains('doctor') || d.contains('medicine') ||
        d.contains('pharmacy') || d.contains('hospital')) return 'Health';
    if (d.contains('rent') || d.contains('house') || d.contains('mortgage'))
      return 'Housing';
    if (d.contains('entertain') || d.contains('movie') || d.contains('game') ||
        d.contains('netflix') || d.contains('cinema')) return 'Entertainment';
    return 'Other';
  }

  static const _catColors = [
    Color(0xFF9E090F), Color(0xFF185FA5), Color(0xFF0F6E56),
    Color(0xFFBA7517), Color(0xFF7B3F9E), Color(0xFFDC3545),
    Color(0xFF28A745), Color(0xFF6C757D),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(booksProvider);
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      booksProvider,
      (previous, next) {
        if (next is AsyncData && previous != next) {
          _loadAll();
        }
      },
    );
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final settings   = ref.watch(settingsProvider);
    final symbol     = settings.currencySymbol;
    final rate       = settings.exchangeRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            floating: false,
            backgroundColor: primaryRed,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryRed, secondaryRed],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.donut_large_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Analytics',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  Text('Spending insights',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12)),
                                ],
                              ),
                            ]),
                            // Refresh
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white, size: 20),
                              onPressed: _loadAll,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (!isLoggedIn)
            SliverFillRemaining(child: _buildSignInPrompt(context))
          else if (_loading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: primaryRed)),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Period filter chips ──────────────────────────────
                    _buildPeriodFilter(),
                    const SizedBox(height: 20),

                    // ── KPI cards ────────────────────────────────────────
                    _buildKpiCards(symbol, rate),
                    const SizedBox(height: 20),

                    // ── Savings rate bar ─────────────────────────────────
                    _buildSavingsBar(symbol, rate),
                    const SizedBox(height: 20),

                    // ── Category donut + legend ──────────────────────────
                    _buildCategorySection(symbol, rate),
                    const SizedBox(height: 20),

                    // ── Trends chart ──────────────────────────────────────
                    _buildTrendsChart(symbol, rate),
                    const SizedBox(height: 20),

                    // ── Smart insights ───────────────────────────────────
                    _buildInsights(symbol, rate),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Period filter ─────────────────────────────────────────────────────────
  Widget _buildPeriodFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _Period.values.map((p) {
          final sel = p == _period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _period = p);
                _animCtrl.forward(from: 0);
                _loadAll();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? primaryRed : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? primaryRed : Colors.grey.shade300),
                  boxShadow: sel
                      ? [BoxShadow(
                          color: primaryRed.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3))]
                      : [],
                ),
                child: Text(p.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : Colors.black87)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── KPI cards ─────────────────────────────────────────────────────────────
  Widget _buildKpiCards(String symbol, double rate) {
    final items = [
      (label: 'Income',  value: _income / rate,  color: incomeGreen,
       icon: Icons.arrow_downward_rounded),
      (label: 'Expense', value: _expense / rate, color: expenseRed,
       icon: Icons.arrow_upward_rounded),
      (label: 'Savings', value: _savings / rate,
       color: _savings >= 0 ? incomeGreen : expenseRed,
       icon: Icons.savings_rounded),
    ];

    return Row(
      children: items.map((item) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(
              right: item.label == 'Savings' ? 0 : 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.color, size: 16),
                ),
                const SizedBox(height: 8),
                Text(item.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '$symbol ${formatCurrencyCompact(item.value)}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: item.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  // ── Savings rate bar ──────────────────────────────────────────────────────
  Widget _buildSavingsBar(String symbol, double rate) {
    final rate_  = _savingsRate.clamp(0.0, 100.0);
    final color  = rate_ >= 30 ? incomeGreen : rate_ >= 10 ? Colors.orange : expenseRed;
    final label  = rate_ >= 30 ? 'Excellent savings!' : rate_ >= 10 ? 'Good progress' : 'Low savings';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Savings Rate',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Row(children: [
                Text(
                  '${_savingsRate.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => LinearProgressIndicator(
                value:           (rate_ / 100) * _anim.value,
                minHeight:       10,
                backgroundColor: Colors.grey.shade100,
                valueColor:      AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Target: save 30%+ of income each month',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ── Category donut chart ──────────────────────────────────────────────────
  Widget _buildCategorySection(String symbol, double rate) {
    final cats   = _categories;
    final total  = cats.values.fold(0.0, (a, b) => a + b);

    if (cats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Icon(Icons.donut_large_outlined,
              size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('No expense data for this period',
              style: TextStyle(color: Colors.grey[500])),
        ]),
      );
    }

    final entries   = cats.entries.toList();
    final colors    = List.generate(
        entries.length, (i) => _catColors[i % _catColors.length]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Spending by Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Donut chart
              AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      values:   entries.map((e) => e.value).toList(),
                      colors:   colors,
                      progress: _anim.value,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$symbol${formatCurrencyCompact(total / rate)}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          Text('total',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  children: entries.asMap().entries.map((e) {
                    final pct = total > 0
                        ? (e.value.value / total * 100)
                        : 0.0;
                    final amt = e.value.value / rate;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: colors[e.key],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.value.key,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors[e.key]),
                            ),
                            Text(
                              '$symbol${formatCurrencyCompact(amt)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[400]),
                            ),
                          ],
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Trends chart ──────────────────────────────────────────────────────────
  Widget _buildTrendsChart(String symbol, double rate) {
    final trends = _monthlyTrends;
    if (trends.isEmpty) return const SizedBox.shrink();

    final incomeSpots = trends.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['income']! / rate))
        .toList();
    final expenseSpots = trends.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value['expense']! / rate))
        .toList();

    final maxY = [
      incomeSpots.map((s) => s.y).fold(0.0, math.max),
      expenseSpots.map((s) => s.y).fold(0.0, math.max),
    ].reduce(math.max);
    final chartMax = math.max(maxY * 1.15, 1.0);
    final interval = chartMax / 4;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Income vs Expense Trends (Last 12 Months)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: interval,
                      getTitlesWidget: (value, meta) {
                        final text = value == 0
                            ? '0'
                            : '$symbol${formatCurrencyCompact(value)}';
                        return Text(text,
                            style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= trends.length) {
                          return const SizedBox.shrink();
                        }
                        if (index % 3 != 0 && index != trends.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final month = trends[index]['month']!.toInt();
                        final year = trends[index]['year']!.toInt();
                        return Text('${_monthAbbrev(month)} ${year % 100}',
                            style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: incomeSpots,
                    isCurved: true,
                    color: incomeGreen,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: expenseSpots,
                    isCurved: true,
                    color: expenseRed,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [
                Container(width: 12, height: 3, color: incomeGreen),
                const SizedBox(width: 4),
                const Text('Income', style: TextStyle(fontSize: 12)),
              ]),
              const SizedBox(width: 20),
              Row(children: [
                Container(width: 12, height: 3, color: expenseRed),
                const SizedBox(width: 4),
                const Text('Expense', style: TextStyle(fontSize: 12)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  String _monthAbbrev(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  // ── Smart insights ────────────────────────────────────────────────────────
  Widget _buildInsights(String symbol, double rate) {
    final insights = <({String text, IconData icon, Color color})>[];
    final cats     = _categories;
    final entries  = cats.entries.toList();

    if (entries.isNotEmpty) {
      final top = entries.first;
      final pct = _expense > 0 ? (top.value / _expense * 100) : 0.0;
      insights.add((
        text:  '${top.key} is your biggest expense (${pct.toStringAsFixed(0)}% of total)',
        icon:  Icons.flag_rounded,
        color: expenseRed,
      ));
    }

    // Compare with previous period
    final prevPeriod = _getPreviousPeriodData();
    if (prevPeriod['expense']! > 0) {
      final change = ((_expense - prevPeriod['expense']!) / prevPeriod['expense']! * 100);
      if (change.abs() > 5) {
        insights.add((
          text:  'Expenses ${change > 0 ? 'increased' : 'decreased'} by ${change.abs().toStringAsFixed(1)}% compared to last ${_period.label.toLowerCase()}',
          icon:  change > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          color: change > 0 ? expenseRed : incomeGreen,
        ));
      }
    }

    // Anomalies
    final anomalies = _anomalies;
    if (anomalies.isNotEmpty) {
      for (final anomaly in anomalies.take(2)) { // Show up to 2
        final amount = (anomaly['amount'] as num?)?.toDouble() ?? 0.0;
        insights.add((
          text:  'Unusual expense: ${anomaly['description'] ?? 'Unknown'} - $symbol${formatCurrency(amount / rate)}',
          icon:  Icons.warning_rounded,
          color: Colors.orange,
        ));
      }
    }

    // Predictive savings
    final predicted = _predictedYearlySavings / rate;
    if (predicted != 0) {
      insights.add((
        text:  'Projected yearly savings: $symbol${formatCurrency(predicted)} based on current trends',
        icon:  Icons.timeline_rounded,
        color: predicted > 0 ? incomeGreen : expenseRed,
      ));
    }

    if (_savingsRate >= 30) {
      insights.add((
        text:  'Outstanding! You\'re saving ${_savingsRate.toStringAsFixed(0)}% of your income 🏆',
        icon:  Icons.emoji_events_rounded,
        color: incomeGreen,
      ));
    } else if (_savingsRate > 0) {
      insights.add((
        text:  'You\'re saving ${_savingsRate.toStringAsFixed(0)}%. Try to reach 30% for financial health.',
        icon:  Icons.trending_up_rounded,
        color: Colors.orange,
      ));
    } else if (_expense > _income && _income > 0) {
      insights.add((
        text:  'Expenses exceed income by $symbol ${formatCurrency((_expense - _income) / rate)}. Review spending.',
        icon:  Icons.warning_amber_rounded,
        color: expenseRed,
      ));
    }

    if (_filtered.isEmpty) {
      insights.add((
        text:  'No transactions found for this period. Add entries to see insights.',
        icon:  Icons.info_outline_rounded,
        color: Colors.blueGrey,
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Smart Insights',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6C757D),
                letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ...insights.map((ins) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: ins.color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: ins.color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(ins.icon, color: ins.color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(ins.text,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                      height: 1.4)),
            ),
          ]),
        )),
      ],
    );
  }

  Map<String, double> _getPreviousPeriodData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime prevCutoff;
    switch (_period) {
      case _Period.week:    prevCutoff = today.subtract(const Duration(days: 14)); break;
      case _Period.month:   prevCutoff = DateTime(now.year, now.month - 1, 1);    break;
      case _Period.quarter: prevCutoff = DateTime(now.year, now.month - 3, 1);    break;
      case _Period.year:    prevCutoff = DateTime(now.year - 1, 1, 1);            break;
    }
    DateTime prevEnd;
    switch (_period) {
      case _Period.week:    prevEnd = today.subtract(const Duration(days: 7));     break;
      case _Period.month:   prevEnd = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)); break;
      case _Period.quarter: prevEnd = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1)); break;
      case _Period.year:    prevEnd = DateTime(now.year, 1, 1).subtract(const Duration(days: 1)); break;
    }
    final prevEntries = _allEntries.where((e) {
      final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
      final d = DateTime.tryParse(ds);
      return d != null && !d.isBefore(prevCutoff) && !d.isAfter(prevEnd);
    }).toList();
    final income = prevEntries.where((e) => e['is_income'] == true)
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    final expense = prevEntries.where((e) => e['is_income'] == false)
        .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
    return {'income': income, 'expense': expense};
  }

  Widget _buildSignInPrompt(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.donut_large_rounded,
                    size: 40, color: primaryRed),
              ),
              const SizedBox(height: 20),
              const Text('Sign in for Analytics',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('View spending breakdowns and financial insights.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 14, height: 1.5)),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.login),
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

// ── Donut chart painter ───────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color>  colors;
  final double       progress;

  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 4;
    const sw = 18.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    double startAngle = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi * progress;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color       = colors[i % colors.length]
          ..strokeWidth = sw
          ..style       = PaintingStyle.stroke
          ..strokeCap   = StrokeCap.butt,
      );
      startAngle += sweep;
      // Small gap between segments
      startAngle += 0.02;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.progress != progress || old.values != values;
}