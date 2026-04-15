// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _client = Supabase.instance.client;

  // ── Session ───────────────────────────────────────────────────
  Session? get currentSession => _client.auth.currentSession;
  User?    get currentUser    => _client.auth.currentUser;
  bool     get isLoggedIn     => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Email Auth ────────────────────────────────────────────────
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: fullName != null ? {'full_name': fullName} : null,
    );
    if (res.user != null && fullName != null) {
      try {
        await _client.from('profiles').upsert({
          'id':         res.user!.id,
          'full_name':  fullName,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    return res;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) =>
      _client.auth.resetPasswordForEmail(email);

  // ── Google OAuth ──────────────────────────────────────────────
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      const webClientId =
          'YOUR_GOOGLE_WEB_CLIENT_ID'; // Replace in production
      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      final googleUser   = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken    = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google idToken is null');

      final res = await _client.auth.signInWithIdToken(
        provider:     OAuthProvider.google,
        idToken:      idToken,
        accessToken:  accessToken,
      );

      if (res.user != null) {
        try {
          await _client.from('profiles').upsert({
            'id':         res.user!.id,
            'full_name':  googleUser.displayName,
            'avatar_url': googleUser.photoUrl,
            'created_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
      return res;
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  // ── Profile ───────────────────────────────────────────────────
  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (fullName  != null) updates['full_name']  = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await _client.from('profiles').upsert({'id': uid, ...updates});
    }
  }
}