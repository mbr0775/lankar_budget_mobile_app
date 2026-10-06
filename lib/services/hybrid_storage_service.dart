import '../utils/debug_log.dart';
// lib/services/hybrid_storage_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'hive_service.dart';
import 'supabase_service.dart';
import '../utils/helpers.dart';
import '../utils/app_errors.dart';

class HybridStorageService {
  static final HybridStorageService _instance =
      HybridStorageService._internal();
  factory HybridStorageService() => _instance;
  HybridStorageService._internal();

  final HiveService _hiveService = HiveService();
  final SupabaseService _supabaseService = SupabaseService();

  bool _isOnline = false;
  bool _isSyncing = false;
  bool _initialized = false;

  StreamSubscription<ConnectivityResult>? _connectivitySub;
  Timer? _syncTimer;

  static const int _maxRetries = 3;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  AppFailure? lastSyncFailure;
  bool isEntryPendingSync(String id) =>
      _hiveService.entriesBox.get(id)?['synced'] != true;
  Box<Map> get syncQueueBox => _hiveService.syncQueueBox;

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _supabaseService.assignClient();

    await _purgeExhaustedOps();

    // ✅ Check connectivity on startup (v1.x API — returns ConnectivityResult)
    try {
      final result = await Connectivity().checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      debugLog('🌐 Initial connectivity: $_isOnline ($result)');
    } catch (e) {
      _isOnline = false;
      debugLog('🌐 Connectivity check failed: $e');
    }

    // ✅ Listen for connectivity changes (v1.x API)
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      _handleConnectivityChange,
    );

    // ✅ If online at startup, sync immediately
    if (_isOnline) {
      unawaited(_verifyAndSync());
    }

    // Periodic sync every 2 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (_isOnline && await getUnsyncedCount() > 0) {
        await syncWithSupabase();
      }
    });
  }

  // ✅ v1.x: handler takes single ConnectivityResult
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOffline = !_isOnline;
    _isOnline = result != ConnectivityResult.none;
    debugLog('🌐 Connectivity changed: $_isOnline ($result)');
    if (wasOffline && _isOnline) {
      unawaited(_verifyAndSync());
    }
  }

  /// ✅ FIX: Use auth check instead of table query to avoid RLS blocking
  Future<void> _verifyAndSync() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        debugLog('⚠️ Not authenticated, skipping sync');
        return;
      }
      _isOnline = true;
      debugLog('✅ Authenticated as ${user.email}, starting sync');
      await syncWithSupabase();
    } catch (e) {
      debugLog('⚠️ _verifyAndSync error: $e');
      _isOnline = false;
    }
  }

  Future<void> _purgeExhaustedOps() async {
    try {
      final keys = _hiveService.syncQueueBox.keys.toList();
      for (final k in keys) {
        final op = _hiveService.syncQueueBox.get(k);
        if (op != null) {
          final data = op['data'] as Map? ?? {};
          final userId = data['user_id'] as String? ?? '';
          if (userId == 'demo_user') {
            await _hiveService.syncQueueBox.delete(k);
          }
        }
      }
      final bookKeys = _hiveService.booksBox.keys.toList();
      for (final k in bookKeys) {
        final book = _hiveService.booksBox.get(k);
        if (book != null) {
          final userId = book['user_id'] as String? ?? '';
          if (userId == 'demo_user') {
            await _hiveService.booksBox.delete(k);
          }
        }
      }
    } catch (_) {}
  }

  // ── Books ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createBook(String name, String userId) async {
    Map<String, dynamic>? book;
    if (_isOnline) {
      try {
        book = await _supabaseService.createBook(
          name,
          userId,
          0.0,
          DateTime.now().toIso8601String(),
        );
      } catch (error, stack) {
        AppErrors.report('Create remote book', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    if (book != null) {
      book['synced'] = true;
      try {
        await _hiveService.booksBox.put(book['id'], book);
      } catch (error, stack) {
        AppErrors.report('Cache saved book', error, stack);
      }
      return book;
    }
    return _hiveService.createBook(name, userId);
  }

  Future<List<Map<String, dynamic>>> getBooksWithBalances(String userId) async {
    if (_isOnline) {
      try {
        final remote = await _supabaseService.getBooks(userId);
        for (var b in remote) {
          b['synced'] = true;
          await _hiveService.booksBox.put(b['id'], b);
        }
        debugLog('✅ Fetched ${remote.length} books from remote');
      } catch (e) {
        debugLog('getBooksWithBalances online error: $e');
      }
    }
    final books = await _hiveService.getBooks(userId);
    await Future.wait(
      books.map((book) async {
        try {
          final income = await getTotalIncome(book['id'] as String);
          final expenses = await getTotalExpenses(book['id'] as String);
          final balance = income - expenses;
          unawaited(
            updateBookBalance(book['id'] as String, balance).catchError((
              Object error,
              StackTrace stack,
            ) {
              AppErrors.report('Refresh book balance', error, stack);
              return false;
            }),
          );
          book['balance'] = balance;
        } catch (_) {
          book['balance'] = 0.0;
        }
      }),
    );
    return books;
  }

  Future<bool> updateBookBalance(String bookId, double balance) async {
    if (_isOnline && !bookId.startsWith('temp_')) {
      try {
        final ok = await _supabaseService.updateBookBalance(bookId, balance);
        if (ok) {
          await _hiveService.updateBookBalance(
            bookId,
            balance,
            addToQueue: false,
          );
          await _hiveService.markAsSynced('book', bookId);
          return true;
        }
      } catch (error, stack) {
        AppErrors.report('updateBookBalance', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    return await _hiveService.updateBookBalance(bookId, balance);
  }

  Future<bool> updateBookName(String bookId, String newName) async {
    if (_isOnline && !bookId.startsWith('temp_')) {
      try {
        final ok = await _supabaseService.updateBookName(bookId, newName);
        if (ok) {
          await _hiveService.updateBookName(bookId, newName, addToQueue: false);
          await _hiveService.markAsSynced('book', bookId);
          return true;
        }
      } catch (error, stack) {
        AppErrors.report('updateBookName', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    return await _hiveService.updateBookName(bookId, newName);
  }

  Future<bool> deleteBook(String bookId) async {
    if (_isOnline && !bookId.startsWith('temp_')) {
      try {
        final ok = await _supabaseService.deleteBook(bookId);
        if (ok) {
          await _hiveService.deleteBook(bookId, addToQueue: false);
          return true;
        }
      } catch (error, stack) {
        AppErrors.report('deleteBook', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    return await _hiveService.deleteBook(bookId);
  }

  // ── Entries ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createEntry({
    required String bookId,
    required double amount,
    required String description,
    required bool isIncome,
    DateTime? entryDate,
  }) async {
    Map<String, dynamic>? entry;
    if (_isOnline && !bookId.startsWith('temp_')) {
      try {
        entry = await _supabaseService.createEntry(
          bookId: bookId,
          amount: amount,
          description: description,
          isIncome: isIncome,
          entryDate: entryDate,
        );
      } catch (error, stack) {
        AppErrors.report('Create remote entry', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    if (entry != null) {
      entry['synced'] = true;
      try {
        await _hiveService.entriesBox.put(entry['id'], entry);
      } catch (error, stack) {
        AppErrors.report('Cache saved entry', error, stack);
      }
      return entry;
    }
    return _hiveService.createEntry(
      bookId: bookId,
      amount: amount,
      description: description,
      isIncome: isIncome,
      entryDate: entryDate,
    );
  }

  Future<List<Map<String, dynamic>>> getEntries(String bookId) async {
    if (_isOnline && !bookId.startsWith('temp_')) {
      try {
        final remote = await _supabaseService.getEntries(bookId);
        for (var e in remote) {
          e['synced'] = true;
          await _hiveService.entriesBox.put(e['id'], e);
        }
      } catch (_) {}
    }
    return await _hiveService.getEntries(bookId);
  }

  Future<bool> updateEntry(
    String entryId, {
    double? amount,
    String? description,
  }) async {
    if (_isOnline && !entryId.startsWith('temp_')) {
      try {
        final ok = await _supabaseService.updateEntry(
          entryId,
          amount: amount,
          description: description,
        );
        if (ok) {
          await _hiveService.updateEntry(
            entryId,
            amount: amount,
            description: description,
            addToQueue: false,
          );
          await _hiveService.markAsSynced('entry', entryId);
          return true;
        }
      } catch (error, stack) {
        AppErrors.report('updateEntry', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    return await _hiveService.updateEntry(
      entryId,
      amount: amount,
      description: description,
    );
  }

  Future<bool> deleteEntry(String entryId) async {
    if (_isOnline && !entryId.startsWith('temp_')) {
      try {
        final ok = await _supabaseService.deleteEntry(entryId);
        if (ok) {
          await _hiveService.deleteEntry(entryId, addToQueue: false);
          return true;
        }
      } catch (error, stack) {
        AppErrors.report('deleteEntry', error, stack);
        if (!AppErrors.canSaveOffline(error)) rethrow;
      }
    }
    return await _hiveService.deleteEntry(entryId);
  }

  Future<double> getTotalIncome(String bookId) =>
      _hiveService.getTotalIncome(bookId);

  Future<double> getTotalExpenses(String bookId) =>
      _hiveService.getTotalExpenses(bookId);

  Future<Map<String, dynamic>> getEntryData(String bookId) async {
    final results = await Future.wait([
      getEntries(bookId),
      getTotalIncome(bookId),
      getTotalExpenses(bookId),
    ]);
    return {
      'entries': results[0] as List<Map<String, dynamic>>,
      'totalIncome': results[1] as double,
      'totalExpenses': results[2] as double,
    };
  }

  // ── Sync ──────────────────────────────────────────────────────────────────
  Future<bool> syncWithSupabase({bool retryFailed = false}) async {
    if (_isSyncing) return false;
    lastSyncFailure = null;
    _isSyncing = true;

    // ✅ FIX: Check auth instead of querying table (avoids RLS false failures)
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        lastSyncFailure = AppErrors.session;
        debugLog('⚠️ syncWithSupabase: not authenticated');
        _isSyncing = false;
        return false;
      }
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      _isSyncing = false;
      lastSyncFailure = AppErrors.from(e);
      return false;
    }

    debugLog(
      '🔄 Sync started — queue: ${_hiveService.syncQueueBox.length} ops',
    );

    try {
      final pendingOps = await _hiveService.getPendingSyncOperations();
      final idMapping = <String, String>{};

      for (final op in pendingOps) {
        final operation = op['operation'] as String;
        final data = Map<String, dynamic>.from(op['data'] as Map);
        final queueId = op['id'] as String;
        final retries = (op['retries'] as int?) ?? 0;

        if (retries >= _maxRetries && !retryFailed) {
          // Retain failed writes for an explicit manual retry.
          continue;
        }

        final dataCopy = Map<String, dynamic>.from(data);

        if (dataCopy.containsKey('id') &&
            idMapping.containsKey(dataCopy['id'])) {
          dataCopy['id'] = idMapping[dataCopy['id']];
        }
        if (dataCopy.containsKey('book_id') &&
            idMapping.containsKey(dataCopy['book_id'])) {
          dataCopy['book_id'] = idMapping[dataCopy['book_id']];
        }

        if ((operation.startsWith('update_') ||
                operation.startsWith('delete_')) &&
            (dataCopy['id'] as String? ?? '').startsWith('temp_')) {
          await _hiveService.removeSyncQueueItem(queueId);
          continue;
        }

        if (operation == 'create_entry' &&
            (dataCopy['book_id'] as String? ?? '').startsWith('temp_')) {
          continue;
        }

        try {
          String? type;
          final originalId = data['id'] as String? ?? '';
          String itemId = idMapping[originalId] ?? originalId;

          switch (operation) {
            case 'create_book':
              type = 'book';
              if (!_hiveService.booksBox.containsKey(originalId)) {
                await _hiveService.removeSyncQueueItem(queueId);
                continue;
              }
              final authUid = _supabaseService.currentUserId;
              if (authUid == null) {
                debugLog('Skipping create_book: not authenticated');
                continue;
              }
              debugLog('📤 Syncing book "${dataCopy['name']}"');
              final bRes = await _supabaseService.client
                  .from('books')
                  .insert({
                    'name': dataCopy['name'],
                    'user_id': authUid,
                    'balance': dataCopy['balance'] ?? 0.0,
                    'created_at': dataCopy['created_at'],
                  })
                  .select()
                  .single();
              final newBId = bRes['id'] as String;
              idMapping[originalId] = newBId;
              itemId = newBId;
              var bk = _hiveService.booksBox.get(originalId);
              if (bk != null) {
                bk = Map.from(bk);
                await _hiveService.booksBox.delete(originalId);
                bk['id'] = newBId;
                bk['synced'] = true;
                await _hiveService.booksBox.put(newBId, bk);
              }
              for (final k in _hiveService.entriesBox.keys.toList()) {
                var e = _hiveService.entriesBox.get(k);
                if (e != null && e['book_id'] == originalId) {
                  e = Map.from(e);
                  e['book_id'] = newBId;
                  await _hiveService.entriesBox.put(k, e);
                }
              }
              for (final k in _hiveService.syncQueueBox.keys.toList()) {
                var qOp = _hiveService.syncQueueBox.get(k);
                if (qOp != null) {
                  final qData = Map<String, dynamic>.from(
                    qOp['data'] as Map? ?? {},
                  );
                  if (qData['book_id'] == originalId) {
                    qOp = Map.from(qOp);
                    final updatedData = Map<String, dynamic>.from(qData);
                    updatedData['book_id'] = newBId;
                    qOp['data'] = updatedData;
                    await _hiveService.syncQueueBox.put(k, qOp);
                  }
                }
              }
              debugLog('✅ Book synced: $originalId → $newBId');
              break;

            case 'create_entry':
              type = 'entry';
              if (!_hiveService.entriesBox.containsKey(originalId)) {
                await _hiveService.removeSyncQueueItem(queueId);
                continue;
              }
              final eRes = await _supabaseService.client
                  .from('entries')
                  .insert({
                    'book_id': dataCopy['book_id'],
                    'amount': dataCopy['amount'],
                    'description': dataCopy['description'],
                    'is_income': dataCopy['is_income'],
                    'entry_date': dataCopy['entry_date'],
                    'created_at': dataCopy['created_at'],
                  })
                  .select()
                  .single();
              final newEId = eRes['id'] as String;
              idMapping[originalId] = newEId;
              itemId = newEId;
              var en = _hiveService.entriesBox.get(originalId);
              if (en != null) {
                en = Map.from(en);
                await _hiveService.entriesBox.delete(originalId);
                en['id'] = newEId;
                en['synced'] = true;
                await _hiveService.entriesBox.put(newEId, en);
              }
              break;

            case 'update_book':
              type = 'book';
              await _supabaseService.client
                  .from('books')
                  .update({
                    'name': dataCopy['name'],
                    'balance': dataCopy['balance'],
                  })
                  .eq('id', dataCopy['id'] as Object)
                  .select('id')
                  .single();
              break;

            case 'update_entry':
              type = 'entry';
              await _supabaseService.client
                  .from('entries')
                  .update({
                    'amount': dataCopy['amount'],
                    'description': dataCopy['description'],
                  })
                  .eq('id', dataCopy['id'] as Object)
                  .select('id')
                  .single();
              break;

            case 'delete_book':
              await _supabaseService.client
                  .from('books')
                  .delete()
                  .eq('id', dataCopy['id'] as Object);
              break;

            case 'delete_entry':
              await _supabaseService.client
                  .from('entries')
                  .delete()
                  .eq('id', dataCopy['id'] as Object);
              break;
          }

          if (type != null &&
              (operation.startsWith('create') ||
                  operation.startsWith('update'))) {
            await _hiveService.markAsSynced(type, itemId);
          }
          await _hiveService.removeSyncQueueItem(queueId);
        } catch (error, stack) {
          lastSyncFailure = AppErrors.from(error);
          AppErrors.report('Sync $operation', error, stack);
          await _incrementRetry(queueId, op);
        }
      }
      return await getUnsyncedCount() == 0;
    } catch (error, stack) {
      lastSyncFailure = AppErrors.from(error);
      AppErrors.report('Sync pending changes', error, stack);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _incrementRetry(String queueId, Map<String, dynamic> op) async {
    try {
      final current = _hiveService.syncQueueBox.get(queueId);
      if (current != null) {
        final updated = Map<String, dynamic>.from(current);
        updated['retries'] = ((updated['retries'] as int?) ?? 0) + 1;
        await _hiveService.syncQueueBox.put(queueId, updated);
      }
    } catch (_) {}
  }

  Future<int> getUnsyncedCount() => _hiveService.getUnsyncedCount();
  Future<void> clearAllData() => _hiveService.clearAllData();

  void dispose() {
    _connectivitySub?.cancel();
    _syncTimer?.cancel();
  }
}
