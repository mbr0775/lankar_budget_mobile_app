import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import 'home/home_motion.dart';

class BookCardWidget extends StatelessWidget {
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
  final Map<String, dynamic> book;
  final String currencySymbol;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool isDarkMode;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = book['name'] as String? ?? 'Cash book';
    final date = DateTime.tryParse(book['created_at'] as String? ?? '');
    final pending = book['synced'] == false;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .05),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: DepthButton(
        radius: 26,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: SculptedIcon(
                      icon: Icons.auto_stories_rounded,
                      size: 44,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          date == null
                              ? 'Cash book'
                              : 'Created ${formatDate(date.toIso8601String())}',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Manage $name',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(
                              Icons.drive_file_rename_outline_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 10),
                            const Text('Rename'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: scheme.error,
                            ),
                            const SizedBox(width: 10),
                            const Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'rename') {
                        onRename();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'BOOK BALANCE',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Semantics(
                label: 'Balance $currencySymbol ${formatCurrency(balance)}',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$currencySymbol ${formatCurrency(balance)}',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.7,
                      color: balance < 0 ? scheme.error : scheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: .45),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    pending
                        ? Icons.cloud_upload_outlined
                        : Icons.auto_stories_outlined,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      pending ? 'Saved on device' : 'View entries',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.primary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
