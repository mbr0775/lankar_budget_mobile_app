// lib/widgets/book_card_widget.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BookCardWidget extends StatelessWidget {
  final Map<String, dynamic> book;
  final String currencySymbol;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool isDarkMode;

  const BookCardWidget({
    super.key,
    required this.book,
    required this.currencySymbol,
    required this.balance,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF212529);
    final subColor  = isDarkMode ? Colors.grey[400]! : const Color(0xFF6C757D);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Book icon
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [primaryRed, secondaryRed]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.book,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    // Book name + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book['name'] ?? '',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 13, color: subColor),
                              const SizedBox(width: 4),
                              Text(
                                formatDate(book['created_at'] ??
                                    DateTime.now().toIso8601String()),
                                style: TextStyle(
                                    color: subColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Popup menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(children: [
                            Icon(Icons.edit,
                                color: primaryRed, size: 18),
                            SizedBox(width: 10),
                            Text('Rename'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete,
                                color: Colors.red, size: 18),
                            SizedBox(width: 10),
                            Text('Delete'),
                          ]),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'rename') onRename();
                        if (val == 'delete') onDelete();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Balance row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: balance >= 0
                        ? incomeGreen.withOpacity(0.08)
                        : expenseRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Balance',
                        style: TextStyle(
                          color: subColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$currencySymbol ${formatCurrency(balance)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? incomeGreen : expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}