import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lankar/providers/analytics_provider.dart';
import 'package:lankar/providers/auth_provider.dart';
import 'package:lankar/providers/books_provider.dart';
import 'package:lankar/services/hive_service.dart';
import 'package:lankar/services/hybrid_storage_service.dart';
import 'package:lankar/utils/analytics_data.dart';

Map<String, dynamic> entry(
  String id,
  String date,
  num amount, {
  bool income = false,
  String book = 'b1',
}) => {
  'id': id,
  'book_id': book,
  'entry_date': date,
  'amount': amount,
  'is_income': income,
  'description': 'Food',
};

class _Books extends BooksNotifier {
  _Books(this.records) : super(HybridStorageService(), null);
  List<Map<String, dynamic>> records;
  @override
  Future<void> loadBooks() async => state = AsyncValue.data(List.of(records));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 5, 12);
  test(
    'calendar periods exclude future entries and include the final day of previous months',
    () {
      final entries = [
        entry('income', '2026-10-05T09:00:00', 1000, income: true),
        entry('week', '2026-10-04T10:00:00', 10),
        entry('late', '2026-09-30T23:59:59', 70),
        entry('future', '2026-10-06T08:00:00', 900),
        entry('invalid', 'invalid', 800),
      ];
      final data = AnalyticsSnapshot(
        entries: entries,
        period: AnalyticsPeriod.month,
        now: now,
      );
      expect(data.income, 1000);
      expect(data.expense, 10);
      expect(data.previousExpense, 70);
      expect(data.months[10].expense, 70);
      expect(data.months.last.income, 1000);
      final week = AnalyticsSnapshot(
        entries: entries,
        period: AnalyticsPeriod.week,
        now: now,
      );
      expect(week.expense, 0);
      final quarter = AnalyticsSnapshot(
        entries: entries,
        period: AnalyticsPeriod.quarter,
        now: now,
      );
      expect(quarter.filtered.map((entry) => entry['id']), ['income', 'week']);
      expect(quarter.previousExpense, 70);
    },
  );
  test(
    'zero income, negative savings, categories and short-history estimates remain truthful',
    () {
      final spending = AnalyticsSnapshot(
        entries: [entry('food', '2026-10-05T10:00:00', 200)],
        period: AnalyticsPeriod.month,
        now: now,
      );
      expect(spending.savingsRate, isNull);
      expect(spending.savings, -200);
      expect(spending.categories, {'Food & dining': 200.0});
      expect(spending.projectedSavings, isNull);
      final negative = AnalyticsSnapshot(
        entries: [
          entry('income', '2026-10-05T09:00:00', 100, income: true),
          entry('expense', '2026-10-05T10:00:00', 200),
        ],
        period: AnalyticsPeriod.month,
        now: now,
      );
      expect(negative.savingsRate, -100);
    },
  );
  test('estimates and unusual expenses use actual history', () {
    final data = AnalyticsSnapshot(
      entries: [
        for (final month in [8, 9, 10])
          entry(
            'income-$month',
            '2026-${month.toString().padLeft(2, '0')}-01T09:00:00',
            1000,
            income: true,
          ),
        for (var i = 0; i < 8; i++)
          entry('expense-$i', '2026-10-05T10:00:00', 10),
        entry('large', '2026-10-05T11:00:00', 900),
      ],
      period: AnalyticsPeriod.month,
      now: now,
    );
    expect(data.unusualExpenses.single['id'], 'large');
    expect(data.projectedSavings, isNotNull);
    expect(data.projectedSavings!.isFinite, true);
  });

  test(
    'analytics streams only current books and observes entry and book changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'lankar-analytics-data-',
      );
      Hive.init(directory.path);
      final box = await Hive.openBox<Map>('analytics-entries');
      HiveService().entriesBox = box;
      await box.put(
        'income',
        entry('income', '2026-10-05T09:00:00', 100, income: true),
      );
      await box.put(
        'other',
        entry('other', '2026-10-05T09:00:00', 900, book: 'other-user'),
      );
      final container = ProviderContainer(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          booksProvider.overrideWith(
            (ref) => _Books([
              {'id': 'b1'},
            ]),
          ),
        ],
      );
      final update = Completer<void>();
      final listener = container.listen(analyticsEntriesProvider, (
        previous,
        next,
      ) {
        if (next.asData?.value.any((entry) => entry['id'] == 'new') == true &&
            !update.isCompleted) {
          update.complete();
        }
      });
      try {
        final initial = await container.read(analyticsEntriesProvider.future);
        expect(initial.map((entry) => entry['id']), ['income']);
        await box.put('new', entry('new', '2026-10-05T10:00:00', 20));
        await update.future.timeout(const Duration(seconds: 2));
        expect(
          container.read(analyticsEntriesProvider).asData!.value.length,
          2,
        );
        final books = container.read(booksProvider.notifier) as _Books;
        books.records = [];
        await books.loadBooks();
        expect(await container.read(analyticsEntriesProvider.future), isEmpty);
      } finally {
        listener.close();
        container.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
