// lib/widgets/home/monthly_summary_card.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

enum _ViewMode { day, week, month }

extension _ViewModeLabel on _ViewMode {
  String get label {
    switch (this) {
      case _ViewMode.day:
        return 'Daily';
      case _ViewMode.week:
        return 'Weekly';
      case _ViewMode.month:
        return 'Monthly';
    }
  }

  IconData get icon {
    switch (this) {
      case _ViewMode.day:
        return Icons.calendar_today_rounded;
      case _ViewMode.week:
        return Icons.view_week_rounded;
      case _ViewMode.month:
        return Icons.calendar_month_rounded;
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
  late Animation<double> _anim;

  _ViewMode _viewMode = _ViewMode.week;
  int _monthOffset = 0; // 0 = current, 1 = last, 2 = two months ago
  int? _selectedBar;

  // We track a logical offsetX (in bar units) and scaleX independently
  // so we can clamp properly.
  double _scaleX = 1.0;
  double _offsetX = 0.0; // leftmost visible bar index
  double _baseScaleX = 1.0;
  double _baseOffsetX = 0.0;
  double _lastFocalDx = 0.0;

  static const double _yAxisW = 50.0;
  static const double _barSpace = 6.0; // gap between bars
  static const double _maxScale = 8.0;

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  /// Returns list of (label, income, expense) per bar.
  List<({String label, double income, double expense})> _buildBars() {
    final month = _targetMonth;
    final days = _daysInMonth;

    // bucket raw entries
    final inc = List<double>.filled(days, 0);
    final exp = List<double>.filled(days, 0);

    for (final e in widget.allEntries) {
      final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
      if (ds.isEmpty) continue;
      final d = DateTime.tryParse(ds);
      if (d == null || d.year != month.year || d.month != month.month) continue;
      final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
      if (e['is_income'] == true) {
        inc[d.day - 1] += amount;
      } else {
        exp[d.day - 1] += amount;
      }
    }

    final mAbbr = _monthNames[month.month - 1]; // e.g. "Jan"

    switch (_viewMode) {
      case _ViewMode.day:
        return List.generate(
          days,
          (i) => (
            label: '$mAbbr\n${i + 1}', // two-line: month on top, day below
            income: inc[i],
            expense: exp[i],
          ),
        );

      case _ViewMode.week:
        final weeks = <({String label, double income, double expense})>[];
        for (int w = 0; w < days; w += 7) {
          final end = math.min(w + 7, days);
          final wNum = weeks.length + 1;
          final startD = w + 1;
          final endD = end;
          final wInc = inc.sublist(w, end).fold(0.0, (a, b) => a + b);
          final wExp = exp.sublist(w, end).fold(0.0, (a, b) => a + b);
          // Label: "W1\nJan 1-7"
          weeks.add((
            label: 'W$wNum\n$mAbbr $startD-$endD',
            income: wInc,
            expense: wExp,
          ));
        }
        return weeks;

      case _ViewMode.month:
        final result = <({String label, double income, double expense})>[];
        for (int m = 5; m >= 0; m--) {
          final mm = DateTime(month.year, month.month - m, 1);
          double mInc = 0, mExp = 0;
          for (final e in widget.allEntries) {
            final ds =
                e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
            if (ds.isEmpty) continue;
            final d = DateTime.tryParse(ds);
            if (d == null || d.year != mm.year || d.month != mm.month) continue;
            final amount =
                (e['amount'] as num).toDouble() / widget.exchangeRate;
            if (e['is_income'] == true) {
              mInc += amount;
            } else {
              mExp += amount;
            }
          }
          // Label: "Jan\n2025"
          result.add((
            label: '${_monthNames[mm.month - 1]}\n${mm.year}',
            income: mInc,
            expense: mExp,
          ));
        }
        return result;
    }
  }

  String _buildInsight(
    double income,
    double expense,
    double previousIncome,
    double previousExpense,
  ) {
    if (income == 0 && expense == 0) {
      return 'Your next entry will bring this chart to life.';
    }
    if (expense > income) {
      return 'Expenses are above income. Take a closer look at your spending.';
    }
    if (previousExpense > 0) {
      final decrease = (previousExpense - expense) / previousExpense * 100;
      if (decrease >= 10) {
        return 'Expenses are down ${decrease.toStringAsFixed(0)}% compared with last period.';
      }
    }
    if (previousIncome > 0) {
      final increase = (income - previousIncome) / previousIncome * 100;
      if (increase >= 10) {
        return 'Income is up ${increase.toStringAsFixed(0)}% compared with last period.';
      }
    }
    final saved = income > 0 ? (income - expense) / income * 100 : 0.0;
    return 'You kept ${saved.toStringAsFixed(0)}% of your income this period.';
  }

  ({double income, double expense}) _prevTotals() {
    if (_viewMode == _ViewMode.month) {
      // Compare last 6 months vs prior 6 months
      final now = _targetMonth;
      double pI = 0, pE = 0;
      for (final e in widget.allEntries) {
        final ds =
            e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
        if (ds.isEmpty) continue;
        final d = DateTime.tryParse(ds);
        if (d == null) continue;
        final monthsAgo = (now.year - d.year) * 12 + (now.month - d.month);
        if (monthsAgo >= 6 && monthsAgo < 12) {
          final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
          if (e['is_income'] == true) {
            pI += amount;
          } else {
            pE += amount;
          }
        }
      }
      return (income: pI, expense: pE);
    }
    // Otherwise compare to same period last month
    final prev = _prevTargetMonth;
    double pI = 0, pE = 0;
    for (final e in widget.allEntries) {
      final ds = e['entry_date'] as String? ?? e['created_at'] as String? ?? '';
      if (ds.isEmpty) continue;
      final d = DateTime.tryParse(ds);
      if (d == null || d.year != prev.year || d.month != prev.month) continue;
      final amount = (e['amount'] as num).toDouble() / widget.exchangeRate;
      if (e['is_income'] == true) {
        pI += amount;
      } else {
        pE += amount;
      }
    }
    return (income: pI, expense: pE);
  }

  void _switchView(_ViewMode mode) {
    setState(() {
      _viewMode = mode;
      _selectedBar = null;
      _scaleX = 1.0;
      _offsetX = 0.0;
    });
    _ctrl.forward(from: 0);
  }

  void _switchMonth(int offset) {
    setState(() {
      _monthOffset = offset;
      _selectedBar = null;
      _scaleX = 1.0;
      _offsetX = 0.0;
    });
    _ctrl.forward(from: 0);
  }

  void _clamp(int n) {
    _scaleX = _scaleX.clamp(1.0, _maxScale);
    final visible = n / _scaleX;
    _offsetX = _offsetX.clamp(0.0, (n - visible).clamp(0.0, double.infinity));
  }

  @override
  Widget build(BuildContext context) {
    final bars = _buildBars();
    final n = bars.length;
    final income = bars.fold(0.0, (sum, bar) => sum + bar.income);
    final expense = bars.fold(0.0, (sum, bar) => sum + bar.expense);
    final previous = _prevTotals();
    final insight = _buildInsight(
      income,
      expense,
      previous.income,
      previous.expense,
    );
    final scheme = Theme.of(context).colorScheme;
    int peakBar = -1;
    double peak = 0;
    for (int i = 0; i < n; i++) {
      if (bars[i].expense > peak) {
        peak = bars[i].expense;
        peakBar = i;
      }
    }
    final monthLabel = _viewMode == _ViewMode.month
        ? 'Last 6 months'
        : '${_monthNames[_targetMonth.month - 1]} ${_targetMonth.year}';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                'Cash flow',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 21,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _ViewDropdown(current: _viewMode, onChanged: _switchView),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_viewMode != _ViewMode.month) ...[
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  enabled: _monthOffset < 2,
                  onTap: () => _switchMonth(_monthOffset + 1),
                ),
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  enabled: _monthOffset > 0,
                  onTap: () => _switchMonth(_monthOffset - 1),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TotalChip(
                label: 'Income',
                amount: income,
                symbol: widget.currencySymbol,
                color: incomeGreen,
                icon: Icons.south_west_rounded,
              ),
              const SizedBox(width: 10),
              _TotalChip(
                label: 'Expense',
                amount: expense,
                symbol: widget.currencySymbol,
                color: expenseRed,
                icon: Icons.north_east_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 185,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (ctx, _) => _BarChart(
                  bars: bars,
                  progress: MediaQuery.disableAnimationsOf(context)
                      ? 1
                      : _anim.value,
                  peakBar: peakBar,
                  selectedBar: _selectedBar,
                  currencySymbol: widget.currencySymbol,
                  scaleX: _scaleX,
                  offsetX: _offsetX,
                  yAxisWidth: _yAxisW,
                  barSpace: _barSpace,
                  onBarTap: (index) => setState(
                    () => _selectedBar = _selectedBar == index ? null : index,
                  ),
                  onScaleStart: (dx) {
                    _baseScaleX = _scaleX;
                    _baseOffsetX = _offsetX;
                    _lastFocalDx = dx;
                  },
                  onScaleUpdate: (scale, dx) {
                    final chartWidth = (ctx.size?.width ?? 300) - _yAxisW;
                    final barWidth = (chartWidth / (n / _baseScaleX)).clamp(
                      1.0,
                      double.infinity,
                    );
                    setState(() {
                      _scaleX = _baseScaleX * scale;
                      _clamp(n);
                      _offsetX = _baseOffsetX + (_lastFocalDx - dx) / barWidth;
                      _clamp(n);
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              const _LegendItem(color: incomeGreen, label: 'Income'),
              const _LegendItem(color: expenseRed, label: 'Expense'),
              if (peakBar >= 0)
                const _LegendItem(
                  color: Colors.orange,
                  label: 'Peak',
                  isDot: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Tap a bar for details. Pinch to zoom.',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
              if (_scaleX > 1.05)
                TextButton(
                  onPressed: () => setState(() {
                    _scaleX = 1;
                    _offsetX = 0;
                    _selectedBar = null;
                  }),
                  child: const Text('Reset zoom'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.primary,
                  size: 17,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
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
      onScaleStart: (d) => onScaleStart(d.localFocalPoint.dx),
      onScaleUpdate: (d) => onScaleUpdate(d.scale, d.localFocalPoint.dx),
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox;
        final loc = box.globalToLocal(d.globalPosition);
        final cW = box.size.width - yAxisWidth;
        final n = bars.length;
        if (n == 0 || cW <= 0) return;
        final visible = n / scaleX;
        final slotW = cW / visible;
        final dx = loc.dx - yAxisWidth;
        if (dx < 0) return;
        final idx = (offsetX + dx / slotW).floor().clamp(0, n - 1);
        onBarTap(idx);
      },
      child: CustomPaint(
        painter: _BarChartPainter(
          scheme: Theme.of(context).colorScheme,
          fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
          bars: bars,
          progress: progress,
          peakBar: peakBar,
          selectedBar: selectedBar,
          currencySymbol: currencySymbol,
          scaleX: scaleX,
          offsetX: offsetX,
          yAxisWidth: yAxisWidth,
          barSpace: barSpace,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<({String label, double income, double expense})> bars;
  final ColorScheme scheme;
  final String? fontFamily;
  final double progress;
  final int peakBar;
  final int? selectedBar;
  final String currencySymbol;
  final double scaleX;
  final double offsetX;
  final double yAxisWidth;
  final double barSpace;

  static const double _padTop = 20.0;
  static const double _padBottom = 34.0; // extra room for two-line labels

  const _BarChartPainter({
    required this.scheme,
    required this.fontFamily,
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

    final rawMax = bars.fold(
      0.0,
      (m, b) => math.max(m, math.max(b.income, b.expense)),
    );
    final maxVal = rawMax == 0 ? 1.0 : _niceMax(rawMax);

    final visible = n / scaleX;
    final startIdx = offsetX;
    final endIdx = math.min(offsetX + visible, n.toDouble());

    // slot width (pixels per bar slot including gap)
    final slotW = chartW / visible;
    final barW = math.max(4.0, slotW - barSpace * 2);

    double barX(int i) => yAxisWidth + (i - startIdx) * slotW + barSpace;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, yAxisWidth - 2, size.height),
      Paint()..color = scheme.surface,
    );

    const gridN = 4;
    final gridP = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .4)
      ..strokeWidth = 1;
    final yStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: 9,
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    for (int g = 0; g <= gridN; g++) {
      final frac = g / gridN;
      final y = _padTop + chartH * (1 - frac);
      final val = maxVal * frac;
      canvas.drawLine(Offset(yAxisWidth, y), Offset(size.width, y), gridP);
      final tp = TextPainter(
        text: TextSpan(text: _compact(val), style: yStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(yAxisWidth - tp.width - 5, y - tp.height / 2));
    }

    final axisP = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .5)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(yAxisWidth, _padTop),
      Offset(yAxisWidth, size.height - _padBottom),
      axisP,
    );
    canvas.drawLine(
      Offset(yAxisWidth, size.height - _padBottom),
      Offset(size.width, size.height - _padBottom),
      axisP,
    );

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(yAxisWidth, 0, chartW, size.height));

    final baseY = size.height - _padBottom;

    for (int i = startIdx.floor(); i < n && i < endIdx.ceil(); i++) {
      final x = barX(i);
      final bar = bars[i];
      final isPeak = i == peakBar;
      final isSelected = i == selectedBar;

      // Animated bar height
      final incH = (bar.income / maxVal * chartH * progress).clamp(0.0, chartH);
      final expH = (bar.expense / maxVal * chartH * progress).clamp(
        0.0,
        chartH,
      );

      final halfBar = barW / 2;
      final incX = x;
      final expX = x + halfBar + 1;
      final pairW = halfBar - 1;

      if (incH > 0) {
        final rr = RRect.fromRectAndCorners(
          Rect.fromLTWH(incX, baseY - incH, pairW, incH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        _drawDepthBar(canvas, rr, incomeGreen, isSelected);
      }

      if (expH > 0) {
        final rr = RRect.fromRectAndCorners(
          Rect.fromLTWH(expX, baseY - expH, pairW, expH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        _drawDepthBar(
          canvas,
          rr,
          isPeak ? Colors.orange : expenseRed,
          isSelected,
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

      if (isSelected) {
        // Highlight column background
        canvas.drawRect(
          Rect.fromLTWH(x - 2, _padTop, barW + 4, chartH),
          Paint()..color = scheme.primary.withValues(alpha: .06),
        );

        final label =
            '${bar.label.replaceAll('\n', ' ')}  In:$currencySymbol${_compact(bar.income)}  Out:$currencySymbol${_compact(bar.expense)}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 9.5,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(1.0, chartW - 18));
        final bW = tp.width + 18;
        final bH = tp.height + 10;
        final cx = x + barW / 2;
        double bx = cx - bW / 2;
        bx = bx.clamp(yAxisWidth, size.width - bW);
        const by = _padTop + 2.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bW, bH),
            const Radius.circular(8),
          ),
          Paint()..color = const Color(0xFF1E293B),
        );
        tp.paint(canvas, Offset(bx + 9, by + 5));
      }

      if (slotW >= 14) {
        final parts = bar.label.split(
          '\n',
        ); // e.g. ['Jan', '1'] or ['W1', 'Jan 1-7']
        final fontSize = slotW > 36
            ? 9.5
            : slotW > 22
            ? 8.5
            : 7.5;
        final topStyle = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: isSelected ? primaryBlue : scheme.onSurface,
        );
        final botStyle = TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize - 0.5,
          color: isSelected ? primaryBlue : scheme.onSurfaceVariant,
        );

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
          botTp.paint(
            canvas,
            Offset(cx - botTp.width / 2, topY + topTp.height + 1),
          );
        }
      }
    }

    canvas.restore();
  }

  void _drawDepthBar(Canvas canvas, RRect shape, Color color, bool selected) {
    final rect = shape.outerRect;
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, selected ? .2 : .4)!,
            color,
            Color.lerp(color, Colors.black, .18)!,
          ],
          stops: const [0, .55, 1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(rect),
    );
    if (rect.width > 4 && rect.height > 5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 1, rect.top + 1, rect.width - 2, 2),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.white.withValues(alpha: .45),
      );
    }
  }

  double _niceMax(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final r = v / mag;
    final nf = r <= 1
        ? 1.0
        : r <= 2
        ? 2.0
        : r <= 5
        ? 5.0
        : 10.0;
    return nf * mag * 1.15;
  }

  String _compact(double v) {
    if (v == 0) return '0';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.scheme != scheme ||
      old.fontFamily != fontFamily ||
      old.currencySymbol != currencySymbol ||
      old.progress != progress ||
      old.selectedBar != selectedBar ||
      old.scaleX != scaleX ||
      old.offsetX != offsetX ||
      old.bars != bars;
}

class _ViewDropdown extends StatelessWidget {
  const _ViewDropdown({required this.current, required this.onChanged});
  final _ViewMode current;
  final ValueChanged<_ViewMode> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<_ViewMode>(
    tooltip: 'Change chart view',
    initialValue: current,
    onSelected: onChanged,
    itemBuilder: (_) => [
      for (final mode in _ViewMode.values)
        PopupMenuItem(value: mode, child: Text(mode.label)),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            current.icon,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            current.label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    ),
  );
}

class _TotalChip extends StatelessWidget {
  const _TotalChip({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.color,
    required this.icon,
  });
  final String label;
  final double amount;
  final String symbol;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol ${formatCurrency(amount)}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: icon == Icons.chevron_left_rounded
        ? 'Previous month'
        : 'Next month',
    onPressed: enabled ? onTap : null,
    icon: Icon(icon, size: 20),
    color: Theme.of(context).colorScheme.primary,
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isDot;
  const _LegendItem({
    required this.color,
    required this.label,
    this.isDot = false,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      isDot
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
