// lib/providers/settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final currencyIndex = prefs.getInt(PrefKeys.selectedCurrency) ?? 2; // QAR default
    final isDark        = prefs.getBool(PrefKeys.isDarkMode) ?? false;
    state = SettingsState(
      currency:   Currency.values[currencyIndex],
      isDarkMode: isDark,
    );
  }

  Future<void> setCurrency(Currency currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefKeys.selectedCurrency, Currency.values.indexOf(currency));
    state = state.copyWith(currency: currency);
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.isDarkMode, value);
    state = state.copyWith(isDarkMode: value);
  }
}

class SettingsState {
  final Currency currency;
  final bool isDarkMode;

  const SettingsState({
    this.currency   = Currency.QAR,
    this.isDarkMode = false,
  });

  SettingsState copyWith({Currency? currency, bool? isDarkMode}) => SettingsState(
        currency:   currency   ?? this.currency,
        isDarkMode: isDarkMode ?? this.isDarkMode,
      );

  String get currencySymbol => currencySymbols[currency]!;
  double get exchangeRate   => exchangeRates[currency]!;
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);