import 'package:flutter/material.dart';
import '../../../core/constants/design_tokens.dart';
import '../controllers/star_placement_controller.dart';

class PlacedStar extends StatelessWidget {
  const PlacedStar({super.key, required this.placement});
  final StarPlacement placement;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment(placement.alignX, placement.alignY),
    child: Container(
      width: kStarHaloSize * placement.scale,
      height: kStarHaloSize * placement.scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            DesignTokens.gold.withValues(alpha: .55),
            DesignTokens.accent.withValues(alpha: .12),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Image.asset(
          'assets/star/hoshi.png',
          width: kStarBaseSize * placement.scale,
        ),
      ),
    ),
  );
}
