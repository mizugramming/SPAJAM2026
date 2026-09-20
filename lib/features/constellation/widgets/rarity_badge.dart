import 'package:flutter/material.dart';
import '../../../core/models/constellation_rarity.dart';

class RarityBadge extends StatelessWidget {
  const RarityBadge({super.key, required this.rarity});
  final ConstellationRarity rarity;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: rarity.color),
      color: rarity.color.withValues(alpha: .12),
    ),
    child: Text(
      rarity.label,
      style: TextStyle(
        color: rarity.color,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        fontSize: 12,
      ),
    ),
  );
}
