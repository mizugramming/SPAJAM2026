import 'package:flutter/material.dart';
import '../../../core/constants/design_tokens.dart';

enum PlanetSymbol { icon, connection, innerCenter }

class PlanetChoice extends StatelessWidget {
  const PlanetChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.width,
    this.symbol = PlanetSymbol.icon,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final double width;
  final PlanetSymbol symbol;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  AnimatedScale(
                    scale: selected ? 1.06 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      duration: duration,
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-.35, -.4),
                          colors: [
                            color.withValues(alpha: selected ? .82 : .62),
                            color.withValues(alpha: .34),
                            DesignTokens.surface,
                          ],
                          stops: const [0, .55, 1],
                        ),
                        border: Border.all(
                          color: selected ? color : DesignTokens.border,
                          width: selected ? 2 : 1,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: .27),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : const [],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (symbol == PlanetSymbol.icon)
                            Icon(icon, color: DesignTokens.ink, size: 30)
                          else
                            CustomPaint(
                              size: const Size.square(30),
                              painter: _PlanetSymbolPainter(symbol),
                            ),
                          if (selected)
                            const Positioned(
                              right: 5,
                              bottom: 5,
                              child: Icon(
                                Icons.check_circle,
                                size: 20,
                                color: DesignTokens.ink,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? DesignTokens.ink : DesignTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanetSymbolPainter extends CustomPainter {
  const _PlanetSymbolPainter(this.symbol);

  final PlanetSymbol symbol;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ink = Paint()..color = DesignTokens.ink;
    if (symbol == PlanetSymbol.connection) {
      final orbit = Path()
        ..moveTo(5, center.dy)
        ..quadraticBezierTo(center.dx, 7, 25, center.dy);
      canvas.drawPath(
        orbit,
        Paint()
          ..color = DesignTokens.ink.withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(5, center.dy), 3.5, ink);
      canvas.drawCircle(Offset(25, center.dy), 3.5, ink);
    } else if (symbol == PlanetSymbol.innerCenter) {
      for (final (radius, opacity, stroke) in [
        (12.0, .55, 1.6),
        (7.0, .8, 1.4),
      ]) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = DesignTokens.ink.withValues(alpha: opacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      }
      canvas.drawCircle(
        center,
        5.5,
        Paint()..color = DesignTokens.ink.withValues(alpha: .2),
      );
      canvas.drawCircle(center, 3, ink);
    }
  }

  @override
  bool shouldRepaint(covariant _PlanetSymbolPainter oldDelegate) =>
      symbol != oldDelegate.symbol;
}
