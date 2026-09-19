import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAlignX = 'star_placement_align_x';
const _kAlignY = 'star_placement_align_y';
const _kScale = 'star_placement_scale';

const kStarBaseSize = 120.0;
const kStarHaloSize = 190.0;

class StarPlacement {
  const StarPlacement({this.alignX = 0, this.alignY = 1, this.scale = 2.0});
  final double alignX; // -1 (left) .. 1 (right)
  final double alignY; // -1 (top) .. 1 (bottom)
  final double scale; // multiplier applied to the base star size

  StarPlacement copyWith({double? alignX, double? alignY, double? scale}) =>
      StarPlacement(
        alignX: alignX ?? this.alignX,
        alignY: alignY ?? this.alignY,
        scale: scale ?? this.scale,
      );
}

final starPlacementProvider =
    AsyncNotifierProvider<StarPlacementNotifier, StarPlacement>(
      StarPlacementNotifier.new,
    );

class StarPlacementNotifier extends AsyncNotifier<StarPlacement> {
  @override
  Future<StarPlacement> build() async {
    final prefs = await SharedPreferences.getInstance();
    const fallback = StarPlacement();
    return StarPlacement(
      alignX: prefs.getDouble(_kAlignX) ?? fallback.alignX,
      alignY: prefs.getDouble(_kAlignY) ?? fallback.alignY,
      scale: prefs.getDouble(_kScale) ?? fallback.scale,
    );
  }

  Future<void> save(StarPlacement placement) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kAlignX, placement.alignX);
    await prefs.setDouble(_kAlignY, placement.alignY);
    await prefs.setDouble(_kScale, placement.scale);
    state = AsyncData(placement);
  }

  Future<void> reset() => save(const StarPlacement());
}
