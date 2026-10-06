import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_errors.dart';
import '../utils/constants.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();
  late SupabaseClient client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    assignClient();
  }

  void assignClient() {
    client = Supabase.instance.client;
  }

  String? get currentUserId => client.auth.currentUser?.id;
  bool get isAuthenticated => currentUserId != null;
  void _requireSession() {
    if (!isAuthenticated) throw AppErrors.session;
  }

  // Errors propagate so callers can distinguish connection failures from a
  // rejected write. select().single() also detects missing/forbidden rows.
  Future<Map<String, dynamic>?> createBook(
    String name,
    String userId,
    double balance,
    String createdAt,
  ) async {
    _requireSession();
    return await client
        .from('books')
        .insert({
          'name': name,
          'user_id': currentUserId,
          'balance': balance,
          'created_at': createdAt,
        })
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> getBooks(String userId) async =>
      await client
          .from('books')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

  Future<bool> updateBookBalance(String bookId, double balance) async {
    _requireSession();
    await client
        .from('books')
        .update({'balance': balance})
        .eq('id', bookId)
        .select('id')
        .single();
    return true;
  }

  Future<bool> updateBookName(String bookId, String newName) async {
    _requireSession();
    await client
        .from('books')
        .update({'name': newName})
        .eq('id', bookId)
        .select('id')
        .single();
    return true;
  }

  Future<bool> deleteBook(String bookId) async {
    _requireSession();
    await client.from('books').delete().eq('id', bookId).select('id').single();
    return true;
  }

  Future<Map<String, dynamic>?> createEntry({
    required String bookId,
    required double amount,
    required String description,
    required bool isIncome,
    DateTime? entryDate,
  }) async {
    _requireSession();
    return await client
        .from('entries')
        .insert({
          'book_id': bookId,
          'amount': amount,
          'description': description,
          'is_income': isIncome,
          'entry_date': (entryDate ?? DateTime.now()).toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
  }

  Future<List<Map<String, dynamic>>> getEntries(String bookId) async =>
      await client
          .from('entries')
          .select()
          .eq('book_id', bookId)
          .order('entry_date', ascending: false);

  Future<bool> updateEntry(
    String entryId, {
    double? amount,
    String? description,
  }) async {
    _requireSession();
    final updates = <String, dynamic>{
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
    };
    if (updates.isEmpty) return true;
    await client
        .from('entries')
        .update(updates)
        .eq('id', entryId)
        .select('id')
        .single();
    return true;
  }

  Future<bool> deleteEntry(String entryId) async {
    _requireSession();
    await client
        .from('entries')
        .delete()
        .eq('id', entryId)
        .select('id')
        .single();
    return true;
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async =>
      await client.from('profiles').select().eq('id', userId).maybeSingle();

  Future<bool> upsertProfile(Map<String, dynamic> data) async {
    _requireSession();
    await client.from('profiles').upsert(data);
    return true;
  }
}
