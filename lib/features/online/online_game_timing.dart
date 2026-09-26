import 'dart:math' as math;

import '../cooperative/soul_course.dart';

/// Read-only projection of accepted network inputs for the existing artwork.
/// It never runs the demo partner or advances/decides the shared game.
class OnlineSoulRun extends SoulRun {
  OnlineSoulRun({
    required this.state,
    required this.serverNow,
    required this.fallbackStartAt,
    required this.failed,
  }) : super(
         level: SoulLevel.all[levelIndex(state)],
         partnerOffsets: const [null, null, null],
       );

  final Map<String, dynamic> state;
  final int serverNow;
  final int fallbackStartAt;
  final bool failed;

  static int levelIndex(Map<String, dynamic> state) =>
      ((state['level'] as num?)?.toInt() ?? 0).clamp(0, 2);

  int get startAt {
    final value = (state['levelStartAt'] as num?)?.toInt();
    return value == null || value <= 0 ? fallbackStartAt : value;
  }

  Duration get elapsed =>
      Duration(milliseconds: math.max(0, serverNow - startAt));

  @override
  int get nextHop => ((state['hop'] as num?)?.toInt() ?? 1).clamp(1, 7);

  @override
  int get carriedHops => nextHop - 1;

  @override
  int? get failedHop => failed
      ? ((state['failedHop'] as num?)?.toInt() ?? nextHop).clamp(1, 6)
      : null;

  @override
  Duration? get failedAt {
    if (!failed) return null;
    final accepted = (state['failedAt'] as num?)?.toInt();
    return accepted == null
        ? arrival(failedHop!) + level.window
        : Duration(milliseconds: math.max(0, accepted - startAt));
  }

  @override
  SoulStatus get status {
    if (failed) return SoulStatus.fell;
    if (nextHop > SoulRun.hops && elapsed >= holeArrival) {
      return SoulStatus.cleared;
    }
    return SoulStatus.flying;
  }

  // The online widget renders the ring separately: either participant can own
  // the left/even lane, including hop 6, unlike the one-device demo.
  @override
  bool isSelfHop(int hop) => false;

  /// Pause at a can until that hop is acknowledged. This does not invent a
  /// partner's successful input while a packet is late or the socket is down.
  Duration get visualTime {
    if (failed || nextHop > SoulRun.hops) return elapsed;
    final target = arrival(nextHop);
    return elapsed > target ? target : elapsed;
  }

  int get targetAt => startAt + arrival(nextHop).inMilliseconds;

  bool ownedBy({required String selfId, required List<String> playerIds}) {
    if (playerIds.length != 2 || nextHop > SoulRun.hops) return false;
    return playerIds[nextHop.isOdd ? 0 : 1] == selfId;
  }

  // No local caller can accidentally re-enable the demo's autonomous partner.
  @override
  void advance(Duration t) {}

  @override
  SoulTapResult tap(Duration t) => const SoulTapResult(SoulTapKind.ignored);
}
