// lib/providers/entries_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/hybrid_storage_service.dart';
import 'books_provider.dart';

final selectedBookIdProvider = StateProvider<String?>((ref) => null);

class EntriesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  EntriesNotifier(this._storage, this._bookId)
    : super(const AsyncValue.loading()) {
    if (_bookId != null) {
      loadEntries();
    }
  }

  final HybridStorageService _storage;
  final String? _bookId;

  double baseTotalIn = 0;
  double baseTotalOut = 0;

  Future<void> loadEntries() async {
    final bookId = _bookId;

    if (bookId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final data = await _storage.getEntryData(bookId);

      baseTotalIn = data['totalIncome'] as double;
      baseTotalOut = data['totalExpenses'] as double;

      state = AsyncValue.data(data['entries'] as List<Map<String, dynamic>>);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<bool> createEntry({
    required double amount,
    required String description,
    required bool isIncome,
    DateTime? entryDate,
  }) async {
    final bookId = _bookId;

    if (bookId == null) return false;

    final entry = await _storage.createEntry(
      bookId: bookId,
      amount: amount,
      description: description,
      isIncome: isIncome,
      entryDate: entryDate,
    );

    if (entry != null) {
      await loadEntries();
    }

    return entry != null;
  }

  Future<bool> updateEntry(
    String entryId, {
    double? amount,
    String? description,
  }) async {
    final ok = await _storage.updateEntry(
      entryId,
      amount: amount,
      description: description,
    );

    if (ok) {
      await loadEntries();
    }

    return ok;
  }

  Future<bool> deleteEntry(String entryId) async {
    final ok = await _storage.deleteEntry(entryId);

    if (ok) {
      state = state.whenData(
        (entries) => entries.where((entry) => entry['id'] != entryId).toList(),
      );
    }

    return ok;
  }
}

final entriesProvider =
    StateNotifierProvider.family<
      EntriesNotifier,
      AsyncValue<List<Map<String, dynamic>>>,
      String
    >((ref, bookId) {
      final storage = ref.watch(storageServiceProvider);

      return EntriesNotifier(storage, bookId);
    });
