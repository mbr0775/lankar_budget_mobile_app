import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Finite entrance motion keeps the scrolling dashboard calm.
class HomeReveal extends StatelessWidget {
  const HomeReveal({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 550 + order * 90),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..translateByDouble(0, 22 * (1 - value), 0, 1)
            ..rotateX(.06 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

/// Ink, keyboard focus and touch depth share one accessible button.
class DepthButton extends StatefulWidget {
  const DepthButton({
    super.key,
    required this.onTap,
    required this.child,
    this.radius = 22,
    this.color,
  });
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  final Color? color;
  @override
  State<DepthButton> createState() => _DepthButtonState();
}

class _DepthButtonState extends State<DepthButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _pressed ? 1 : 0),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (_, value, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateX(reduced ? 0 : -.045 * value)
          ..scaleByDouble(1 - .025 * value, 1 - .025 * value, 1, 1),
        child: child,
      ),
      child: Material(
        color: widget.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(widget.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(widget.radius),
          child: widget.child,
        ),
      ),
    );
  }
}

class SculptedIcon extends StatelessWidget {
  const SculptedIcon({super.key, required this.icon, this.size = 46});
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .002)
        ..rotateX(.16)
        ..rotateY(-.18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF73CEF4), primaryBlue, Color(0xFF10567E)],
            stops: [0, .55, 1],
          ),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: Colors.white.withValues(alpha: .4)),
          boxShadow: [
            const BoxShadow(color: Color(0xFF0D4566), offset: Offset(2, 4)),
            BoxShadow(
              color: primaryBlue.withValues(alpha: .22),
              blurRadius: 14,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * .48),
      ),
    ),
  );
}

/// Only the decorative sculpture repaints continuously. Values stay still.
class GrowthSculpture extends StatefulWidget {
  const GrowthSculpture({super.key, this.size = 120});
  final double size;
  @override
  State<GrowthSculpture> createState() => _GrowthSculptureState();
}

class _GrowthSculptureState extends State<GrowthSculpture>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .25;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (_, __) {
              final wave = math.sin(_motion.value * math.pi * 2);
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0015)
                  ..translateByDouble(0, wave * 4, 0, 1)
                  ..rotateY(wave * .09)
                  ..rotateX(.04),
                child: CustomPaint(painter: _GrowthPainter(wave)),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _GrowthPainter extends CustomPainter {
  const _GrowthPainter(this.wave);
  final double wave;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 140);
    canvas.drawOval(
      const Rect.fromLTWH(16, 111, 113, 18),
      Paint()
        ..color = const Color(0xFF001E35).withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    _block(
      canvas,
      19,
      114,
      102,
      10,
      10,
      const Color(0xFF69B8D8),
      const Color(0xFFA1E1F9),
    );
    _block(
      canvas,
      28,
      105,
      21,
      35,
      10,
      const Color(0xFF35A1D3),
      const Color(0xFF9FE5FC),
    );
    _block(canvas, 60, 105, 21, 55, 10, const Color(0xFFBCE9F9), Colors.white);
    _block(
      canvas,
      92,
      105,
      21,
      79,
      10,
      const Color(0xFF59BEE7),
      const Color(0xFFCAF2FF),
    );
    final arrow = Path()
      ..moveTo(24, 63)
      ..lineTo(52, 35)
      ..lineTo(67, 46)
      ..lineTo(96, 17)
      ..lineTo(87, 9)
      ..lineTo(119, 5)
      ..lineTo(113, 37)
      ..lineTo(104, 28)
      ..lineTo(67, 63)
      ..lineTo(52, 52)
      ..lineTo(31, 73)
      ..close();
    canvas.save();
    canvas.translate(2, 4);
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF197EAE));
    canvas.restore();
    canvas.drawPath(
      arrow,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0xFF80DBFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(24, 5, 95, 70)),
    );
    canvas.save();
    canvas.translate(0, -wave * 3);
    canvas.drawOval(
      const Rect.fromLTWH(3, 91, 35, 12),
      Paint()..color = const Color(0xFF287DA6),
    );
    canvas.drawRect(
      const Rect.fromLTWH(3, 86, 35, 11),
      Paint()..color = const Color(0xFF287DA6),
    );
    canvas.drawOval(
      const Rect.fromLTWH(3, 80, 35, 15),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFD8F6FF), Color(0xFF67BBDC)],
        ).createShader(const Rect.fromLTWH(3, 80, 35, 15)),
    );
    canvas.drawOval(
      const Rect.fromLTWH(10, 83, 21, 8),
      Paint()
        ..color = Colors.white.withValues(alpha: .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _block(
    Canvas canvas,
    double x,
    double base,
    double width,
    double height,
    double depth,
    Color front,
    Color top,
  ) {
    final face = Rect.fromLTWH(x, base - height, width, height);
    canvas.drawRect(
      face,
      Paint()
        ..shader = LinearGradient(
          colors: [top, front],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(face),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, base - height)
        ..lineTo(x + depth, base - height - depth * .6)
        ..lineTo(x + width + depth, base - height - depth * .6)
        ..lineTo(x + width, base - height)
        ..close(),
      Paint()..color = top,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + width, base - height)
        ..lineTo(x + width + depth, base - height - depth * .6)
        ..lineTo(x + width + depth, base - depth * .6)
        ..lineTo(x + width, base)
        ..close(),
      Paint()..color = Color.lerp(front, const Color(0xFF083D60), .35)!,
    );
  }

  @override
  bool shouldRepaint(_GrowthPainter oldDelegate) => oldDelegate.wave != wave;
}
