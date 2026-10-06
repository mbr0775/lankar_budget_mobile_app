import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Shared dock for the five persistent tabs. The scaffold reserves its space,
/// so the floating shape never covers page controls or keyboard content.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  }) : assert(selectedIndex >= 0 && selectedIndex < 5);

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _destinations = [
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination(
      'Books',
      Icons.auto_stories_outlined,
      Icons.auto_stories_rounded,
    ),
    _Destination(
      'Reports',
      Icons.insert_chart_outlined_rounded,
      Icons.insert_chart_rounded,
    ),
    _Destination(
      'Analytics',
      Icons.donut_large_outlined,
      Icons.donut_large_rounded,
    ),
    _Destination('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final duration = reduced
        ? Duration.zero
        : const Duration(milliseconds: 320);
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xFF17374D), const Color(0xFF102838)]
                      : [Colors.white, const Color(0xFFF4FAFE)],
                ),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF36566C)
                      : const Color(0xFFD7E8F3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: brandNavy.withValues(alpha: dark ? .32 : .10),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: dark ? .07 : .04),
                    blurRadius: 14,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final slotWidth =
                          constraints.maxWidth / _destinations.length;
                      var labelHeight = 0.0;
                      for (final destination in _destinations) {
                        final painter = TextPainter(
                          text: TextSpan(
                            text: destination.label,
                            style: labelStyle,
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: math.max(1, slotWidth - 6));
                        labelHeight = math.max(labelHeight, painter.height);
                        painter.dispose();
                      }
                      final height = 38 + 8 + labelHeight + 18;
                      return SizedBox(
                        height: height,
                        child: Stack(
                          children: [
                            AnimatedPositionedDirectional(
                              key: const ValueKey('nav-highlight'),
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              start: selectedIndex * slotWidth + 2,
                              top: 0,
                              bottom: 0,
                              width: slotWidth - 4,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(
                                      alpha: dark ? .13 : .07,
                                    ),
                                    borderRadius: BorderRadius.circular(23),
                                    border: Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: .12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            FocusTraversalGroup(
                              child: Row(
                                children: [
                                  for (
                                    int index = 0;
                                    index < _destinations.length;
                                    index++
                                  )
                                    Expanded(
                                      child: _DockTab(
                                        destination: _destinations[index],
                                        index: index,
                                        selected: selectedIndex == index,
                                        duration: duration,
                                        labelStyle: labelStyle,
                                        labelHeight: labelHeight,
                                        onTap: () {
                                          if (index != selectedIndex) {
                                            onTap(index);
                                          }
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    required this.destination,
    required this.index,
    required this.selected,
    required this.duration,
    required this.labelStyle,
    required this.labelHeight,
    required this.onTap,
  });
  final _Destination destination;
  final int index;
  final bool selected;
  final Duration duration;
  final TextStyle labelStyle;
  final double labelHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      key: ValueKey('nav-tab-${destination.label.toLowerCase()}'),
      container: true,
      button: true,
      selected: selected,
      label: destination.label,
      hint: 'Tab ${index + 1} of 5',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: destination.label,
          child: InkWell(
            borderRadius: BorderRadius.circular(23),
            onTap: onTap,
            focusColor: scheme.primary.withValues(alpha: .18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: selected ? 1 : 0),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -2 * value),
                      child: Container(
                        width: 42,
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.lerp(
                                Colors.transparent,
                                secondaryBlue,
                                value,
                              )!,
                              Color.lerp(
                                Colors.transparent,
                                primaryBlue,
                                value,
                              )!,
                              Color.lerp(
                                Colors.transparent,
                                const Color(0xFF10527A),
                                value,
                              )!,
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .35 * value),
                          ),
                          boxShadow: value == 0
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF0B466B,
                                    ).withValues(alpha: value),
                                    offset: Offset(0, 2 * value),
                                  ),
                                  BoxShadow(
                                    color: primaryBlue.withValues(
                                      alpha: .24 * value,
                                    ),
                                    blurRadius: 10 * value,
                                    offset: Offset(0, 5 * value),
                                  ),
                                ],
                        ),
                        child: AnimatedSwitcher(
                          duration: duration,
                          child: Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            key: ValueKey(selected),
                            size: 22,
                            color: Color.lerp(
                              scheme.onSurfaceVariant,
                              Colors.white,
                              value,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: labelHeight,
                      child: Text(
                        destination.label,
                        textAlign: TextAlign.center,
                        style: labelStyle.copyWith(
                          color: Color.lerp(
                            scheme.onSurfaceVariant,
                            scheme.primary,
                            value,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
