import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'home/home_motion.dart';

class DimensionalPage extends StatelessWidget {
  const DimensionalPage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.onRefresh,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final scroll = ListView(
      key: PageStorageKey('dimensional-$title'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: children,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xFF0C1E2C), const Color(0xFF132F45)]
                : [const Color(0xFFF0F7FC), const Color(0xFFF7FAFD)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: onRefresh == null
                  ? scroll
                  : RefreshIndicator(onRefresh: onRefresh!, child: scroll),
            ),
          ),
        ),
      ),
    );
  }
}

class RaisedPanel extends StatelessWidget {
  const RaisedPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? scheme.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: gradient != null
              ? Colors.white.withValues(alpha: .2)
              : scheme.outlineVariant.withValues(alpha: .4),
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0xFF071825) : const Color(0xFFD7E6F1),
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: brandNavy.withValues(alpha: dark ? .18 : .07),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DepthIcon extends StatelessWidget {
  const DepthIcon({
    super.key,
    required this.icon,
    this.color = primaryBlue,
    this.size = 42,
  });
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0015)
        ..rotateX(.12)
        ..rotateY(-.16),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .3),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, .45)!,
              color,
              Color.lerp(color, Colors.black, .25)!,
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .35)),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(color, Colors.black, .4)!,
              offset: const Offset(2, 4),
            ),
            BoxShadow(
              color: color.withValues(alpha: .18),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * .48),
      ),
    ),
  );
}

class DepthAction extends StatelessWidget {
  const DepthAction({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = primaryBlue,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          DepthIcon(icon: icon, color: color, size: 38),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color == const Color(0xFFC34B56)
                        ? scheme.error
                        : scheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              (onTap == null
                  ? const SizedBox.shrink()
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    )),
        ],
      ),
    );
    return RaisedPanel(
      padding: EdgeInsets.zero,
      child: onTap == null
          ? content
          : DepthButton(radius: 26, onTap: onTap!, child: content),
    );
  }
}

class DimensionalHeading extends StatelessWidget {
  const DimensionalHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    ],
  );
}
