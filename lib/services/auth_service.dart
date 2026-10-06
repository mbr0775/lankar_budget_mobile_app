import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_errors.dart';
import '../utils/constants.dart';

enum AuthNotice {
  signedIn,
  signedUp,
  confirmEmail,
  signedOut,
  passwordReset,
  passwordUpdated,
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  final _notices = StreamController<AuthNotice>.broadcast();
  Stream<AuthNotice> get notices => _notices.stream;
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
      data: fullName == null ? null : {'full_name': fullName},
    );
    if (response.user == null) {
      throw const AppFailure(
        'Could not create your account',
        'Please try again in a moment.',
      );
    }
    _notices.add(
      response.session == null ? AuthNotice.confirmEmail : AuthNotice.signedUp,
    );
    // A profile write requires a session. Confirmation-only signups keep the
    // name in auth metadata until their first authenticated session.
    if (response.session != null && fullName != null) {
      await _cacheProfile({
        'id': response.user!.id,
        'full_name': fullName,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) {
      throw const AppFailure(
        'Could not sign in',
        'Please try again in a moment.',
      );
    }
    _notices.add(AuthNotice.signedIn);
    return response;
  }

  Future<void> signOut({bool notify = true}) async {
    // Authentication failures propagate. A Google cache failure must not turn
    // an already completed Supabase sign-out into a failed sign-out.
    await _client.auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (error, stack) {
      AppErrors.report('Clear Google account cache', error, stack);
    }
    if (notify) _notices.add(AuthNotice.signedOut);
  }

  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: SupabaseConfig.passwordResetRedirectUrl,
    );
    _notices.add(AuthNotice.passwordReset);
  }

  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
    );
    _notices.add(AuthNotice.confirmEmail);
  }

  Future<UserResponse> updatePassword(String password) async {
    final response = await _client.auth.updateUser(
      UserAttributes(password: password),
    );
    if (response.user == null) throw AppErrors.session;
    _notices.add(AuthNotice.passwordUpdated);
    return response;
  }

  /// Returns false when the account chooser is cancelled, without a success notice.
  Future<bool> signInWithGoogle() async {
    const webClientId =
        '432227685688-rvrtlvdpl616p390clj1k5hlo7p0mnh3.apps.googleusercontent.com';
    final googleSignIn = GoogleSignIn(serverClientId: webClientId);
    await googleSignIn.signOut();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return false;
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw const AppFailure(
        'Google sign-in unavailable',
        'Try again, or sign in with your email and password.',
      );
    }
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
    if (response.session == null || response.user == null) {
      throw const AppFailure(
        'Could not sign in with Google',
        'Please try again.',
      );
    }
    _notices.add(AuthNotice.signedIn);
    await _cacheProfile({
      'id': response.user!.id,
      'full_name': googleUser.displayName,
      'avatar_url': googleUser.photoUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<void> _cacheProfile(Map<String, dynamic> profile) async {
    try {
      await _client
          .from('profiles')
          .upsert(profile)
          .timeout(const Duration(seconds: 8));
    } catch (error, stack) {
      // Optional profile enrichment must not report an established session as
      // a failed login (or encourage a second signup).
      AppErrors.report('Save optional profile', error, stack);
    }
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    final uid = currentUser?.id;
    if (uid == null) throw AppErrors.session;
    final updates = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    if (updates.isNotEmpty) {
      await _client.from('profiles').upsert({'id': uid, ...updates});
    }
  }
}
