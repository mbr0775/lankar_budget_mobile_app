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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _signUp() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final response = await AuthService().signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
      );
      if (!mounted) return;
      if (response.user == null) {
        _showError('Could not create your account. Please try again.');
        return;
      }
      TextInput.finishAutofillContext();
      if (response.session != null) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.confirmEmail, extra: _emailCtrl.text.trim());
      }
    } catch (error, stack) {
      AppErrors.report('Create account', error, stack);
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Unable to create your account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
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
    title: 'A fresh start for\nyour finances.',
    subtitle: 'Create your account. Make every rupee count.',
    backAction: _isLoading ? null : _backToLogin,
    child: AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              label: 'Full name',
              controller: _nameCtrl,
              icon: Icons.person_outline_rounded,
              validator: Validators.name,
              keyboardType: TextInputType.name,
              autofillHints: const [AutofillHints.name],
            ),
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
              obscure: _obscurePass,
              toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
              autofillHints: const [AutofillHints.newPassword],
            ),
            AuthField(
              label: 'Confirm password',
              controller: _confirmCtrl,
              icon: Icons.lock_outline_rounded,
              validator: (value) =>
                  Validators.confirmPassword(value, _passCtrl.text),
              obscure: _obscureConfirm,
              toggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              last: true,
              onSubmitted: (_) => _signUp(),
            ),
            const SizedBox(height: 8),
            AuthSubmitButton(
              label: 'Create account',
              loading: _isLoading,
              onPressed: _signUp,
            ),
            const AuthDivider(),
            GoogleAuthButton(onPressed: _isLoading ? null : _signUpWithGoogle),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _backToLogin,
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
