import 'dart:math' as math;
import 'report_data.dart';

enum AnalyticsPeriod {
  week('This week'),
  month('This month'),
  quarter('This quarter'),
  year('This year');

  const AnalyticsPeriod(this.label);
  final String label;
  DateTime start(DateTime now) => switch (this) {
    AnalyticsPeriod.week => DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    ),
    AnalyticsPeriod.month => DateTime(now.year, now.month, 1),
    AnalyticsPeriod.quarter => DateTime(
      now.year,
      ((now.month - 1) ~/ 3) * 3 + 1,
      1,
    ),
    AnalyticsPeriod.year => DateTime(now.year, 1, 1),
  };
  DateTime previousStart(DateTime now) => switch (this) {
    AnalyticsPeriod.week => start(now).subtract(const Duration(days: 7)),
    AnalyticsPeriod.month => DateTime(now.year, now.month - 1, 1),
    AnalyticsPeriod.quarter => DateTime(
      start(now).year,
      start(now).month - 3,
      1,
    ),
    AnalyticsPeriod.year => DateTime(now.year - 1, 1, 1),
  };
}

class AnalyticsMonth {
  const AnalyticsMonth(this.date, this.income, this.expense);
  final DateTime date;
  final double income;
  final double expense;
}

class AnalyticsSnapshot {
  AnalyticsSnapshot({
    required this.entries,
    required this.period,
    required this.now,
  }) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    filtered = _between(period.start(now), tomorrow);
    income = reportTotal(filtered, true);
    expense = reportTotal(filtered, false);
    final grouped = <String, double>{};
    for (final entry in filtered.where(
      (entry) => entry['is_income'] == false,
    )) {
      final category = categoriseExpense(entry['description'] as String? ?? '');
      grouped[category] =
          (grouped[category] ?? 0) + (entry['amount'] as num).toDouble();
    }
    categories = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
    months = [
      for (var i = 11; i >= 0; i--)
        _month(DateTime(now.year, now.month - i, 1), tomorrow),
    ];
  }
  final List<Map<String, dynamic>> entries;
  final AnalyticsPeriod period;
  final DateTime now;
  late final List<Map<String, dynamic>> filtered;
  late final double income;
  late final double expense;
  late final Map<String, double> categories;
  late final List<AnalyticsMonth> months;
  double get savings => income - expense;
  double? get savingsRate => income > 0 ? savings / income * 100 : null;
  double get previousExpense => reportTotal(
    _between(period.previousStart(now), period.start(now)),
    false,
  );

  List<Map<String, dynamic>> _between(DateTime start, DateTime end) =>
      entries.where((entry) {
        final date = reportDate(entry);
        return date != null && !date.isBefore(start) && date.isBefore(end);
      }).toList();
  AnalyticsMonth _month(DateTime start, DateTime tomorrow) {
    final next = DateTime(start.year, start.month + 1, 1);
    final data = _between(start, next.isAfter(tomorrow) ? tomorrow : next);
    return AnalyticsMonth(
      start,
      reportTotal(data, true),
      reportTotal(data, false),
    );
  }

  List<Map<String, dynamic>> get unusualExpenses {
    final expenses = filtered
        .where((entry) => entry['is_income'] == false)
        .toList();
    if (expenses.length < 3) return [];
    final mean = expense / expenses.length;
    final variance =
        expenses.fold<double>(
          0,
          (sum, entry) =>
              sum + math.pow((entry['amount'] as num).toDouble() - mean, 2),
        ) /
        expenses.length;
    final threshold = mean + 2 * math.sqrt(variance);
    return expenses
        .where((entry) => (entry['amount'] as num).toDouble() > threshold)
        .toList();
  }

  double? get projectedSavings {
    final active = months
        .where((month) => month.income != 0 || month.expense != 0)
        .toList();
    if (active.length < 3) return null;
    final history = months
        .skipWhile((month) => month.income == 0 && month.expense == 0)
        .toList();
    final n = history.length;
    final values = history
        .map((month) => month.income - month.expense)
        .toList();
    final sumX = n * (n - 1) / 2;
    final sumY = values.fold<double>(0, (sum, value) => sum + value);
    final sumXY = List.generate(
      n,
      (i) => i * values[i],
    ).fold<double>(0, (sum, value) => sum + value);
    final sumXX = List.generate(
      n,
      (i) => i * i,
    ).fold<double>(0, (sum, value) => sum + value);
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    return List.generate(
      12,
      (i) => intercept + slope * (n + i),
    ).fold<double>(0, (sum, value) => sum + value);
  }
}

String categoriseExpense(String description) {
  final text = description.toLowerCase();
  for (final group in <String, List<String>>{
    'Food & dining': [
      'food',
      'meal',
      'restaurant',
      'lunch',
      'dinner',
      'breakfast',
      'coffee',
      'cafe',
    ],
    'Transport': [
      'fuel',
      'petrol',
      'gas',
      'transport',
      'taxi',
      'uber',
      'bus',
      'metro',
    ],
    'Shopping': ['shop', 'cloth', 'purchase', 'buy', 'amazon'],
    'Utilities': ['bill', 'electric', 'water', 'utility', 'internet'],
    'Health': ['health', 'doctor', 'medicine', 'pharmacy', 'hospital'],
    'Housing': ['rent', 'house', 'mortgage'],
    'Entertainment': ['entertain', 'movie', 'game', 'netflix', 'cinema'],
  }.entries) {
    if (group.value.any(text.contains)) return group.key;
  }
  return 'Other';
}
