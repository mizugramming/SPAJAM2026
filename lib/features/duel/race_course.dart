import 'dart:math';

import 'package:flutter/foundation.dart';

/// How far a racer has fallen down the rope: 0 at the start, 1 level with the
/// seachicken can. Values above 1 mean past the can and into the sea.
///
/// Pure timing/physics, kept separate from the widget so it can be tested and
/// reused if a real two-device version later needs the same fall curve.
@immutable
class RaceCourse {
  const RaceCourse({required this.fallDuration});

  /// A duration inside [min]..[max], deterministic for a given [seed] so a
  /// widget test can reproduce one run.
  factory RaceCourse.seeded(
    int seed, {
    Duration min = const Duration(milliseconds: 1100),
    Duration max = const Duration(milliseconds: 2000),
  }) {
    final span = max.inMilliseconds - min.inMilliseconds;
    final ms = min.inMilliseconds + Random(seed).nextInt(span + 1);
    return RaceCourse(fallDuration: Duration(milliseconds: ms));
  }

  /// Time to fall from the start to level with the can if never stopped.
  final Duration fallDuration;

  /// Accelerating fall (starts slow, speeds up toward the can), matching the
  /// "だんだん危なくなる" feel the chicken-race brief asked for.
  double depthAt(Duration elapsed) {
    if (elapsed <= Duration.zero) return 0;
    final x = elapsed.inMicroseconds / fallDuration.inMicroseconds;
    return x * x;
  }
}

/// One racer's result: where they stopped, or that they missed the can.
@immutable
class RaceDecision {
  const RaceDecision.stopped(this.depth) : fell = false;
  const RaceDecision.fell() : depth = 1, fell = true;

  /// Depth at the moment of the decision. 1 when fallen.
  final double depth;
  final bool fell;

  /// Distance short of the can's edge, 0 (perfect) .. 1 (never moved). Null
  /// once fallen — there is no "how close" once you're in the sea.
  double? get gap => fell ? null : (1 - depth).clamp(0.0, 1.0);

  /// How close to the edge, as a 0-100 display value. 0 when fallen.
  int get closeness => fell ? 0 : ((1 - gap!) * 100).round();
}

/// Self's result compared with peer's, from self's point of view.
///
/// [DuelGameResult] only has win/loss, no draw. The one case this can't
/// represent cleanly is both racers falling: this resolves to a loss for
/// self, which is intentionally symmetric — if the same rule ran again from
/// peer's point of view, peer would also compute a loss, so a shared fall
/// never favors either side. An exact tie between two stopped depths is
/// unreachable in practice with a continuous clock and resolves the same way.
bool selfWinsRace(RaceDecision self, RaceDecision peer) {
  if (self.fell) return false;
  if (peer.fell) return true;
  return self.gap! < peer.gap!;
}
