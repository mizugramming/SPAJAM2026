import 'dart:math';

import 'package:flutter/material.dart';

/// ゲームの背景（缶の内側と砂地）。対戦・協力と、ゲーム画面の上部の帯で共用する。
///
/// 2枚を交互にクロスフェードして、缶の内側をゆらす。
/// 時刻は親のゲーム時計から受け取り、この部品はタイマーもTickerも持たない。
/// 時計が止まっている間（スタート待ちなど）は画面の更新を要求しない。
///
/// 絵は置き場所の幅に合わせて拡大し、下端（砂地）をそろえて置く。高さには
/// 左右されないので、幅と下端が同じ場所どうし（ゲームの領域と、その上の帯を
/// 含む画面全体）では、同じ絵が同じ位置に出て、境目でずれない。絵より高い
/// 場所では、上の余りを絵の上端の色で塗る。
class SeaBackground extends StatelessWidget {
  const SeaBackground({super.key, required this.elapsed});

  static const assetA = 'assets/characters/tunaumi1.png';
  static const assetB = 'assets/characters/tunaumi2.png';

  /// 絵の上端あたりの色。絵が届かない上の余りを塗る。
  static const topColor = Color(0xFFE2E9F1);

  /// 1枚目から2枚目へ移り、1枚目へ戻るまでの一周の長さ。
  static const cycle = Duration(seconds: 3);

  /// ゲーム時計の経過時間。
  final Duration elapsed;

  /// 2枚目の見える度合い。0で1枚目だけ、1で2枚目だけ、なめらかに往復する。
  static double mixAt(Duration elapsed) {
    if (elapsed <= Duration.zero) return 0;
    final turns = elapsed.inMicroseconds / cycle.inMicroseconds;
    return (1 - cos(2 * pi * turns)) / 2;
  }

  @override
  Widget build(BuildContext context) {
    // 動きは装飾なので、OSの「アニメーションを減らす」設定では止める。
    final mix = MediaQuery.disableAnimationsOf(context) ? 0.0 : mixAt(elapsed);
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: topColor),
        const _SeaImage(asset: assetA),
        _SeaImage(asset: assetB, opacity: AlwaysStoppedAnimation(mix)),
      ],
    );
  }
}

class _SeaImage extends StatelessWidget {
  const _SeaImage({required this.asset, this.opacity});

  final String asset;
  final Animation<double>? opacity;

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    opacity: opacity,
    // 幅に合わせ、砂地を常に下端へ置く。高い絵は上を切る。
    fit: BoxFit.fitWidth,
    alignment: Alignment.bottomCenter,
    // 読み込みに失敗したら例外が出て気づけるよう、代わりの表示は付けない。
    excludeFromSemantics: true,
  );
}
