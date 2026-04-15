// lib/widgets/home/home_book_tile.dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class HomeBookTile extends StatelessWidget {
  final Map<String, dynamic> book;
  final String symbol;
  final double balance;
  final VoidCallback onTap;

  const HomeBookTile({
    super.key,
    required this.book,
    required this.symbol,
    required this.balance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [primaryRed, secondaryRed]),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.book, color: Colors.white, size: 20),
        ),
        title: Text(
          book['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          formatDate(book['created_at'] as String? ??
              DateTime.now().toIso8601String()),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Text(
          '$symbol ${formatCurrency(balance)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: balance >= 0 ? incomeGreen : expenseRed,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}