import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/cooperative/soul_course.dart';
import 'package:spajam2026/features/online/online_game_timing.dart';

void main() {
  OnlineSoulRun run({
    int hop = 1,
    int now = 10000,
    bool failed = false,
    Map<String, dynamic> extra = const {},
  }) => OnlineSoulRun(
    state: {'level': 0, 'levelStartAt': 1000, 'hop': hop, ...extra},
    serverNow: now,
    fallbackStartAt: 1000,
    failed: failed,
  );

  test('late partner packet never invents a carried hop or a failure', () {
    final state = run(hop: 2);
    expect(state.visualTime, const Duration(milliseconds: 2300));
    expect(state.nextHop, 2);
    expect(state.status, SoulStatus.flying);
    state.advance(const Duration(days: 1));
    state.tap(const Duration(days: 1));
    expect(state.nextHop, 2);
    expect(state.status, SoulStatus.flying);
  });

  test('odd/even ownership includes the sixth hop on the second device', () {
    expect(run().ownedBy(selfId: 'a', playerIds: ['a', 'b']), isTrue);
    expect(run().ownedBy(selfId: 'b', playerIds: ['a', 'b']), isFalse);
    expect(run(hop: 6).ownedBy(selfId: 'b', playerIds: ['a', 'b']), isTrue);
    expect(run(hop: 7).ownedBy(selfId: 'b', playerIds: ['a', 'b']), isFalse);
  });

  test('all accepted hops sink only on the shared hole arrival timeline', () {
    expect(run(hop: 7, now: 8299).status, SoulStatus.flying);
    expect(run(hop: 7, now: 8300).status, SoulStatus.cleared);
    expect(run(hop: 6, now: 20000).status, SoulStatus.flying);
  });

  test('confirmed failure uses the server timestamp and failed hop', () {
    final state = run(
      hop: 3,
      failed: true,
      extra: {'failedAt': 4290, 'failedHop': 3},
    );
    expect(state.status, SoulStatus.fell);
    expect(state.failedAt, const Duration(milliseconds: 3290));
    expect(state.failedHop, 3);
  });

  test('unstarted server level stays at the release position', () {
    final state = run(now: 1000, extra: {'levelStartAt': 0});
    expect(state.elapsed, Duration.zero);
    expect(state.visualTime, Duration.zero);
  });

  test('new level uses its own clock, speed, and target time', () {
    final state = run(now: 21000, extra: {'level': 2, 'levelStartAt': 20000});
    expect(state.level.number, 3);
    expect(state.targetAt, 20845);
    expect(state.level.window, const Duration(milliseconds: 150));
  });
}
