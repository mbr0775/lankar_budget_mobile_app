import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/auth_design.dart';

class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({super.key, this.email = ''});
  final String email;

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  bool _sending = false;

  Future<void> _resend() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await AuthService().resendConfirmation(_email.text);
    } catch (error) {
      if (mounted) {
        AppFeedback.error(
          context,
          error,
          fallback: 'Could not send a confirmation email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthPageLayout(
    title: 'Confirm your email.',
    subtitle:
        'Check your inbox and spam folder. Open the newest confirmation link on this device, using the same Lankar installation. If it has expired, request another below.',
    backAction: () => context.go(AppRoutes.login),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Email address',
            controller: _email,
            icon: Icons.alternate_email_rounded,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
          ),
          AuthSubmitButton(
            label: 'Resend confirmation email',
            loading: _sending,
            onPressed: _resend,
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    ),
  );
}

class AuthLinkErrorScreen extends StatelessWidget {
  const AuthLinkErrorScreen({super.key});

  @override
  Widget build(BuildContext context) => AuthPageLayout(
    title: 'This link could not be opened.',
    subtitle:
        'It may have expired, already been used, or been requested on another installation. Check your connection, then request a fresh email and open its newest link on this device.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: () => context.go(AppRoutes.forgotPass),
          child: const Text('Request a password reset'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.confirmEmail),
          child: const Text('Resend confirmation email'),
        ),
        TextButton(
          onPressed: () => context.go(AppRoutes.login),
          child: const Text('Back to sign in'),
        ),
      ],
    ),
  );
}
