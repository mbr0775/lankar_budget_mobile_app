import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'home_motion.dart';

class TotalBalanceCard extends StatelessWidget {
  const TotalBalanceCard({
    super.key,
    required this.displayBalance,
    required this.symbol,
    required this.bookCount,
    this.monthIncome,
    this.monthExpense,
    this.activityLoading = false,
  });
  final double displayBalance;
  final String symbol;
  final int bookCount;
  final double? monthIncome;
  final double? monthExpense;
  final bool activityLoading;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF102E45), Color(0xFF145F8D), primaryBlue],
      ),
      border: Border.all(color: const Color(0xFF419FC5).withValues(alpha: .4)),
      boxShadow: [
        BoxShadow(
          color: primaryBlue.withValues(alpha: .23),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned(
          right: -45,
          top: -85,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .08),
                width: 38,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BalanceOverview(
                balance: displayBalance,
                symbol: symbol,
                count: bookCount,
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFF4882A4), height: 1),
              const SizedBox(height: 17),
              const Text(
                'THIS MONTH',
                style: TextStyle(
                  color: Color(0xFFC3E5F6),
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _MonthValues(
                income: monthIncome,
                expense: monthExpense,
                symbol: symbol,
                loading: activityLoading,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({
    required this.balance,
    required this.symbol,
    required this.count,
  });
  final double balance;
  final String symbol;
  final int count;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const label = Text(
        'TOTAL BALANCE',
        style: TextStyle(
          color: Color(0xFFC3E5F6),
          fontSize: 10,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      );
      final amount = Semantics(
        label: 'Total balance $symbol ${formatCurrency(balance)}',
        excludeSemantics: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '$symbol ${formatCurrency(balance)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              letterSpacing: -1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
      final caption = Text(
        'Across $count cash ${count == 1 ? 'book' : 'books'}',
        style: const TextStyle(color: Color(0xFFC3E5F6), fontSize: 12),
      );
      if (constraints.maxWidth < 260 ||
          MediaQuery.textScalerOf(context).scale(12) > 15) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(child: label),
                GrowthSculpture(size: 72),
              ],
            ),
            const SizedBox(height: 4),
            amount,
            const SizedBox(height: 10),
            caption,
          ],
        );
      }
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 12),
                amount,
                const SizedBox(height: 10),
                caption,
              ],
            ),
          ),
          const SizedBox(width: 6),
          const GrowthSculpture(size: 100),
        ],
      );
    },
  );
}

class _MonthValues extends StatelessWidget {
  const _MonthValues({
    required this.income,
    required this.expense,
    required this.symbol,
    required this.loading,
  });
  final double? income;
  final double? expense;
  final String symbol;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final moneyIn = _MonthValue(
      label: 'Money in',
      amount: income,
      symbol: symbol,
      loading: loading,
      icon: Icons.south_west_rounded,
      color: const Color(0xFF9BE5CE),
    );
    final moneyOut = _MonthValue(
      label: 'Money out',
      amount: expense,
      symbol: symbol,
      loading: loading,
      icon: Icons.north_east_rounded,
      color: const Color(0xFFD6EDFA),
    );
    if (MediaQuery.textScalerOf(context).scale(12) > 17) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [moneyIn, const SizedBox(height: 12), moneyOut],
      );
    }
    return Row(
      children: [
        Expanded(child: moneyIn),
        const SizedBox(width: 14),
        Expanded(child: moneyOut),
      ],
    );
  }
}

class _MonthValue extends StatelessWidget {
  const _MonthValue({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.icon,
    required this.color,
    required this.loading,
  });
  final String label;
  final double? amount;
  final String symbol;
  final IconData icon;
  final Color color;
  final bool loading;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFFC3E5F6), fontSize: 10),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount == null
                    ? (loading ? 'Loading...' : 'Unavailable')
                    : '$symbol ${formatCurrency(amount!)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
