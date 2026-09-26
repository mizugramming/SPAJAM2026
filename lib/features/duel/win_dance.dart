import 'package:flutter/material.dart';

/// 対戦に勝ったとき、結果画面の前に出す場面。子分が光って親方に変わり、踊る。
///
/// 時刻は親のゲーム時計から受け取り、この部品はタイマーを持たない。
/// 踊りはアニメーション WebP（依存パッケージなしで Image が再生する）。
/// 「アニメーションを減らす」設定では、踊らない1枚絵を出す。
class WinDance extends StatelessWidget {
  const WinDance({super.key, required this.elapsed});

  static const followerAsset = 'assets/characters/kobun_normal.png';
  static const danceAsset = 'assets/characters/oyakata_dance.webp';
  static const stillAsset = 'assets/characters/oyakata_dance_still.png';

  /// 子分が親方に変わるまでの時間。
  static const change = Duration(milliseconds: 700);

  /// 踊り始めてからの経過時間。
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final t = (elapsed.inMicroseconds / change.inMicroseconds).clamp(0.0, 1.0);
    // 前半で子分がふくらんで光り、後半で親方に入れ替わる。
    final grow = Curves.easeOut.transform(t);
    final flash = (1 - (t - .5).abs() * 2).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide * .8;
        return Stack(
          key: const Key('win-dance'),
          alignment: Alignment.center,
          children: [
            // 背景の上に薄く白を重ね、踊りを主役にする。
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: .45)),
            ),
            Positioned(
              top: box.maxHeight * .08,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: t,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '親方になった！',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE08A00),
                    ),
                  ),
                ),
              ),
            ),
            if (t < 1)
              Opacity(
                opacity: 1 - Curves.easeIn.transform(t),
                child: Transform.scale(
                  scale: .6 + .5 * grow,
                  child: Image.asset(
                    followerAsset,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            Opacity(
              opacity: Curves.easeIn.transform(t),
              child: Image.asset(
                reduceMotion ? stillAsset : danceAsset,
                key: const Key('oyakata-dance'),
                width: size,
                height: size,
                fit: BoxFit.contain,
                semanticLabel: '踊る親方',
              ),
            ),
            // 入れ替わる瞬間の光。
            IgnorePointer(
              child: Container(
                width: size * 1.1,
                height: size * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFF4C2).withValues(alpha: .9 * flash),
                      const Color(0x00FFF4C2),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
