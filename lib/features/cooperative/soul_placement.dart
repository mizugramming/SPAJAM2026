import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 協力ゲームの缶6個と、最後の空き缶の置き場所。
///
/// 位置は盤面の幅・高さに対する割合で持ち、画面の大きさが変わっても同じ並びになる。
/// x は缶の中心、y は缶の上端。缶は1番から順に魂が運ばれ、奇数番があなた、
/// 偶数番が相方の担当。缶ごとに傾き（度、時計回りが正）を持つ。
@immutable
class SoulPlacement {
  const SoulPlacement({
    required this.cans,
    required this.hole,
    this.angles = _flat,
  });

  static const _flat = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];

  /// 傾けられる範囲（度）。
  static const maxAngle = 90.0;

  /// 最初の並び（ユーザーが決めた配置）。
  static const standard = SoulPlacement(
    cans: [
      Offset(1.000, 0.255),
      Offset(0.060, 0.349),
      Offset(0.967, 0.440),
      Offset(0.055, 0.540),
      Offset(0.989, 0.628),
      Offset(0.031, 0.715),
    ],
    hole: Offset(0.488, 0.869),
    angles: [-25.0, 25.0, -25.0, 25.0, -25.0, 25.0],
  );

  /// 1〜6番の缶。
  final List<Offset> cans;

  /// 最後に魂が入る空き缶。
  final Offset hole;

  /// 1〜6番の缶の傾き（度）。
  final List<double> angles;

  Offset can(int hop) => cans[hop - 1];

  double angle(int hop) => angles[hop - 1];

  SoulPlacement withCan(int hop, Offset position) => SoulPlacement(
    cans: [
      for (var i = 0; i < cans.length; i++) i == hop - 1 ? position : cans[i],
    ],
    hole: hole,
    angles: angles,
  );

  SoulPlacement withHole(Offset position) =>
      SoulPlacement(cans: cans, hole: position, angles: angles);

  SoulPlacement withAngle(int hop, double degrees) => SoulPlacement(
    cans: cans,
    hole: hole,
    angles: [
      for (var i = 0; i < angles.length; i++)
        i == hop - 1 ? degrees.clamp(-maxAngle, maxAngle) : angles[i],
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is SoulPlacement &&
      listEquals(other.cans, cans) &&
      other.hole == hole &&
      listEquals(other.angles, angles);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(cans), hole, Object.hashAll(angles));
}
