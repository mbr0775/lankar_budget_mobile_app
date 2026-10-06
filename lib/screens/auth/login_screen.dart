import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../utils/constants.dart';
import '../../utils/app_errors.dart';
import '../../widgets/app_feedback.dart';
import '../../utils/validators.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_design.dart';
import '../../widgets/google_auth_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final response = await AuthService().signIn(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      if (response.session != null) {
        TextInput.finishAutofillContext();
        context.go(AppRoutes.home);
      } else {
        _showError('Sign in failed. Please try again.');
      }
    } catch (error, stack) {
      AppErrors.report('Authenticate', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Unable to sign in. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithGoogle();
      if (mounted && AuthService().currentSession != null) {
        context.go(AppRoutes.home);
      }
    } catch (error, stack) {
      AppErrors.report('Google sign-in', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Could not sign in with Google. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppFeedback.error(context, AppFailure('Please try again', message));
  }

  @override
  Widget build(BuildContext context) => AuthPageLayout(
    title: 'Good to see you again.',
    subtitle: 'Your money, your plans. Pick up where you left off.',
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              label: 'Email address',
              controller: _emailCtrl,
              icon: Icons.alternate_email_rounded,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            AuthField(
              label: 'Password',
              controller: _passCtrl,
              icon: Icons.lock_outline_rounded,
              validator: Validators.password,
              obscure: _obscure,
              toggleObscure: () => setState(() => _obscure = !_obscure),
              autofillHints: const [AutofillHints.password],
              last: true,
              onSubmitted: (_) => _signIn(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => context.push(AppRoutes.forgotPass),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => context.push(
                      AppRoutes.confirmEmail,
                      extra: _emailCtrl.text.trim(),
                    ),
              child: const Text('Resend confirmation email'),
            ),
            AuthSubmitButton(
              label: 'Sign in',
              loading: _isLoading,
              onPressed: _signIn,
            ),
            const AuthDivider(),
            GoogleAuthButton(onPressed: _isLoading ? null : _signInWithGoogle),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'New to Lankar?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.push(AppRoutes.signup),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
