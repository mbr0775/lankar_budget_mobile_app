import 'package:flutter/material.dart';
import '../../screens/profile/subscription_screen.dart';
import 'home_motion.dart';

class PremiumBanner extends StatelessWidget {
  const PremiumBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: .2)),
      ),
      child: DepthButton(
        radius: 24,
        color: scheme.primary.withValues(alpha: .07),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const SculptedIcon(
                icon: Icons.workspace_premium_rounded,
                size: 42,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make room for more',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Explore Lankar Premium',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                color: scheme.primary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
