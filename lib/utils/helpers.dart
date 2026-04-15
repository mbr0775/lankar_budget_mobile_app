// lib/utils/helpers.dart
import 'dart:async';
import 'package:intl/intl.dart';

void unawaited(Future<void> future) {
  future.catchError((error) => print('Unawaited error: $error'));
}

String formatCurrency(double amount) {
  final formatter = NumberFormat('#,##0.00', 'en_US');
  return formatter.format(amount);
}

String formatCurrencyCompact(double amount) {
  if (amount.abs() >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount.abs() >= 1000)    return '${(amount / 1000).toStringAsFixed(1)}K';
  return amount.toStringAsFixed(0);
}

String? getRelativeDate(String dateString) {
  final entryDate  = DateTime.parse(dateString);
  final today      = DateTime.now();
  final todayDate  = DateTime(today.year, today.month, today.day);
  final entryOnly  = DateTime(entryDate.year, entryDate.month, entryDate.day);
  final diff       = todayDate.difference(entryOnly).inDays;

  if (diff ==  0) return 'Today';
  if (diff ==  1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  return null;
}

String getFormattedDate(String dateString) {
  final d = DateTime.parse(dateString);
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String formatTime(String dateString) {
  final d = DateTime.parse(dateString);
  return '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

String formatDate(String dateString) {
  final date = DateTime.parse(dateString);
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7)  return '${diff.inDays} days ago';
  return '${date.day}/${date.month}/${date.year}';
}