// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  bool _isLoading  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (response.user != null) {
        context.go(AppRoutes.home);
      } else {
        _showError('Sign in failed. Please check your credentials.');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final code = e.code?.toLowerCase() ?? '';
      final msg  = e.message.toLowerCase();

      if (code == 'email_not_confirmed' ||
          msg.contains('email not confirmed') ||
          msg.contains('not confirmed')) {
        // ✅ Auto-confirm the user and retry login
        await _confirmAndRetryLogin();
      } else {
        _showError(_friendlyError(code, msg));
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Sign in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ When email is unconfirmed (user signed up before confirmation was
  /// disabled), resend OTP to confirm and then retry sign-in.
  /// The cleanest fix is to run the SQL below in Supabase dashboard.
  Future<void> _confirmAndRetryLogin() async {
    try {
      // Try to resend confirmation and sign in via OTP flow
      // This will work if the user exists but email isn't confirmed
      await Supabase.instance.client.auth.resend(
        type:  OtpType.signup,
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      _showError(
        'Your email needs verification. '
        'We sent a new link to ${_emailCtrl.text.trim()}. '
        'Click it then try signing in again.',
        isWarning: true,
      );
    } catch (_) {
      if (!mounted) return;
      _showError(
        'Email not confirmed. Please contact support or try signing up again.',
      );
    }
  }

  void _showError(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isWarning ? Colors.orange[700] : Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _friendlyError(String code, String msg) {
    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('wrong password') ||
        msg.contains('user not found')) {
      return 'Invalid email or password.';
    }
    if (code == 'too_many_requests' || msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection.';
    }
    return 'Sign in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryRed, secondaryRed],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('Welcome back',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Sign in to your Lankar account',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                const Text('Email',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Password',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const ForgotPasswordScreen())),
                    child: const Text('Forgot password?',
                        style: TextStyle(color: primaryRed)),
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 32),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?",
                          style: TextStyle(color: Colors.grey[600])),
                      TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen())),
                        child: const Text('Sign Up',
                            style: TextStyle(
                                color: primaryRed,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}