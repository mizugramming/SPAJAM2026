import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'space_record.dart';

enum ConstellationRarity {
  normal('通常', Color(0xFFAEB8CF)),
  rare('レア', Color(0xFFCEBEF6)),
  superRare('激レア', Color(0xFFFFD8A1));

  const ConstellationRarity(this.label, this.color);
  final String label;
  final Color color;
}

// More stars, and more spread-out creation times, make a rarer constellation.
// Star count alone can raise the rarity; a wide time spread can raise it
// further at the same count.
ConstellationRarity computeRarity(List<SpaceRecord> records) {
  if (records.length < 3) return ConstellationRarity.normal;
  final hours = records
      .map(
        (r) => r.createdAt.toLocal().hour + r.createdAt.toLocal().minute / 60,
      )
      .toList();
  final spread = hours.reduce(math.max) - hours.reduce(math.min);
  if (records.length >= 6 || (records.length >= 5 && spread >= 8)) {
    return ConstellationRarity.superRare;
  }
  if (records.length >= 4 || spread >= 4) return ConstellationRarity.rare;
  return ConstellationRarity.normal;
}
