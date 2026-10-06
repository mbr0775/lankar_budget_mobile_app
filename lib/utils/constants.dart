// lib/utils/constants.dart

import 'package:flutter/material.dart';

// ── Brand Colors ──────────────────────────────────────────────

const Color primaryBlue = Color(0xFF1673A5);
const Color secondaryBlue = Color(0xFF249BD1);
const Color brandNavy = Color(0xFF102E45);
const Color brandMist = Color(0xFFF2F8FC);
const Color incomeGreen = Color(0xFF28A745);
const Color expenseRed = Color(0xFFDC3545);
const Color navDark = brandNavy;
const Color accentYellow = Color(0xFFFFC107);

// ── Currency ──────────────────────────────────────────────────

// ISO 4217 codes intentionally match their familiar uppercase labels.
// ignore: constant_identifier_names
enum Currency { LKR, USD, QAR }

const Map<Currency, String> currencySymbols = {
  Currency.LKR: 'Rs',

  Currency.USD: '\$',

  Currency.QAR: 'QR',
};

const Map<Currency, double> exchangeRates = {
  Currency.USD: 1.0,

  Currency.LKR: 0.003281,

  Currency.QAR: 0.2743,
};

// ── Route Names ───────────────────────────────────────────────

class AppRoutes {
  // Splash must have its own route
  static const splash = '/splash';

  static const onboarding = '/onboarding';

  static const login = '/login';

  static const signup = '/signup';
  static const confirmEmail = '/confirm-email';
  static const authLinkError = '/auth-link-error';
  static const authLinkOpening = '/auth-link-opening';

  static const forgotPass = '/forgot-password';

  static const updatePassword = '/update-password';

  static const home = '/home';

  static const bookDetail = '/book/:bookId';

  static const reports = '/reports';

  static const profile = '/profile';

  static const settings = '/settings';

  static const subscription = '/subscription';
}

// ── Shared Prefs Keys ─────────────────────────────────────────

class PrefKeys {
  static const seenOnboarding = 'seen_onboarding';

  static const selectedCurrency = 'selected_currency';

  static const isDarkMode = 'is_dark_mode';
}

// ── Supabase ──────────────────────────────────────────────────

class SupabaseConfig {
  static const authRedirectUrl = 'io.supabase.flutter://login-callback';
  static const passwordResetRedirectUrl = 'io.supabase.flutter://reset-callback';

  static const url = 'https://wnmrzrxagwpyyayalrnn.supabase.co';

  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndubXJ6cnhhZ3dweXlheWFscm5uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMzMxMjcsImV4cCI6MjA3NzYwOTEyN30.0XRLCk9iIVcaOZ_JFJT63_NPHhom9hPmQ7pwgq4KQe0';
}
