// lib/services/hive_service.dart
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  late Box<Map> booksBox;
  late Box<Map> entriesBox;
  late Box<Map> syncQueueBox;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;          // safe to call multiple times
    _initialized = true;

    await Hive.initFlutter();
    booksBox     = await Hive.openBox<Map>('books');
    entriesBox   = await Hive.openBox<Map>('entries');
    syncQueueBox = await Hive.openBox<Map>('sync_queue');
  }

  // ── Books ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createBook(String name, String userId,
      {bool addToQueue = true}) async {
    final bookId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final book = {
      'id': bookId, 'name': name, 'user_id': userId,
      'balance': 0.0, 'created_at': DateTime.now().toIso8601String(),
      'synced': false,
    };
    await booksBox.put(bookId, book);
    if (addToQueue) await _addToSyncQueue('create_book', book);
    return book;
  }

  Future<List<Map<String, dynamic>>> getBooks(String userId) async {
    final books = <Map<String, dynamic>>[];
    for (var key in booksBox.keys) {
      final b = Map<String, dynamic>.from(booksBox.get(key)!);
      if (b['user_id'] == userId) books.add(b);
    }
    books.sort((a, b) =>
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    return books;
  }

  Future<bool> updateBookBalance(String bookId, double balance,
      {bool addToQueue = true}) async {
    try {
      final book = Map<String, dynamic>.from(booksBox.get(bookId)!);
      book['balance'] = balance; book['synced'] = false;
      await booksBox.put(bookId, book);
      if (addToQueue) await _addToSyncQueue('update_book', book);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> updateBookName(String bookId, String newName,
      {bool addToQueue = true}) async {
    try {
      final book = Map<String, dynamic>.from(booksBox.get(bookId)!);
      book['name'] = newName; book['synced'] = false;
      await booksBox.put(bookId, book);
      if (addToQueue) await _addToSyncQueue('update_book', book);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteBook(String bookId, {bool addToQueue = true}) async {
    try {
      final toDelete = <String>[];
      for (var key in entriesBox.keys) {
        final e = Map<String, dynamic>.from(entriesBox.get(key)!);
        if (e['book_id'] == bookId) toDelete.add(key.toString());
      }
      for (var k in toDelete) await entriesBox.delete(k);
      await booksBox.delete(bookId);
      if (addToQueue) await _addToSyncQueue('delete_book', {'id': bookId});
      return true;
    } catch (e) { return false; }
  }

  // ── Entries ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createEntry({
    required String bookId,
    required double amount,
    required String description,
    required bool isIncome,
    DateTime? entryDate,
    bool addToQueue = true,
  }) async {
    final entryId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final entry = {
      'id': entryId, 'book_id': bookId, 'amount': amount,
      'description': description, 'is_income': isIncome,
      'entry_date': (entryDate ?? DateTime.now()).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(), 'synced': false,
    };
    await entriesBox.put(entryId, entry);
    if (addToQueue) await _addToSyncQueue('create_entry', entry);
    return entry;
  }

  Future<List<Map<String, dynamic>>> getEntries(String bookId) async {
    final entries = <Map<String, dynamic>>[];
    for (var key in entriesBox.keys) {
      final e = Map<String, dynamic>.from(entriesBox.get(key)!);
      if (e['book_id'] == bookId) entries.add(e);
    }
    entries.sort((a, b) => DateTime.parse(b['entry_date'])
        .compareTo(DateTime.parse(a['entry_date'])));
    return entries;
  }

  Future<bool> updateEntry(String entryId,
      {double? amount, String? description, bool addToQueue = true}) async {
    try {
      final entry = Map<String, dynamic>.from(entriesBox.get(entryId)!);
      if (amount != null) entry['amount'] = amount;
      if (description != null) entry['description'] = description;
      entry['synced'] = false;
      await entriesBox.put(entryId, entry);
      if (addToQueue) await _addToSyncQueue('update_entry', entry);
      return true;
    } catch (e) { return false; }
  }

  Future<bool> deleteEntry(String entryId, {bool addToQueue = true}) async {
    try {
      await entriesBox.delete(entryId);
      if (addToQueue) await _addToSyncQueue('delete_entry', {'id': entryId});
      return true;
    } catch (e) { return false; }
  }

  Future<double> getTotalIncome(String bookId) async {
    double total = 0;
    for (var key in entriesBox.keys) {
      final e = Map<String, dynamic>.from(entriesBox.get(key)!);
      if (e['book_id'] == bookId && e['is_income'] == true)
        total += (e['amount'] as num).toDouble();
    }
    return total;
  }

  Future<double> getTotalExpenses(String bookId) async {
    double total = 0;
    for (var key in entriesBox.keys) {
      final e = Map<String, dynamic>.from(entriesBox.get(key)!);
      if (e['book_id'] == bookId && e['is_income'] == false)
        total += (e['amount'] as num).toDouble();
    }
    return total;
  }

  // ── Sync Queue ─────────────────────────────────────────────────────────────
  Future<void> _addToSyncQueue(String operation,
      Map<String, dynamic> data) async {
    final queueId = DateTime.now().millisecondsSinceEpoch.toString();
    await syncQueueBox.put(queueId, {
      'id': queueId, 'operation': operation, 'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'retries': 0,                              // track retries from creation
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    final ops = <Map<String, dynamic>>[];
    for (var key in syncQueueBox.keys)
      ops.add(Map<String, dynamic>.from(syncQueueBox.get(key)!));
    ops.sort((a, b) =>
        DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));
    return ops;
  }

  Future<void> clearSyncQueue()                    => syncQueueBox.clear();
  Future<void> removeSyncQueueItem(String queueId) => syncQueueBox.delete(queueId);

  Future<void> markAsSynced(String type, String id) async {
    try {
      if (type == 'book') {
        final b = booksBox.get(id);
        if (b != null) {
          final m = Map<String, dynamic>.from(b); m['synced'] = true;
          await booksBox.put(id, m);
        }
      } else if (type == 'entry') {
        final e = entriesBox.get(id);
        if (e != null) {
          final m = Map<String, dynamic>.from(e); m['synced'] = true;
          await entriesBox.put(id, m);
        }
      }
    } catch (e) { print('markAsSynced error: $e'); }
  }

  Future<void> syncFromSupabase(List<Map<String, dynamic>> books,
      Map<String, List<Map<String, dynamic>>> entries) async {
    await booksBox.clear();
    await entriesBox.clear();
    for (var book in books) {
      book['synced'] = true;
      await booksBox.put(book['id'], book);
    }
    for (var bookId in entries.keys)
      for (var entry in entries[bookId]!) {
        entry['synced'] = true;
        await entriesBox.put(entry['id'], entry);
      }
  }

  Future<int> getUnsyncedCount() => Future.value(syncQueueBox.length);

  Future<void> clearAllData() async {
    await booksBox.clear();
    await entriesBox.clear();
    await syncQueueBox.clear();
  }
}