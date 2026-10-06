import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'home/home_motion.dart';

const cashIncomeColor = Color(0xFF16815C);
const cashExpenseColor = Color(0xFFC34B56);

class CashBalanceCard extends StatelessWidget {
  const CashBalanceCard({
    super.key,
    required this.income,
    required this.expense,
    required this.symbol,
    required this.count,
  });
  final double income;
  final double expense;
  final String symbol;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF12364B), Color(0xFF1B647D)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .18)),
      boxShadow: [
        BoxShadow(
          color: primaryBlue.withValues(alpha: .2),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final roomy =
            constraints.maxWidth >= 270 &&
            MediaQuery.textScalerOf(context).scale(12) <= 15;
        final balance = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available balance',
              style: TextStyle(
                color: Color(0xFFC9E9F8),
                fontSize: 13,
                letterSpacing: .2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _Amount(
              value: income - expense,
              symbol: symbol,
              size: 36,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              '$count ${count == 1 ? 'entry' : 'entries'} · All time',
              style: const TextStyle(color: Color(0xFFC9E9F8), fontSize: 11),
            ),
          ],
        );
        final totals = [
          _FlowTotal(
            label: 'Total in',
            value: income,
            symbol: symbol,
            icon: Icons.south_west_rounded,
            color: const Color(0xFF91E8C6),
          ),
          _FlowTotal(
            label: 'Total out',
            value: expense,
            symbol: symbol,
            icon: Icons.north_east_rounded,
            color: const Color(0xFFFFB4BC),
          ),
        ];
        final stacked =
            constraints.maxWidth < 240 ||
            MediaQuery.textScalerOf(context).scale(12) > 17;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (roomy)
              Row(
                children: [
                  Expanded(child: balance),
                  const SizedBox(width: 6),
                  const _WalletMark(size: 54),
                ],
              )
            else ...[
              const Align(
                alignment: Alignment.centerRight,
                child: _WalletMark(size: 44),
              ),
              balance,
            ],
            const SizedBox(height: 22),
            if (stacked) ...[
              totals[0],
              const SizedBox(height: 12),
              totals[1],
            ] else
              Row(
                children: [
                  Expanded(child: totals[0]),
                  const SizedBox(width: 12),
                  Expanded(child: totals[1]),
                ],
              ),
          ],
        );
      },
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.value,
    required this.symbol,
    required this.size,
    required this.color,
  });
  final double value;
  final String symbol;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$symbol ${formatCurrency(value)}',
    excludeSemantics: true,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        '$symbol ${formatCurrency(value)}',
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
    ),
  );
}

class _FlowTotal extends StatelessWidget {
  const _FlowTotal({
    required this.label,
    required this.value,
    required this.symbol,
    required this.icon,
    required this.color,
  });
  final String label;
  final double value;
  final String symbol;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _Amount(value: value, symbol: symbol, size: 19, color: Colors.white),
      ],
    ),
  );
}

class CashActionDock extends StatelessWidget {
  const CashActionDock({
    super.key,
    required this.onIncome,
    required this.onExpense,
  });
  final VoidCallback onIncome;
  final VoidCallback onExpense;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: .1),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Action(
                      label: 'Cash in',
                      icon: Icons.add_rounded,
                      onTap: onIncome,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Action(
                      label: 'Cash out',
                      icon: Icons.remove_rounded,
                      onTap: onExpense,
                      filled: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = filled
        ? Colors.white
        : scheme.brightness == Brightness.dark
        ? const Color(0xFFFFB4BC)
        : cashExpenseColor;
    return DepthButton(
      onTap: onTap,
      radius: 16,
      color: filled ? cashIncomeColor : cashExpenseColor.withValues(alpha: .1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletMark extends StatelessWidget {
  const _WalletMark({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Icon(
        Icons.account_balance_wallet_outlined,
        color: const Color(0xFFC9E9F8),
        size: size * .45,
      ),
    ),
  );
}

class CashActivityFilters extends StatelessWidget {
  const CashActivityFilters({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final label in ['All', 'Income', 'Expense'])
            Expanded(
              child: Semantics(
                selected: selected == label,
                child: TextButton(
                  onPressed: () => onSelected(label),
                  style: TextButton.styleFrom(
                    foregroundColor: selected == label
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    backgroundColor: selected == label
                        ? scheme.surface
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
