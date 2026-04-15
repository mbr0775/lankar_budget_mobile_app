// lib/providers/books_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hybrid_storage_service.dart';
import '../services/hive_service.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';

final storageServiceProvider =
    Provider<HybridStorageService>((_) => HybridStorageService());

class BooksNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  BooksNotifier(this._storage, this._userId)
      : super(const AsyncValue.loading()) {
    loadBooks();
  }

  final HybridStorageService _storage;
  final String? _userId;

  // ── Main load: books + entries + balances in one shot ──────────────────
  Future<void> loadBooks() async {
    if (_userId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      // ── Step 1: Show local data instantly (no waiting) ──────────────────
      final localBooks = await HiveService().getBooks(_userId!);
      for (final book in localBooks) {
        final income   = await HiveService().getTotalIncome(book['id'] as String);
        final expenses = await HiveService().getTotalExpenses(book['id'] as String);
        book['balance'] = income - expenses;
      }
      if (mounted) state = AsyncValue.data(List.from(localBooks));

      // ── Step 2: If online, fetch everything from Supabase ───────────────
      if (_storage.isOnline) {
        await _syncAllFromRemote();
      }
    } catch (e, s) {
      if (state is AsyncData) return; // already have local data, don't error
      if (mounted) state = AsyncValue.error(e, s);
    }
  }

  /// Fetches all books + all their entries from Supabase,
  /// caches everything into Hive, then updates state with correct balances.
  Future<void> _syncAllFromRemote() async {
    if (_userId == null) return;
    try {
      final supabase = SupabaseService();
      supabase.assignClient();

      // 1. Fetch books from remote
      final remoteBooks = await supabase.getBooks(_userId!);
      if (remoteBooks.isEmpty) return;

      // 2. Fetch entries for ALL books in parallel
      final entriesByBook = <String, List<Map<String, dynamic>>>{};
      await Future.wait(remoteBooks.map((book) async {
        final bookId  = book['id'] as String;
        final entries = await supabase.getEntries(bookId);
        entriesByBook[bookId] = entries;

        // Cache entries into Hive immediately
        for (final entry in entries) {
          entry['synced'] = true;
          await HiveService().entriesBox.put(entry['id'], entry);
        }
      }));

      // 3. Compute real balance for each book from fetched entries
      final updatedBooks = remoteBooks.map((book) {
        final bookId  = book['id'] as String;
        final entries = entriesByBook[bookId] ?? [];
        final income  = entries
            .where((e) => e['is_income'] == true)
            .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
        final expense = entries
            .where((e) => e['is_income'] == false)
            .fold(0.0, (s, e) => s + (e['amount'] as num).toDouble());
        final balance = income - expense;

        // Update Hive book cache with correct balance
        final cached = Map<String, dynamic>.from(book);
        cached['balance'] = balance;
        cached['synced']  = true;
        HiveService().booksBox.put(bookId, cached);

        return {...cached, 'balance': balance};
      }).toList();

      // Sort newest first
      updatedBooks.sort((a, b) => DateTime.parse(b['created_at'] as String)
          .compareTo(DateTime.parse(a['created_at'] as String)));

      if (mounted) state = AsyncValue.data(updatedBooks);
      debugPrint('✅ Synced ${remoteBooks.length} books + all entries on load');
    } catch (e) {
      debugPrint('⚠️ _syncAllFromRemote error: $e');
      // Don't crash — local data already shown in Step 1
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> createBook(String name) async {
    if (_userId == null) return null;
    debugPrint('📖 createBook: name=$name userId=$_userId online=${_storage.isOnline}');

    final book = await _storage.createBook(name, _userId!);
    debugPrint('📖 createBook result: $book');

    if (book != null) {
      // Immediately insert into state so UI shows it right away
      if (mounted) {
        final current = state.asData?.value ?? [];
        final updated = [
          {...book, 'balance': (book['balance'] as num?)?.toDouble() ?? 0.0},
          ...current,
        ];
        state = AsyncValue.data(updated);
      }
      // Full reload after short delay to get accurate server data
      await Future.delayed(const Duration(milliseconds: 500));
      await loadBooks();
    }
    return book;
  }

  Future<bool> renameBook(String bookId, String newName) async {
    final ok = await _storage.updateBookName(bookId, newName);
    if (ok) await loadBooks();
    return ok;
  }

  Future<bool> deleteBook(String bookId) async {
    final ok = await _storage.deleteBook(bookId);
    if (ok && mounted) {
      state = state.whenData(
          (books) => books.where((b) => b['id'] != bookId).toList());
    }
    return ok;
  }
}

final booksProvider = StateNotifierProvider<BooksNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) {
    final user    = ref.watch(currentUserProvider);
    final storage = ref.watch(storageServiceProvider);
    return BooksNotifier(storage, user?.id);
  },
);