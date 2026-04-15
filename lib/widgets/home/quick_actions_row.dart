// lib/widgets/home/quick_actions_row.dart
import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/currency_picker_widget.dart';
import '../../screens/profile/subscription_screen.dart';

class QuickActionsRow extends StatelessWidget {
  /// Called when Books action is tapped — switches to Books tab
  final VoidCallback onBooksTap;

  /// Called when Reports action is tapped
  final VoidCallback onReportsTap;

  const QuickActionsRow({
    super.key,
    required this.onBooksTap,
    required this.onReportsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickActionItem(
          icon:  Icons.book_outlined,
          label: 'Books',
          color: primaryRed,
          onTap: onBooksTap,         // ✅ Switches to Books tab
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon:  Icons.bar_chart_outlined,
          label: 'Reports',
          color: const Color(0xFF185FA5),
          onTap: onReportsTap,       // ✅ Caller handles this
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon:  Icons.attach_money,
          label: 'Currency',
          color: const Color(0xFF0F6E56),
          onTap: () => CurrencyPickerWidget.show(context), // ✅ Opens currency picker
        ),
        const SizedBox(width: 12),
        _QuickActionItem(
          icon:  Icons.workspace_premium,
          label: 'Premium',
          color: const Color(0xFFBA7517),
          onTap: () => Navigator.push(                    // ✅ Opens subscription screen
            context,
            MaterialPageRoute(
                builder: (_) => const SubscriptionScreen()),
          ),
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}