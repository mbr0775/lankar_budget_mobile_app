// lib/widgets/entry_card_widget.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class EntryCardWidget extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String currencySymbol;
  final double displayAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.currencySymbol,
    required this.displayAmount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome  = entry['is_income'] as bool;
    final dateField = entry['entry_date'] ?? entry['created_at'];
    final relative  = getRelativeDate(dateField);
    final formatted = getFormattedDate(dateField);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isIncome
                      ? [incomeGreen, incomeGreen.withOpacity(0.7)]
                      : [primaryRed, secondaryRed],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Description + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['description'] ?? 'No description',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          relative ?? formatted,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.access_time,
                          size: 11, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        formatTime(dateField),
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Amount + actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currencySymbol ${formatCurrency(displayAmount)}',
                  style: TextStyle(
                    color: isIncome ? incomeGreen : expenseRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.blue, size: 19),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          color: Colors.red, size: 19),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}