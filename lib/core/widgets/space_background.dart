import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

class SpaceBackground extends StatelessWidget {
  const SpaceBackground({super.key, required this.child, this.scenic = false});
  final Widget child;
  final bool scenic;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const ColoredBox(color: DesignTokens.background),
      Positioned.fill(
        child: Opacity(
          opacity: scenic ? .85 : .34,
          child: Image.asset(
            'assets/common/night_sky.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            excludeFromSemantics: true,
          ),
        ),
      ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                DesignTokens.background.withValues(alpha: .12),
                Colors.transparent,
                DesignTokens.background.withValues(alpha: scenic ? .12 : .65),
              ],
            ),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(child: CustomPaint(painter: _StarDustPainter())),
      ),
      child,
    ],
  );
}

class _StarDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(82);
    for (var i = 0; i < 95; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = .3 + random.nextDouble() * .8;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = Colors.white.withValues(
            alpha: .1 + random.nextDouble() * .3,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarDustPainter oldDelegate) => false;
}
