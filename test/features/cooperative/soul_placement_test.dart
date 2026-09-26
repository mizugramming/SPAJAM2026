import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/cooperative/soul_placement.dart';
import 'package:spajam2026/features/cooperative/soul_stage.dart';

void main() {
  test('最初の並びはユーザーが決めた位置と角度', () {
    const standard = SoulPlacement.standard;
    expect(standard.cans, const [
      Offset(1.000, 0.255),
      Offset(0.060, 0.349),
      Offset(0.967, 0.440),
      Offset(0.055, 0.540),
      Offset(0.989, 0.628),
      Offset(0.031, 0.715),
    ]);
    expect(standard.hole, const Offset(0.488, 0.869));
    expect(standard.angles, [-25.0, 25.0, -25.0, 25.0, -25.0, 25.0]);
  });

  test('配置は画面の割合で決まり、画面の外へははみ出さない', () {
    const size = Size(400, 800);
    final middle = SoulLayout(
      size,
      SoulPlacement.standard.withCan(1, const Offset(0.5, 0.3)),
    );
    expect(middle.canX(1), closeTo(200, 1e-6));
    expect(middle.canTop(1), closeTo(240, 1e-6));

    final edge = SoulLayout(
      size,
      SoulPlacement.standard
          .withCan(1, const Offset(1, 1))
          .withHole(const Offset(0, 0)),
    );
    expect(edge.canX(1) + edge.canWidth / 2, lessThanOrEqualTo(400));
    expect(edge.canTop(1) + edge.canHeight, lessThanOrEqualTo(800));
    expect(edge.holeCenter.dx - edge.holeWidth / 2, greaterThanOrEqualTo(0));
    expect(edge.holeTop, 0);
    // 魂は空き缶の上へ入る。
    expect(edge.holePoint.dx, closeTo(edge.holeCenter.dx, 1e-6));
  });

  test('傾けた缶では、魂はふたの向きに乗り、角度は範囲内に収まる', () {
    const size = Size(400, 800);
    final flat = SoulLayout(size, SoulPlacement.standard.withAngle(1, 0));
    final tilted = SoulLayout(size, SoulPlacement.standard.withAngle(1, 30));
    // 時計回りに傾けると、ふたの上の点は右へずれる。
    expect(tilted.standing(1).dx, greaterThan(flat.standing(1).dx + 5));
    expect(tilted.lid(1).dx, greaterThan(flat.lid(1).dx));
    // 他の缶は変わらない。
    expect(tilted.standing(2), flat.standing(2));
    expect(SoulPlacement.standard.withAngle(3, 200).angle(3), 90);
    expect(SoulPlacement.standard.withAngle(3, -200).angle(3), -90);
  });

  test('缶の傾きはラジアンに直して回す', () {
    final layout = SoulLayout(const Size(400, 800));
    expect(layout.canRadians(1), closeTo(-25 * pi / 180, 1e-9));
    expect(layout.canRadians(2), closeTo(25 * pi / 180, 1e-9));
  });
}
