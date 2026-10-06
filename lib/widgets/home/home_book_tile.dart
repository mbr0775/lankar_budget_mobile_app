import 'package:flutter/material.dart';
import '../../utils/helpers.dart';
import 'home_motion.dart';

class HomeBookTile extends StatelessWidget {
  const HomeBookTile({
    super.key,
    required this.book,
    required this.symbol,
    required this.balance,
    required this.onTap,
  });
  final Map<String, dynamic> book;
  final String symbol;
  final double balance;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: .45),
          ),
        ),
        child: DepthButton(
          radius: 24,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const SculptedIcon(icon: Icons.auto_stories_rounded, size: 42),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['name'] as String? ?? 'Cash book',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatDate(
                          book['created_at'] as String? ??
                              DateTime.now().toIso8601String(),
                        ),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '$symbol ${formatCurrency(balance)}',
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: -.4,
                          fontWeight: FontWeight.w800,
                          color: balance < 0 ? scheme.error : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
