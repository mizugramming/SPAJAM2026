import 'dart:math';

import 'package:flutter/material.dart';

/// 対戦ゲームの背景。
///
/// ツナ海の2枚（砂地の波線の位置だけが違う）を交互にクロスフェードして、海底をゆらす。
/// 時刻は親のゲーム時計から受け取り、この部品はタイマーもTickerも持たない。
/// 時計が止まっている間（スタート待ちなど）は画面の更新を要求しない。
class SeaBackground extends StatelessWidget {
  const SeaBackground({super.key, required this.elapsed});

  static const assetA = 'assets/characters/tunaumi1.png';
  static const assetB = 'assets/characters/tunaumi2.png';

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
    fit: BoxFit.cover,
    // 砂地を常に下端へ置き、縦横比が違うときは上と左右だけを切る。
    alignment: Alignment.bottomCenter,
    // 読み込みに失敗したら例外が出て気づけるよう、代わりの表示は付けない。
    excludeFromSemantics: true,
  );
}
