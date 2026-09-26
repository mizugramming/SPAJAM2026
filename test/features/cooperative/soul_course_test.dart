import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/cooperative/soul_course.dart';

SoulRun run({
  SoulLevel? level,
  List<Duration?> partner = const [Duration.zero, Duration.zero, Duration.zero],
}) => SoulRun(level: level ?? SoulLevel.all.first, partnerOffsets: partner);

void main() {
  test('レベルは3つで、1・2・3pt。上がるほど速く、押せる幅がせまい', () {
    expect(SoulLevel.all.map((l) => l.points), [1, 2, 3]);
    for (var i = 1; i < SoulLevel.all.length; i++) {
      expect(SoulLevel.all[i].flight, lessThan(SoulLevel.all[i - 1].flight));
      expect(SoulLevel.all[i].window, lessThan(SoulLevel.all[i - 1].window));
    }
  });

  test('右・左・右・左・右・左と運び、最後に穴へ入る', () {
    final r = run();
    final level = r.level;
    expect(r.isSelfHop(1), isTrue);
    expect(r.isSelfHop(2), isFalse);

    for (final hop in [1, 3, 5]) {
      final result = r.tap(r.arrival(hop));
      expect(result.kind, SoulTapKind.carried, reason: 'hop $hop');
      expect(result.just, isTrue);
    }
    r.advance(r.holeArrival - const Duration(milliseconds: 1));
    expect(r.status, SoulStatus.flying);
    expect(r.carriedHops, 6);
    r.advance(r.holeArrival);
    expect(r.status, SoulStatus.cleared);
    expect(r.holeArrival, level.firstArrival + level.flight * 6);
  });

  test('押せる幅の端までは運べ、ぴったりでなければ「ジャスト」にはならない', () {
    final r = run();
    final late = r.tap(r.arrival(1) + r.level.window);
    expect(late.kind, SoulTapKind.carried);
    expect(late.just, isFalse);
  });

  test('早すぎると、その缶で海へ落ちる', () {
    final r = run();
    final at = r.arrival(1) - r.level.window - const Duration(milliseconds: 1);
    expect(r.tap(at).kind, SoulTapKind.fell);
    expect(r.status, SoulStatus.fell);
    expect(r.failedHop, 1);
    expect(r.failedAt, at);
  });

  test('押さずに見のがすと、幅の終わりで落ちる', () {
    final r = run();
    r.advance(r.arrival(1) + r.level.window);
    expect(r.status, SoulStatus.flying);
    r.advance(r.arrival(1) + r.level.window + const Duration(milliseconds: 1));
    expect(r.status, SoulStatus.fell);
    expect(r.failedHop, 1);
    expect(r.failedAt, r.arrival(1) + r.level.window);
    // 落ちた後の操作は何も起こさない。
    expect(r.tap(r.arrival(3)).kind, SoulTapKind.ignored);
  });

  test('相方の番に押すと、おてつきで落ちる', () {
    final r = run();
    r.tap(r.arrival(1));
    final result = r.tap(r.arrival(2) - const Duration(milliseconds: 300));
    expect(result.kind, SoulTapKind.fell);
    expect(r.failedHop, 2);
  });

  test('相方が押しそこねると、その缶で落ちる', () {
    final r = run(partner: const [Duration.zero, null, Duration.zero]);
    r.tap(r.arrival(1));
    r.tap(r.arrival(3));
    r.advance(r.arrival(4) + r.level.window + const Duration(milliseconds: 1));
    expect(r.status, SoulStatus.fell);
    expect(r.failedHop, 4);
  });

  test('運び終わった後のタップは何もしない', () {
    final r = run();
    for (final hop in [1, 3, 5]) {
      r.tap(r.arrival(hop));
    }
    expect(r.tap(r.arrival(6)).kind, SoulTapKind.ignored);
    r.advance(r.holeArrival);
    expect(r.status, SoulStatus.cleared);
  });

  test('仮想の相方は幅の半分の範囲で押し、レベル1では押しそこねない', () {
    final partner = SoulPartner(Random(1));
    for (final level in SoulLevel.all) {
      for (var i = 0; i < 50; i++) {
        final offsets = partner.offsetsFor(level);
        expect(offsets, hasLength(SoulRun.partnerHops));
        for (final offset in offsets) {
          if (offset == null) {
            expect(level.number, isNot(1));
            continue;
          }
          expect(offset.abs() * 2, lessThanOrEqualTo(level.window));
        }
      }
    }
  });
}
