// lib/providers/auth_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/hybrid_storage_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data:    (state) => state.session?.user,
    loading: ()      => AuthService().currentUser,
    error:   (_, __) => null,
  );
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Resolves the display name from all possible Supabase metadata locations.
/// Supabase stores name in different places depending on auth method.
final userDisplayNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 'there';

  // 1. userMetadata['full_name'] — set during email signup / Google OAuth
  final meta = user.userMetadata;
  if (meta != null) {
    final fullName = meta['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    // 2. userMetadata['name'] — some OAuth providers use this key
    final name = meta['name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim().split(' ').first;
    }
  }

  // 3. Fall back to email prefix
  final email = user.email ?? '';
  if (email.isNotEmpty) return email.split('@').first;

  return 'there';
});

/// Full display name (not just first name) for profile screen
final userFullNameProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 'User';

  final meta = user.userMetadata;
  if (meta != null) {
    final fullName = meta['full_name'] as String?;
    if (fullName != null && fullName.trim().isNotEmpty) return fullName.trim();
    final name = meta['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
  }

  return user.email?.split('@').first ?? 'User';
});

// ── Auth Actions ──────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  final AuthService _authService;

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signIn(email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> signUp(String email, String password, {String? name}) async {
    state = const AsyncValue.loading();
    try {
      await _authService.signUp(
          email: email, password: password, fullName: name);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authService.signInWithGoogle();
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await HybridStorageService().clearAllData();
  }

  Future<void> resetPassword(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authService.resetPassword(email);
      state = const AsyncValue.data(null);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(ref.watch(authServiceProvider)),
);