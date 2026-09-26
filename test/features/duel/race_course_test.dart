import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/duel/race_course.dart';

void main() {
  test('同じ seed なら毎回同じ落下時間になる', () {
    final a = RaceCourse.seeded(42);
    final b = RaceCourse.seeded(42);
    expect(a.fallDuration, b.fallDuration);
    expect(a.fallDuration.inMilliseconds, inInclusiveRange(3500, 6000));
  });

  test('だんだん速くなり、fallDuration で缶の面に届く', () {
    const course = RaceCourse(fallDuration: Duration(seconds: 4));
    expect(course.depthAt(Duration.zero), 0);
    expect(course.depthAt(const Duration(seconds: 2)), closeTo(0.25, 1e-9));
    expect(course.depthAt(const Duration(seconds: 4)), closeTo(1, 1e-9));
  });

  test('ぎりぎりのほうが勝ち、落ちたら負け', () {
    const near = RaceDecision.stopped(0.98);
    const far = RaceDecision.stopped(0.7);
    const fell = RaceDecision.fell();

    expect(selfWinsRace(near, far), isTrue);
    expect(selfWinsRace(far, near), isFalse);
    expect(selfWinsRace(far, fell), isTrue);
    expect(selfWinsRace(fell, far), isFalse);
    expect(near.closeness, 98);
    expect(fell.closeness, 0);
    expect(fell.gap, isNull);
  });

  test('両者とも落ちたときは自分視点で負けとし、相手視点でも負けになる対称な規則', () {
    const fell = RaceDecision.fell();
    // self=fell, peer=fell -> self の負け。
    expect(selfWinsRace(fell, fell), isFalse);
    // 同じ規則を相手視点（self と peer を入れ替え）で評価しても負けのまま。
    expect(selfWinsRace(fell, fell), isFalse);
  });
}
