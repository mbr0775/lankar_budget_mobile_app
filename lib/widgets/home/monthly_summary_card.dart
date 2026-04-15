// lib/widgets/home/monthly_summary_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

// ── View mode ────────────────────────────────────────────────────────────────
enum _ViewMode { day, week, month }

extension _ViewModeLabel on _ViewMode {
  String get label {
    switch (this) {
      case _ViewMode.day:   return 'Daily';
      case _ViewMode.week:  return 'Weekly';
      case _ViewMode.month: return 'Monthly';
    }
  }
  IconData get icon {
    switch (this) {
      case _ViewMode.day:   return Icons.calendar_today_rounded;
      case _ViewMode.week:  return Icons.view_week_rounded;
      case _ViewMode.month: return Icons.calendar_month_rounded;
    }
  }
}

class MonthlySummaryCard extends StatefulWidget {
  final List<Map<String, dynamic>> allEntries;
  final String currencySymbol;
  final double exchangeRate;

  const MonthlySummaryCard({
    super.key,
    required this.allEntries,
    required this.currencySymbol,
    required this.exchangeRate,
  });

  @override
  State<MonthlySummaryCard> createState() => _MonthlySummaryCardState();
}

class _MonthlySummaryCardState extends State<MonthlySummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  _ViewMode _viewMode    = _ViewMode.day;
  int       _monthOffset = 0;   // 0 = current, 1 = last, 2 = two months ago
  int?      _selectedBar;

  // ── Smooth pan/zoom via TransformationController ──────────────────────────
  // We track a logical offsetX (in bar units) and scaleX independently
  // so we can clamp properly.
  double _scaleX       = 1.0;
  double _offsetX      = 0.0;   // leftmost visible bar index
  double _baseScaleX   = 1.0;
  double _baseOffsetX  = 0.0;
  double _lastFocalDx  = 0.0;

  static const double _yAxisW   = 50.0;
  static const double _barSpace = 6.0;  // gap between bars
  static const double _maxScale = 8.0;

  static const _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── Time helpers ──────────────────────────────────────────────────────────

  DateTime get _targetMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month - _monthOffset, 1);
  }

  DateTime get _prevTargetMonth =>
      DateTime(_targetMonth.year, _targetMonth.month - 1, 1);

  int get _daysInMonth {
    final t = _targetMonth;
    return DateTime(t.year, t.month + 1, 0).day;
  }

  // ── Aggregate data into bars depending on view mode ───────────────────────

  /// Returns list of (label, income, expense) per bar.
  List<({String label, double income, double expense})> _buildBars() {
    final month = _targetMonth;
    final days  = _daysInMonth;

    // bucket raw entries
    final inc = List<double>.filled(days, 0);
    final exp = List<double>.filled(days, 0);

    for (final e in widget.allEntries) {
      final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
      if (ds.isEmpty) continue;
      final d = DateTime.tryParse(ds);
      if (d == null || d.year != month.year || d.month != month.month) continue;
      final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
      if (e['is_income'] == true) inc[d.day - 1] += amount;
      else                        exp[d.day - 1] += amount;
    }

    final mAbbr = _monthNames[month.month - 1]; // e.g. "Jan"

    switch (_viewMode) {
      // ── Daily: "Jan 1" … "Jan 31" ──────────────────────────────────────
      case _ViewMode.day:
        return List.generate(days, (i) => (
          label:   '$mAbbr\n${i + 1}',   // two-line: month on top, day below
          income:  inc[i],
          expense: exp[i],
        ));

      // ── Weekly: "W1\nJan 1-7", "W2\nJan 8-14" … ───────────────────────
      case _ViewMode.week:
        final weeks = <({String label, double income, double expense})>[];
        for (int w = 0; w < days; w += 7) {
          final end    = math.min(w + 7, days);
          final wNum   = weeks.length + 1;
          final startD = w + 1;
          final endD   = end;
          final wInc   = inc.sublist(w, end).fold(0.0, (a, b) => a + b);
          final wExp   = exp.sublist(w, end).fold(0.0, (a, b) => a + b);
          // Label: "W1\nJan 1-7"
          weeks.add((
            label:   'W$wNum\n$mAbbr $startD-$endD',
            income:  wInc,
            expense: wExp,
          ));
        }
        return weeks;

      // ── Monthly: "Jan\n2025", "Feb\n2025" … last 6 months ──────────────
      case _ViewMode.month:
        final result = <({String label, double income, double expense})>[];
        for (int m = 5; m >= 0; m--) {
          final mm   = DateTime(month.year, month.month - m, 1);
          double mInc = 0, mExp = 0;
          for (final e in widget.allEntries) {
            final ds = e['entry_date'] as String? ??
                e['created_at'] as String? ?? '';
            if (ds.isEmpty) continue;
            final d = DateTime.tryParse(ds);
            if (d == null || d.year != mm.year || d.month != mm.month) continue;
            final amount =
                (e['amount'] as num).toDouble() / widget.exchangeRate;
            if (e['is_income'] == true) mInc += amount;
            else                        mExp += amount;
          }
          // Label: "Jan\n2025"
          result.add((
            label:   '${_monthNames[mm.month - 1]}\n${mm.year}',
            income:  mInc,
            expense: mExp,
          ));
        }
        return result;
    }
  }

  // ── Smart insight ─────────────────────────────────────────────────────────
  String _buildInsight(
      double cI, double cE, double pI, double pE) {
    if (cI == 0 && cE == 0) return 'No transactions recorded yet.';
    final savings = cI > 0 ? ((cI - cE) / cI * 100) : 0.0;
    if (pE == 0 && pI == 0) {
      return savings >= 0
          ? 'Savings rate: ${savings.toStringAsFixed(0)}% this period 🎉'
          : 'Overspent by ${widget.currencySymbol} ${formatCurrency(cE - cI)} 📉';
    }
    final expDiff = pE > 0 ? ((cE - pE) / pE * 100) : 0.0;
    final incDiff = pI > 0 ? ((cI - pI) / pI * 100) : 0.0;
    if (expDiff >= 10) return 'Expenses up ${expDiff.toStringAsFixed(0)}% vs last period 📈';
    if (expDiff <= -10) return 'Expenses down ${expDiff.abs().toStringAsFixed(0)}% vs last period 💚';
    if (incDiff >= 10)  return 'Income up ${incDiff.toStringAsFixed(0)}% vs last period 🚀';
    if (savings >= 40)  return 'Outstanding! ${savings.toStringAsFixed(0)}% savings rate 🏆';
    if (savings >= 20)  return 'Good job! Saving ${savings.toStringAsFixed(0)}% of income ✅';
    if (savings > 0)    return 'Savings rate: ${savings.toStringAsFixed(0)}% — keep going!';
    if (cE > cI)        return 'Spent more than earned. Review your expenses ⚠️';
    return 'Income and expenses are balanced this period.';
  }

  // ── Previous-period totals for insight comparison ─────────────────────────
  ({double income, double expense}) _prevTotals() {
    if (_viewMode == _ViewMode.month) {
      // Compare last 6 months vs prior 6 months
      final now = _targetMonth;
      double pI = 0, pE = 0;
      for (final e in widget.allEntries) {
        final ds = e['entry_date'] as String? ??
            e['created_at'] as String? ?? '';
        if (ds.isEmpty) continue;
        final d = DateTime.tryParse(ds);
        if (d == null) continue;
        final monthsAgo = (now.year - d.year) * 12 + (now.month - d.month);
        if (monthsAgo >= 6 && monthsAgo < 12) {
          final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
          if (e['is_income'] == true) pI += amount;
          else pE += amount;
        }
      }
      return (income: pI, expense: pE);
    }
    // Otherwise compare to same period last month
    final prev = _prevTargetMonth;
    final pDays = DateTime(prev.year, prev.month + 1, 0).day;
    double pI = 0, pE = 0;
    for (final e in widget.allEntries) {
      final ds = e['entry_date'] as String? ??
          e['created_at'] as String? ?? '';
      if (ds.isEmpty) continue;
      final d = DateTime.tryParse(ds);
      if (d == null || d.year != prev.year || d.month != prev.month) continue;
      final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
      if (e['is_income'] == true) pI += amount;
      else pE += amount;
    }
    return (income: pI, expense: pE);
  }

  // ── View switching ─────────────────────────────────────────────────────────
  void _switchView(_ViewMode mode) {
    setState(() {
      _viewMode    = mode;
      _selectedBar = null;
      _scaleX      = 1.0;
      _offsetX     = 0.0;
    });
    _ctrl.forward(from: 0);
  }

  void _switchMonth(int offset) {
    setState(() {
      _monthOffset = offset;
      _selectedBar = null;
      _scaleX      = 1.0;
      _offsetX     = 0.0;
    });
    _ctrl.forward(from: 0);
  }

  // ── Clamp zoom/pan ────────────────────────────────────────────────────────
  void _clamp(int n) {
    _scaleX = _scaleX.clamp(1.0, _maxScale);
    final visible = n / _scaleX;
    _offsetX = _offsetX.clamp(
        0.0, (n - visible).clamp(0.0, double.infinity));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bars   = _buildBars();
    final n      = bars.length;
    final totInc = bars.fold(0.0, (s, b) => s + b.income);
    final totExp = bars.fold(0.0, (s, b) => s + b.expense);
    final prev   = _prevTotals();
    final insight = _buildInsight(totInc, totExp, prev.income, prev.expense);

    // peak bar index
    int peakBar = -1; double peakVal = 0;
    for (int i = 0; i < n; i++) {
      if (bars[i].expense > peakVal) { peakVal = bars[i].expense; peakBar = i; }
    }

    final monthLabel = _viewMode == _ViewMode.month
        ? 'Last 6 months'
        : '${_monthNames[_targetMonth.month - 1]} ${_targetMonth.year}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Row 1: title + view dropdown + month nav ─────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: primaryRed, size: 18),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text('Summary',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),

                // ── View mode dropdown ───────────────────────────────────
                _ViewDropdown(
                  current: _viewMode,
                  onChanged: _switchView,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Row 2: month navigator (hidden in monthly mode) ──────────
            if (_viewMode != _ViewMode.month)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(monthLabel,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _NavBtn(
                      icon: Icons.chevron_left,
                      enabled: _monthOffset < 2,
                      onTap: () => _switchMonth(_monthOffset + 1),
                    ),
                    const SizedBox(width: 4),
                    _NavBtn(
                      icon: Icons.chevron_right,
                      enabled: _monthOffset > 0,
                      onTap: () => _switchMonth(_monthOffset - 1),
                    ),
                  ]),
                ],
              )
            else
              Text(monthLabel,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),

            const SizedBox(height: 12),

            // ── Totals chips ─────────────────────────────────────────────
            Row(children: [
              _TotalChip(
                  label: 'Income',
                  amount: totInc,
                  symbol: widget.currencySymbol,
                  color: incomeGreen,
                  icon: Icons.arrow_downward_rounded),
              const SizedBox(width: 10),
              _TotalChip(
                  label: 'Expense',
                  amount: totExp,
                  symbol: widget.currencySymbol,
                  color: expenseRed,
                  icon: Icons.arrow_upward_rounded),
            ]),
            const SizedBox(height: 14),

            // ── Zoom hint + reset ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.pinch_rounded,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Pinch · drag to explore',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400)),
                if (_scaleX > 1.05) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _scaleX  = 1.0;
                      _offsetX = 0.0;
                      _selectedBar = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Reset',
                          style: TextStyle(
                              fontSize: 10,
                              color: primaryRed,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // ── Chart ────────────────────────────────────────────────────
            SizedBox(
              height: 196,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (ctx, __) => _BarChart(
                  bars:           bars,
                  progress:       _anim.value,
                  peakBar:        peakBar,
                  selectedBar:    _selectedBar,
                  currencySymbol: widget.currencySymbol,
                  scaleX:         _scaleX,
                  offsetX:        _offsetX,
                  yAxisWidth:     _yAxisW,
                  barSpace:       _barSpace,
                  onBarTap: (idx) => setState(() =>
                      _selectedBar = _selectedBar == idx ? null : idx),
                  onScaleStart: (focalDx) {
                    _baseScaleX  = _scaleX;
                    _baseOffsetX = _offsetX;
                    _lastFocalDx = focalDx;
                  },
                  onScaleUpdate: (scale, focalDx) {
                    final chartW =
                        (ctx.size?.width ?? 300) - _yAxisW;
                    final barW  = (chartW / (n / _baseScaleX))
                        .clamp(1.0, double.infinity);

                    setState(() {
                      // 1. Apply new scale centred on focal point
                      final prevScale  = _scaleX;
                      _scaleX = _baseScaleX * scale;
                      _clamp(n);

                      // 2. Pan by focal point delta (1 px = barW pixels)
                      final panDelta = (_lastFocalDx - focalDx) / barW;
                      _offsetX = _baseOffsetX + panDelta;
                      _clamp(n);
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Legend ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: incomeGreen, label: 'Income'),
                const SizedBox(width: 16),
                _LegendItem(color: expenseRed,  label: 'Expense'),
                if (peakBar >= 0) ...[
                  const SizedBox(width: 16),
                  _LegendItem(
                      color: Colors.orange,
                      label: 'Peak',
                      isDot: true),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── Smart insight ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                    color: primaryRed, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(insight,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bar chart widget (handles gestures) ──────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<({String label, double income, double expense})> bars;
  final double progress;
  final int peakBar;
  final int? selectedBar;
  final String currencySymbol;
  final double scaleX;
  final double offsetX;
  final double yAxisWidth;
  final double barSpace;
  final ValueChanged<int> onBarTap;
  final void Function(double focalDx) onScaleStart;
  final void Function(double scale, double focalDx) onScaleUpdate;

  const _BarChart({
    required this.bars,
    required this.progress,
    required this.peakBar,
    required this.selectedBar,
    required this.currencySymbol,
    required this.scaleX,
    required this.offsetX,
    required this.yAxisWidth,
    required this.barSpace,
    required this.onBarTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // ── Pinch-to-zoom + drag-to-pan via ScaleGesture ──────────────────
      onScaleStart: (d) => onScaleStart(d.localFocalPoint.dx),
      onScaleUpdate: (d) =>
          onScaleUpdate(d.scale, d.localFocalPoint.dx),
      // ── Tap to select bar ──────────────────────────────────────────────
      onTapDown: (d) {
        final box  = context.findRenderObject() as RenderBox;
        final loc  = box.globalToLocal(d.globalPosition);
        final cW   = box.size.width - yAxisWidth;
        final n    = bars.length;
        if (n == 0 || cW <= 0) return;
        final visible = n / scaleX;
        final slotW   = cW / visible;
        final dx      = loc.dx - yAxisWidth;
        if (dx < 0) return;
        final idx = (offsetX + dx / slotW).floor().clamp(0, n - 1);
        onBarTap(idx);
      },
      child: CustomPaint(
        painter: _BarChartPainter(
          bars:           bars,
          progress:       progress,
          peakBar:        peakBar,
          selectedBar:    selectedBar,
          currencySymbol: currencySymbol,
          scaleX:         scaleX,
          offsetX:        offsetX,
          yAxisWidth:     yAxisWidth,
          barSpace:       barSpace,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── Bar chart painter ─────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<({String label, double income, double expense})> bars;
  final double progress;
  final int    peakBar;
  final int?   selectedBar;
  final String currencySymbol;
  final double scaleX;
  final double offsetX;
  final double yAxisWidth;
  final double barSpace;

  static const double _padTop    = 20.0;
  static const double _padBottom = 34.0; // extra room for two-line labels

  const _BarChartPainter({
    required this.bars,
    required this.progress,
    required this.peakBar,
    required this.selectedBar,
    required this.currencySymbol,
    required this.scaleX,
    required this.offsetX,
    required this.yAxisWidth,
    required this.barSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0) return;

    final chartH = size.height - _padTop - _padBottom;
    final chartW = size.width - yAxisWidth;

    // ── Max value → nice round ceiling ────────────────────────────────────
    final rawMax = bars.fold(0.0, (m, b) => math.max(m, math.max(b.income, b.expense)));
    final maxVal = rawMax == 0 ? 1.0 : _niceMax(rawMax);

    // ── Visible range ────────────────────────────────────────────────────
    final visible  = n / scaleX;
    final startIdx = offsetX;
    final endIdx   = math.min(offsetX + visible, n.toDouble());

    // slot width (pixels per bar slot including gap)
    final slotW    = chartW / visible;
    final barW     = math.max(4.0, slotW - barSpace * 2);

    double barX(int i) =>
        yAxisWidth + (i - startIdx) * slotW + barSpace;

    double toY(double v) =>
        _padTop + chartH - (v / maxVal * chartH).clamp(0.0, chartH);

    // ── Y-axis white background ───────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, yAxisWidth - 2, size.height),
      Paint()..color = Colors.white,
    );

    // ── Grid + Y labels ───────────────────────────────────────────────────
    const gridN = 4;
    final gridP = Paint()
      ..color = Colors.grey.withOpacity(0.12)
      ..strokeWidth = 1;
    final yStyle = TextStyle(
        fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w500);

    for (int g = 0; g <= gridN; g++) {
      final frac = g / gridN;
      final y    = _padTop + chartH * (1 - frac);
      final val  = maxVal * frac;
      canvas.drawLine(Offset(yAxisWidth, y), Offset(size.width, y), gridP);
      final tp = TextPainter(
        text: TextSpan(text: _compact(val), style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(yAxisWidth - tp.width - 5, y - tp.height / 2));
    }

    // ── Axis lines ────────────────────────────────────────────────────────
    final axisP = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(yAxisWidth, _padTop),
        Offset(yAxisWidth, size.height - _padBottom), axisP);
    canvas.drawLine(Offset(yAxisWidth, size.height - _padBottom),
        Offset(size.width, size.height - _padBottom), axisP);

    // ── Clip chart body ────────────────────────────────────────────────────
    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(yAxisWidth, 0, chartW, size.height));

    final baseY = size.height - _padBottom;

    for (int i = startIdx.floor(); i < n && i < endIdx.ceil(); i++) {
      final x    = barX(i);
      final bar  = bars[i];
      final isPeak     = i == peakBar;
      final isSelected = i == selectedBar;

      // Animated bar height
      final incH = (bar.income  / maxVal * chartH * progress).clamp(0.0, chartH);
      final expH = (bar.expense / maxVal * chartH * progress).clamp(0.0, chartH);

      final halfBar = barW / 2;
      final incX   = x;
      final expX   = x + halfBar + 1;
      final pairW  = halfBar - 1;

      // ── Income bar ──────────────────────────────────────────────────
      if (incH > 0) {
        final rr = RRect.fromRectAndCorners(
          Rect.fromLTWH(incX, baseY - incH, pairW, incH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = isSelected
                ? incomeGreen
                : incomeGreen.withOpacity(0.75),
        );
      }

      // ── Expense bar ─────────────────────────────────────────────────
      if (expH > 0) {
        final rr = RRect.fromRectAndCorners(
          Rect.fromLTWH(expX, baseY - expH, pairW, expH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(
          rr,
          Paint()
            ..color = isPeak
                ? Colors.orange
                : isSelected
                    ? expenseRed
                    : expenseRed.withOpacity(0.75),
        );
        // Peak diamond marker above bar
        if (isPeak && expH > 0) {
          final dX = expX + pairW / 2;
          final dY = baseY - expH - 8;
          final path = Path()
            ..moveTo(dX, dY - 5)
            ..lineTo(dX + 4, dY)
            ..lineTo(dX, dY + 5)
            ..lineTo(dX - 4, dY)
            ..close();
          canvas.drawPath(path, Paint()..color = Colors.orange);
        }
      }

      // ── Selected bar: highlight + tooltip ──────────────────────────
      if (isSelected) {
        // Highlight column background
        canvas.drawRect(
          Rect.fromLTWH(x - 2, _padTop, barW + 4, chartH),
          Paint()..color = Colors.blueGrey.withOpacity(0.06),
        );

        // Tooltip — replace newline with space for single-line display
        final label =
            '${bar.label.replaceAll('\n', ' ')}  In:${currencySymbol}${_compact(bar.income)}  Out:${currencySymbol}${_compact(bar.expense)}';
        final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: const TextStyle(
                  fontSize: 9.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: chartW);
        final bW = tp.width + 18;
        final bH = tp.height + 10;
        final cx = x + barW / 2;
        double bx = cx - bW / 2;
        bx = bx.clamp(yAxisWidth, size.width - bW);
        const by = _padTop + 2.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bx, by, bW, bH), const Radius.circular(8)),
          Paint()..color = const Color(0xFF1E293B),
        );
        tp.paint(canvas, Offset(bx + 9, by + 5));
      }

      // ── X label: two lines split on '\n' (skip if too crowded) ────────
      if (slotW >= 14) {
        final parts    = bar.label.split('\n'); // e.g. ['Jan', '1'] or ['W1', 'Jan 1-7']
        final fontSize = slotW > 36 ? 9.5 : slotW > 22 ? 8.5 : 7.5;
        final topStyle = TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: isSelected ? primaryRed : Colors.black87);
        final botStyle = TextStyle(
            fontSize: fontSize - 0.5,
            color: isSelected ? primaryRed : Colors.grey.shade500);

        final topTp = TextPainter(
          text: TextSpan(text: parts[0], style: topStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        final cx = x + barW / 2;
        final topY = size.height - _padBottom + 4;
        topTp.paint(canvas, Offset(cx - topTp.width / 2, topY));

        if (parts.length > 1) {
          final botTp = TextPainter(
            text: TextSpan(text: parts[1], style: botStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          botTp.paint(canvas,
              Offset(cx - botTp.width / 2, topY + topTp.height + 1));
        }
      }
    }

    canvas.restore();
  }

  double _niceMax(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final r   = v / mag;
    final nf  = r <= 1 ? 1.0 : r <= 2 ? 2.0 : r <= 5 ? 5.0 : 10.0;
    return nf * mag * 1.15;
  }

  String _compact(double v) {
    if (v == 0) return '0';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.progress    != progress    ||
      old.selectedBar != selectedBar ||
      old.scaleX      != scaleX      ||
      old.offsetX     != offsetX     ||
      old.bars        != bars;
}

// ── View-mode dropdown ────────────────────────────────────────────────────────

class _ViewDropdown extends StatelessWidget {
  final _ViewMode current;
  final ValueChanged<_ViewMode> onChanged;
  const _ViewDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primaryRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryRed.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(current.icon, size: 13, color: primaryRed),
            const SizedBox(width: 5),
            Text(current.label,
                style: const TextStyle(
                    fontSize: 12,
                    color: primaryRed,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: primaryRed),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            const Text('View Mode',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._ViewMode.values.map((mode) {
              final selected = mode == current;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onChanged(mode);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? primaryRed.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? primaryRed
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryRed.withOpacity(0.12)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(mode.icon,
                            size: 18,
                            color: selected
                                ? primaryRed
                                : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mode.label,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? primaryRed
                                        : Colors.black87)),
                            Text(
                              _modeSubtitle(mode),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: primaryRed, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _modeSubtitle(_ViewMode m) {
    switch (m) {
      case _ViewMode.day:   return 'Income & expense per day';
      case _ViewMode.week:  return 'Grouped by week';
      case _ViewMode.month: return 'Last 6 months overview';
    }
  }
}

// ── Small reusable widgets ─────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color color;
  final IconData icon;
  const _TotalChip({required this.label, required this.amount,
      required this.symbol, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 1),
            Text('$symbol ${formatCurrency(amount)}',
                style: TextStyle(fontSize: 13, color: color,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    ),
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _NavBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: enabled ? primaryRed.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 18,
          color: enabled ? primaryRed : Colors.grey.shade300),
    ),
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;
  const _LegendItem(
      {required this.color, required this.label, this.isDot = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      isDot
          ? Container(width: 8, height: 8,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle))
          : Container(width: 16, height: 10,
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500)),
    ],
  );
}