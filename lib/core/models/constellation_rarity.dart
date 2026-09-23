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

/// The day's badge starts from how hard the constellation itself is to get
/// ([baseRarity], the book entry's 1-5 stars) and is pushed up by how much of
/// the day went into it: more stars, and more spread-out creation times.
ConstellationRarity computeRarity(
  List<SpaceRecord> records, {
  int baseRarity = 1,
}) {
  if (records.isEmpty) return ConstellationRarity.normal;
  var score = baseRarity.clamp(1, 5);
  if (records.length >= 6) {
    score += 2;
  } else if (records.length >= 4) {
    score += 1;
  }
  if (records.length >= 3) {
    final hours = records
        .map(
          (r) => r.createdAt.toLocal().hour + r.createdAt.toLocal().minute / 60,
        )
        .toList();
    final spread = hours.reduce(math.max) - hours.reduce(math.min);
    if (spread >= 8) {
      score += 2;
    } else if (spread >= 4) {
      score += 1;
    }
  }
  if (score >= 7) return ConstellationRarity.superRare;
  if (score >= 4) return ConstellationRarity.rare;
  return ConstellationRarity.normal;
}
