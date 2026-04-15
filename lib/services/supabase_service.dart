// lib/services/supabase_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url:     SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    client = Supabase.instance.client;
  }

  void assignClient() {
    client = Supabase.instance.client;
  }

  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated  => client.auth.currentUser != null;

  // ── Books ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createBook(
      String name, String userId, double balance, String createdAt) async {
    try {
      final authUid = currentUserId;
      if (authUid == null) {
        debugPrint('❌ createBook: not authenticated');
        return null;
      }
      debugPrint('📤 Supabase createBook: name=$name uid=$authUid');
      final result = await client.from('books').insert({
        'name':       name,
        'user_id':    authUid,   // ✅ always real auth uid
        'balance':    balance,
        'created_at': createdAt,
      }).select().single();
      debugPrint('✅ createBook OK: ${result['id']}');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('❌ createBook error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getBooks(String userId) async {
    try {
      final res = await client
          .from('books')
          .select()
          .order('created_at', ascending: false);
      debugPrint('✅ getBooks: ${res.length} rows');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ getBooks error: $e');
      return [];
    }
  }

  Future<bool> updateBookBalance(String bookId, double balance) async {
    try {
      await client
          .from('books')
          .update({'balance': balance})
          .eq('id', bookId);
      return true;
    } catch (e) {
      debugPrint('❌ updateBookBalance error: $e');
      return false;
    }
  }

  Future<bool> updateBookName(String bookId, String newName) async {
    try {
      await client
          .from('books')
          .update({'name': newName})
          .eq('id', bookId);
      return true;
    } catch (e) {
      debugPrint('❌ updateBookName error: $e');
      return false;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      await client.from('books').delete().eq('id', bookId);
      return true;
    } catch (e) {
      debugPrint('❌ deleteBook error: $e');
      return false;
    }
  }

  // ── Entries ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createEntry({
    required String bookId,
    required double amount,
    required String description,
    required bool isIncome,
    DateTime? entryDate,
  }) async {
    try {
      if (!isAuthenticated) {
        debugPrint('❌ createEntry: not authenticated');
        return null;
      }
      final result = await client.from('entries').insert({
        'book_id':     bookId,
        'amount':      amount,
        'description': description,
        'is_income':   isIncome,
        'entry_date':  (entryDate ?? DateTime.now()).toIso8601String(),
        'created_at':  DateTime.now().toIso8601String(),
      }).select().single();
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('❌ createEntry error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getEntries(String bookId) async {
    try {
      final res = await client
          .from('entries')
          .select()
          .eq('book_id', bookId)
          .order('entry_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('❌ getEntries error: $e');
      return [];
    }
  }

  Future<bool> updateEntry(String entryId,
      {double? amount, String? description}) async {
    try {
      final updates = <String, dynamic>{};
      if (amount      != null) updates['amount']      = amount;
      if (description != null) updates['description'] = description;
      await client.from('entries').update(updates).eq('id', entryId);
      return true;
    } catch (e) {
      debugPrint('❌ updateEntry error: $e');
      return false;
    }
  }

  Future<bool> deleteEntry(String entryId) async {
    try {
      await client.from('entries').delete().eq('id', entryId);
      return true;
    } catch (e) {
      debugPrint('❌ deleteEntry error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      return await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
    } catch (e) {
      return null;
    }
  }

  Future<bool> upsertProfile(Map<String, dynamic> data) async {
    try {
      await client.from('profiles').upsert(data);
      return true;
    } catch (e) {
      return false;
    }
  }
}