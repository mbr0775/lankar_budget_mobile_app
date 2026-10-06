import 'package:flutter/material.dart';
import '../utils/helpers.dart';
import 'cash_book_design.dart';

class EntryCardWidget extends StatelessWidget {
  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.currencySymbol,
    required this.displayAmount,
    required this.onEdit,
    required this.onDelete,
  });
  final Map<String, dynamic> entry;
  final String currencySymbol;
  final double displayAmount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final income = entry['is_income'] == true;
    final color = income
        ? (dark ? const Color(0xFF7DDCB6) : cashIncomeColor)
        : (dark ? const Color(0xFFFFB4BC) : cashExpenseColor);
    final raw = (entry['entry_date'] ?? entry['created_at']) as String? ?? '';
    final date = DateTime.tryParse(raw)?.toLocal();
    final description = (entry['description'] as String? ?? '').trim();
    final name = description.isEmpty
        ? (income ? 'Cash in' : 'Cash out')
        : description;
    final pending = entry['synced'] == false;
    final amount = Semantics(
      label:
          '${income ? 'Income' : 'Expense'} $currencySymbol ${formatCurrency(displayAmount)}',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          '${income ? '+' : '-'} $currencySymbol ${formatCurrency(displayAmount)}',
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          date == null
              ? 'Date unavailable'
              : formatTime(date.toIso8601String()),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
        if (pending) ...[
          const SizedBox(height: 6),
          Text(
            'Saved on device',
            style: TextStyle(color: scheme.primary, fontSize: 11),
          ),
        ],
      ],
    );
    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        income ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: color,
        size: 21,
      ),
    );
    final menu = PopupMenuButton<String>(
      tooltip: 'Manage entry ${entry['id']}',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: scheme.onSurfaceVariant,
        size: 21,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit entry')),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete entry', style: TextStyle(color: scheme.error)),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .35)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(12) > 15;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(child: icon),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          Expanded(child: amount),
                        ],
                        menu,
                      ],
                    ),
                    if (compact)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 54,
                          top: 12,
                          right: 10,
                        ),
                        child: amount,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
