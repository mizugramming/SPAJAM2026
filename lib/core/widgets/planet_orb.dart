import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlanetOrb extends StatelessWidget {
  const PlanetOrb({
    super.key,
    required this.color,
    this.size = 120,
    this.stage = 2,
    this.seed = 1,
    this.rings = false,
  });
  final Color color;
  final double size;
  final int stage;
  final int seed;
  final bool rings;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PlanetPainter(color, stage, seed, rings)),
    ),
  );
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.color, this.stage, this.seed, this.rings);
  final Color color;
  final int stage;
  final int seed;
  final bool rings;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .32;
    final base = stage == 0
        ? Color.lerp(color, const Color(0xFF18203A), .78)!
        : color;
    canvas.drawCircle(
      center,
      radius * 1.48,
      Paint()
        ..shader = RadialGradient(
          colors: [base.withValues(alpha: .20), base.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.48)),
    );
    if (rings) _ring(canvas, center, radius, false);
    final sphere = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.6, -.6),
          radius: 1.1,
          colors: [
            Color.lerp(base, Colors.white, .7)!,
            base,
            Color.lerp(base, const Color(0xFF0A112C), .88)!,
          ],
          stops: const [0, .4, 1],
        ).createShader(sphere),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    final random = math.Random(seed);
    for (var i = 0; i < 18; i++) {
      final x = center.dx + (random.nextDouble() * 2 - 1) * radius;
      final y = center.dy + (random.nextDouble() * 2 - 1) * radius;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * (.15 + random.nextDouble() * .65),
          height: radius * (.1 + random.nextDouble() * .24),
        ),
        Paint()
          ..color =
              (i.isEven ? const Color(0xFFFCDE9E) : const Color(0xFF314C6F))
                  .withValues(alpha: stage == 0 ? .07 : .23)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = base.withValues(alpha: .65),
    );
    if (rings) _ring(canvas, center, radius, true);
    if (stage >= 3) {
      canvas.drawCircle(
        Offset(center.dx + radius * 1.1, center.dy - radius * .95),
        radius * .10,
        Paint()..color = const Color(0xFFFFDFAC),
      );
    }
  }

  void _ring(Canvas canvas, Offset center, double radius, bool front) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.27);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 3.5,
      height: radius * 1.1,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFD6AB).withValues(alpha: front ? .9 : .3);
    canvas.drawArc(
      rect,
      front ? 0 : math.pi,
      math.pi,
      false,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawArc(
      rect,
      front ? 0 : math.pi,
      math.pi,
      false,
      paint
        ..maskFilter = null
        ..strokeWidth = 1.3,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlanetPainter old) =>
      old.color != color ||
      old.stage != stage ||
      old.seed != seed ||
      old.rings != rings;
}
