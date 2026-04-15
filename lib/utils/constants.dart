// lib/utils/constants.dart
import 'package:flutter/material.dart';

// ── Brand Colors ──────────────────────────────────────────────
const Color primaryRed    = Color(0xFF9E090F);
const Color secondaryRed  = Color(0xFFD01419);
const Color incomeGreen   = Color(0xFF28A745);
const Color expenseRed    = Color(0xFFDC3545);
const Color navDark       = Color(0xFF2D1B3D);
const Color accentYellow  = Color(0xFFFFC107);

// ── Currency ──────────────────────────────────────────────────
enum Currency { LKR, USD, QAR }

const Map<Currency, String> currencySymbols = {
  Currency.LKR: 'Rs',
  Currency.USD: '\$',
  Currency.QAR: 'QR',
};

// Base currency is USD internally. Rates = how many USD per 1 unit of currency.
const Map<Currency, double> exchangeRates = {
  Currency.USD: 1.0,
  Currency.LKR: 0.003281,
  Currency.QAR: 0.2743,
};

// ── Route Names ───────────────────────────────────────────────
class AppRoutes {
  static const splash       = '/';
  static const onboarding   = '/onboarding';
  static const login        = '/login';
  static const signup       = '/signup';
  static const forgotPass   = '/forgot-password';
  static const home         = '/home';
  static const bookDetail   = '/book/:bookId';
  static const reports      = '/reports';
  static const profile      = '/profile';
  static const settings     = '/settings';
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
  static const url    = 'https://wnmrzrxagwpyyayalrnn.supabase.co';
  static const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndubXJ6cnhhZ3dweXlheWFscm5uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIwMzMxMjcsImV4cCI6MjA3NzYwOTEyN30.0XRLCk9iIVcaOZ_JFJT63_NPHhom9hPmQ7pwgq4KQe0';
}