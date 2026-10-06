import 'package:flutter/material.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../screens/profile/subscription_screen.dart';
import 'home_motion.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    required this.onBooksTap,
    required this.onReportsTap,
  });
  final VoidCallback onBooksTap;
  final VoidCallback onReportsTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actions = [
      (icon: Icons.auto_stories_rounded, label: 'Books', onTap: onBooksTap),
      (
        icon: Icons.insert_chart_outlined_rounded,
        label: 'Reports',
        onTap: onReportsTap,
      ),
      (
        icon: Icons.currency_exchange_rounded,
        label: 'Currency',
        onTap: () => CurrencyPickerWidget.show(context),
      ),
      (
        icon: Icons.workspace_premium_rounded,
        label: 'Premium',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
          );
        },
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth < 310 ||
                MediaQuery.textScalerOf(context).scale(12) > 16
            ? 2
            : 4;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: .45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: .05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: DepthButton(
                    onTap: action.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 17,
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SculptedIcon(icon: action.icon, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            action.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
