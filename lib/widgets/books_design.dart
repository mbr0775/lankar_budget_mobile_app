import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class BooksSummaryCard extends StatelessWidget {
  const BooksSummaryCard({
    super.key,
    required this.balance,
    required this.symbol,
    required this.count,
  });
  final double balance;
  final String symbol;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandNavy, Color(0xFF145F8D), primaryBlue],
      ),
      border: Border.all(color: const Color(0xFF4AA4CB).withValues(alpha: .4)),
      boxShadow: [
        BoxShadow(
          color: primaryBlue.withValues(alpha: .2),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    padding: const EdgeInsets.all(22),
    child: LayoutBuilder(
      builder: (context, constraints) {
        const label = Text(
          'ALL CASH BOOKS',
          style: TextStyle(
            color: Color(0xFFC9E9F8),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        );
        final amount = Semantics(
          label: 'Combined balance $symbol ${formatCurrency(balance)}',
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol ${formatCurrency(balance)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                letterSpacing: -1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        final caption = Text(
          'Combined balance across $count ${count == 1 ? 'book' : 'books'}',
          style: const TextStyle(
            color: Color(0xFFC9E9F8),
            fontSize: 11,
            height: 1.5,
          ),
        );
        if (constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(12) > 15) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(child: label),
                  BookStackArtwork(size: 76),
                ],
              ),
              const SizedBox(height: 6),
              amount,
              const SizedBox(height: 8),
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
            const SizedBox(width: 8),
            const BookStackArtwork(size: 96),
          ],
        );
      },
    ),
  );
}

class BooksEmptyState extends StatelessWidget {
  const BooksEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.icon = Icons.auto_stories_rounded,
  });
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.6,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// A native book sculpture, isolated from text and the scrolling list.
class BookStackArtwork extends StatefulWidget {
  const BookStackArtwork({super.key, this.size = 120});
  final double size;
  @override
  State<BookStackArtwork> createState() => _BookStackArtworkState();
}

class _BookStackArtworkState extends State<BookStackArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
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
                  ..rotateY(wave * .08),
                child: CustomPaint(painter: _BookStackPainter(wave)),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _BookStackPainter extends CustomPainter {
  const _BookStackPainter(this.wave);
  final double wave;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 140, size.height / 140);
    canvas.drawOval(
      const Rect.fromLTWH(18, 116, 112, 14),
      Paint()
        ..color = const Color(0xFF001D30).withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    _book(
      canvas,
      86 + wave * 2,
      const Color(0xFF85D1EC),
      const Color(0xFFD4F2FC),
    );
    _book(
      canvas,
      64 - wave * 2,
      const Color(0xFF348FB8),
      const Color(0xFF70CEF1),
    );
    _book(
      canvas,
      41 + wave * 3,
      const Color(0xFF1673A5),
      const Color(0xFF82DAF8),
    );
  }

  void _book(Canvas canvas, double y, Color front, Color light) {
    final top = Path()
      ..moveTo(16, y + 12)
      ..lineTo(70, y + 31)
      ..lineTo(125, y + 2)
      ..lineTo(71, y - 17)
      ..close();
    canvas.drawPath(
      Path()
        ..moveTo(16, y + 12)
        ..lineTo(70, y + 31)
        ..lineTo(70, y + 42)
        ..lineTo(16, y + 23)
        ..close(),
      Paint()..color = front,
    );
    canvas.drawPath(
      Path()
        ..moveTo(70, y + 31)
        ..lineTo(125, y + 2)
        ..lineTo(125, y + 13)
        ..lineTo(70, y + 42)
        ..close(),
      Paint()..color = const Color(0xFFCCE9F5),
    );
    for (final offset in [4.0, 7.0]) {
      canvas.drawLine(
        Offset(74, y + 31 + offset),
        Offset(121, y + 6 + offset),
        Paint()
          ..color = const Color(0xFF82B8CE)
          ..strokeWidth = .8,
      );
    }
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: [light, front],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(16, y - 17, 109, 50)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(37, y + 10)
        ..lineTo(49, y + 14)
        ..lineTo(83, y - 4),
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(77, y - 6)
        ..lineTo(86, y - 6)
        ..lineTo(83, y + 1),
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BookStackPainter oldDelegate) => oldDelegate.wave != wave;
}
