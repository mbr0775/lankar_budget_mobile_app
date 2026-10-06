import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum FailureKind {
  network,
  authentication,
  validation,
  storage,
  cancelled,
  unknown,
}

/// Safe user-facing errors; backend messages and account details stay out of UI.
class AppFailure implements Exception {
  const AppFailure(this.title, this.message, {this.kind = FailureKind.unknown});
  final String title;
  final String message;
  final FailureKind kind;
  @override
  String toString() => message;
}

class AppErrors {
  static const network = AppFailure(
    'Connection problem',
    'Check your connection and try again.',
    kind: FailureKind.network,
  );
  static const session = AppFailure(
    'Please sign in again',
    'Your session has expired. Sign in to continue.',
    kind: FailureKind.authentication,
  );

  static AppFailure from(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is AppFailure) return error;
    if (error is AuthUnknownException) {
      return from(error.originalError, fallback: fallback);
    }
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException ||
        error is AuthRetryableFetchException) {
      return network;
    }
    if (error is AuthSessionMissingException) return session;
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return const AppFailure(
            'Could not sign in',
            'Check your email and password, then try again.',
            kind: FailureKind.authentication,
          );
        case 'email_not_confirmed':
          return const AppFailure(
            'Confirm your email',
            'Open the confirmation link in your email before signing in.',
            kind: FailureKind.authentication,
          );
        case 'user_already_exists':
        case 'email_exists':
          return const AppFailure(
            'Try signing in',
            'An account may already use this email. Sign in or reset your password.',
            kind: FailureKind.validation,
          );
        case 'weak_password':
          return const AppFailure(
            'Choose a stronger password',
            'Use a longer password with letters, numbers, and symbols.',
            kind: FailureKind.validation,
          );
        case 'same_password':
          return const AppFailure(
            'Choose a new password',
            'Your new password must differ from your current password.',
            kind: FailureKind.validation,
          );
        case 'otp_expired':
          return const AppFailure(
            'Link expired',
            'Request a new confirmation or password-reset email and open its newest link.',
            kind: FailureKind.authentication,
          );
        case 'refresh_token_not_found':
        case 'refresh_token_already_used':
        case 'session_not_found':
          return session;
      }
      if (error.statusCode == '429' ||
          error.code?.startsWith('over_') == true) {
        return const AppFailure(
          'Please wait a moment',
          'Too many attempts. Wait a few minutes before trying again.',
        );
      }
      if (error.statusCode == '401' || error.statusCode == '403') {
        return session;
      }
      if ((int.tryParse(error.statusCode ?? '') ?? 0) >= 500) return network;
    }
    if (error is PostgrestException) {
      if (error.code == '42501' ||
          error.code == 'PGRST301' ||
          error.code == 'PGRST302') {
        return const AppFailure(
          'Unable to access this item',
          'Sign in again and make sure this cash book belongs to you.',
          kind: FailureKind.authentication,
        );
      }
      if (error.code == '23505') {
        return const AppFailure(
          'Item already exists',
          'Refresh the list before trying again.',
          kind: FailureKind.validation,
        );
      }
      if (error.code == '23503' || error.code == 'PGRST116') {
        return const AppFailure(
          'Item no longer available',
          'Refresh your cash books and try again.',
          kind: FailureKind.validation,
        );
      }
    }
    if (error is PlatformException) {
      if ([
        'sign_in_canceled',
        'sign_in_cancelled',
        'canceled',
      ].contains(error.code)) {
        return const AppFailure('', '', kind: FailureKind.cancelled);
      }
      if (error.code == 'network_error') return network;
      if (error.code == 'sign_in_failed') {
        return const AppFailure(
          'Google sign-in unavailable',
          'Try again, or sign in with your email and password.',
        );
      }
    }
    if (error is HiveError || error is FileSystemException) {
      return const AppFailure(
        'Could not save on this device',
        'Check available storage and try again.',
        kind: FailureKind.storage,
      );
    }
    return AppFailure('Could not complete this action', fallback);
  }

  /// Only connection failures qualify for the existing offline-save path.
  static bool canSaveOffline(Object error) =>
      from(error).kind == FailureKind.network;

  static void report(String operation, Object error, StackTrace stack) {
    // Do not log raw exceptions: they may contain emails, tokens, or entry data.
    final code = error is AuthException
        ? error.code
        : error is PostgrestException
        ? error.code
        : null;
    debugPrint(
      '$operation failed (${error.runtimeType}${code == null ? '' : ', code=$code'})',
    );
    if (kDebugMode) debugPrintStack(stackTrace: stack, maxFrames: 5);
  }
}
