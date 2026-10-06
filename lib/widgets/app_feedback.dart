import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_errors.dart';

enum FeedbackTone { success, error, info, warning }

class AppFeedback {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String title, String message) =>
      show(context, title, message, FeedbackTone.success);
  static void info(BuildContext context, String title, String message) =>
      show(context, title, message, FeedbackTone.info);
  static void warning(BuildContext context, String title, String message) =>
      show(context, title, message, FeedbackTone.warning);
  static void error(
    BuildContext context,
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final failure = AppErrors.from(error, fallback: fallback);
    if (failure.kind != FailureKind.cancelled) {
      show(context, failure.title, failure.message, FeedbackTone.error);
    }
  }

  static void show(
    BuildContext context,
    String title,
    String message,
    FeedbackTone tone,
  ) {
    if (!context.mounted) return;
    final messenger =
        messengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);
    if (messenger != null) _display(messenger, title, message, tone);
  }

  static void global(String title, String message, FeedbackTone tone) {
    // Authentication can replace routes before the awaiting screen resumes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = messengerKey.currentState;
      if (messenger != null && messenger.mounted) {
        _display(messenger, title, message, tone);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static void globalError(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final failure = AppErrors.from(error, fallback: fallback);
    if (failure.kind != FailureKind.cancelled) {
      global(failure.title, failure.message, FeedbackTone.error);
    }
  }

  static void _display(
    ScaffoldMessengerState messenger,
    String title,
    String message,
    FeedbackTone tone,
  ) {
    final width = math.min(
      520.0,
      MediaQuery.sizeOf(messenger.context).width - 32,
    );
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: width,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        duration: Duration(
          seconds: tone == FeedbackTone.error || tone == FeedbackTone.warning
              ? 7
              : 4,
        ),
        dismissDirection: DismissDirection.horizontal,
        content: FeedbackCard(
          title: title,
          message: message,
          tone: tone,
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }
}

class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.title,
    required this.message,
    required this.tone,
    required this.onDismiss,
  });
  final String title;
  final String message;
  final FeedbackTone tone;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final color = switch (tone) {
      FeedbackTone.success =>
        dark ? const Color(0xFF7DDCB6) : const Color(0xFF16815C),
      FeedbackTone.error => scheme.error,
      FeedbackTone.info => scheme.primary,
      FeedbackTone.warning =>
        dark ? const Color(0xFFFFD18B) : const Color(0xFF9B6109),
    };
    final icon = switch (tone) {
      FeedbackTone.success => Icons.check_circle_outline_rounded,
      FeedbackTone.error => Icons.error_outline_rounded,
      FeedbackTone.info => Icons.info_outline_rounded,
      FeedbackTone.warning => Icons.cloud_off_rounded,
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .2 : .08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss message',
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatefulWidget {
  const AppErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;
  @override
  State<AppErrorView> createState() => _AppErrorViewState();
}

class _AppErrorViewState extends State<AppErrorView> {
  bool _retrying = false;
  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (error, stack) {
      AppErrors.report('Reload data', error, stack);
      if (mounted) AppFeedback.error(context, error);
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = AppErrors.from(
      widget.error,
      fallback: 'Your data could not be loaded. Try refreshing.',
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                failure.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(failure.message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_retrying ? 'Refreshing…' : 'Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One app-level subscription avoids duplicate messages from auth routes.
class AuthFeedbackListener extends StatefulWidget {
  const AuthFeedbackListener({super.key, required this.child});
  final Widget child;
  @override
  State<AuthFeedbackListener> createState() => _AuthFeedbackListenerState();
}

class _AuthFeedbackListenerState extends State<AuthFeedbackListener> {
  late final StreamSubscription<AuthNotice> _subscription;
  @override
  void initState() {
    super.initState();
    _subscription = AuthService().notices.listen((notice) {
      final (title, message) = switch (notice) {
        AuthNotice.signedIn => (
          'Welcome back',
          'You’re signed in. Let’s make every rupee count.',
        ),
        AuthNotice.signedUp => (
          'You’re all set',
          'Your account is ready. Create your first cash book.',
        ),
        AuthNotice.confirmEmail => (
          'Check your email',
          'Open the confirmation link, then sign in to Lankar.',
        ),
        AuthNotice.signedOut => (
          'Signed out',
          'You’ve safely signed out of Lankar.',
        ),
        AuthNotice.passwordReset => (
          'Reset link sent',
          'If an account uses this email, you’ll receive a password-reset link.',
        ),
        AuthNotice.passwordUpdated => (
          'Password updated',
          'Your new password is ready to use.',
        ),
      };
      AppFeedback.global(title, message, FeedbackTone.success);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
