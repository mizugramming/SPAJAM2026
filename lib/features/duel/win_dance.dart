import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 対戦に勝ったとき、結果画面の前に出す場面。煙の中から親方が現れて踊る。
///
/// 時刻は親のゲーム時計から受け取り、この部品はタイマーを持たない。
/// 踊りはアニメーション WebP（依存パッケージなしで Image が再生する）。
/// 「アニメーションを減らす」設定では、踊らない1枚絵を出し、煙も揺らさない。
class WinDance extends StatelessWidget {
  const WinDance({super.key, required this.elapsed});

  static const danceAsset = 'assets/characters/oyakata_dance.webp';
  static const stillAsset = 'assets/characters/oyakata_dance_still.png';

  /// 煙が広がり、親方が現れるまでの時間。
  static const appear = Duration(milliseconds: 600);

  /// 踊り始めてからの経過時間。
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final t = (elapsed.inMicroseconds / appear.inMicroseconds).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.shortestSide * .8;
        return Stack(
          key: const Key('win-dance'),
          alignment: Alignment.center,
          children: [
            // 親方の後ろの、煙のような半透明の白。
            IgnorePointer(
              child: CustomPaint(
                key: const Key('dance-smoke'),
                size: Size.square(size * 1.3),
                painter: _SmokePainter(
                  spread: Curves.easeOutCubic.transform(t),
                  drift: reduceMotion ? 0 : elapsed.inMilliseconds / 1000,
                ),
              ),
            ),
            Opacity(
              opacity: Curves.easeIn.transform(t),
              child: Transform.scale(
                scale: .85 + .15 * Curves.easeOutBack.transform(t),
                child: Image.asset(
                  reduceMotion ? stillAsset : danceAsset,
                  key: const Key('oyakata-dance'),
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  semanticLabel: '踊る親方',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ぼかした白い円を重ねた煙。[spread] 0〜1 で中心から広がり、[drift]（秒）で
/// ゆっくり揺らぐ。
class _SmokePainter extends CustomPainter {
  _SmokePainter({required this.spread, required this.drift});

  final double spread;
  final double drift;

  /// 円の中心の方向（周の割合）・距離・大きさ。
  static const _puffs = [
    (angle: 0.00, distance: .00, radius: .34),
    (angle: 0.08, distance: .26, radius: .22),
    (angle: 0.22, distance: .30, radius: .20),
    (angle: 0.38, distance: .27, radius: .23),
    (angle: 0.52, distance: .30, radius: .19),
    (angle: 0.66, distance: .26, radius: .22),
    (angle: 0.80, distance: .31, radius: .20),
    (angle: 0.93, distance: .24, radius: .21),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (spread <= 0) return;
    final center = size.center(Offset.zero);
    final unit = size.shortestSide;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .55 * spread)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * .05);
    for (var i = 0; i < _puffs.length; i++) {
      final puff = _puffs[i];
      final wobble = math.sin(drift * 2.2 + i) * .02;
      final angle = puff.angle * 2 * math.pi + drift * .15;
      final distance = (puff.distance + wobble) * spread * unit;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        (puff.radius + wobble) * (.4 + .6 * spread) * unit,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) =>
      old.spread != spread || old.drift != drift;
}
