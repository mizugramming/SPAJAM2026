import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import 'race_course.dart';
import 'sea_background.dart';

/// 対戦の盤面。背景・アウトの線・吊られた2体の魚を描く。
///
/// 状態は持たず、深さや結果は親から受け取る。ゲームの進行は `DuelGame` が担当する。
class RaceField extends StatelessWidget {
  const RaceField({
    super.key,
    required this.self,
    required this.peer,
    required this.selfDepth,
    required this.peerDepth,
    this.elapsed = Duration.zero,
    this.selfDecision,
    this.peerDecision,
    this.selfWins,
    this.landingRatio = defaultLandingRatio,
  });

  /// アウトの線の高さ。盤面の高さに対する割合（0が上端、1が下端）。
  ///
  /// 魚の口先がこの線へ届くと、海へ落ちたことになる。位置はユーザーが決めた値。
  static const defaultLandingRatio = 0.894;

  /// 描画する深さの上限（線を越えて海の中）。
  static const maxDepth = 1.4;

  final Participant self;
  final Participant peer;

  /// 0は吊り始め、1は魚の口先が線に付いた位置、1より大きいと線を越えている。
  final double selfDepth;
  final double peerDepth;

  /// 背景のゆれに使うゲーム時計。止まっているときは動かない。
  final Duration elapsed;

  /// 止まった／落ちた後だけ、その列の上部に結果を出す。
  final RaceDecision? selfDecision;
  final RaceDecision? peerDecision;

  /// 自分が勝ったか。両者が決まるまでは null。
  final bool? selfWins;

  final double landingRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _RaceLayout(
          constraints.biggest,
          landingRatio: landingRatio,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: SeaBackground(elapsed: elapsed)),
            _LandingLine(layout: layout),
            _Racer(
              layout: layout,
              isSelf: true,
              participant: self,
              depth: selfDepth,
            ),
            _Racer(
              layout: layout,
              isSelf: false,
              participant: peer,
              depth: peerDepth,
            ),
            if (selfDecision case final decision?)
              _ResultPanel(
                layout: layout,
                isSelf: true,
                decision: decision,
                wins: selfWins,
              ),
            if (peerDecision case final decision?)
              _ResultPanel(
                layout: layout,
                isSelf: false,
                decision: decision,
                // 両方落ちたときは、どちらも LOSE。
                wins: selfWins == null
                    ? null
                    : !selfWins! && !(selfDecision!.fell && decision.fell),
              ),
          ],
        );
      },
    );
  }
}

/// 吊られた魚の画像（hikareruaka / hikareruao、どちらも1024×1536）の寸法。
///
/// 上端から綱が伸び、逆さの魚が下に吊られている。魚の口先が着地の位置。
abstract final class _Sprite {
  static const width = 1024.0;
  static const height = 1536.0;

  /// 綱の中心のx。
  static const ropeX = 510.0;

  /// 魚の上端（尾びれ）と、魚の口先のy。
  static const fishTop = 1160.0;
  static const fishBottom = 1496.0;
  static const fishHeight = fishBottom - fishTop;

  /// 魚の幅（ひれを含む）。
  static const fishWidth = 222.0;

  /// 上端からこの高さまでは綱だけが描かれている。綱を継ぎ足すときに使う。
  static const ropeOnlyHeight = 1000.0;

  static String assetFor(Team team) => switch (team) {
    Team.red => 'assets/characters/hikareruaka.png',
    Team.blue => 'assets/characters/hikareruao.png',
  };
}

/// 画面サイズから各要素の位置を決める。上部の情報表示の領域は避ける。
class _RaceLayout {
  _RaceLayout(this.size, {required this.landingRatio});

  final Size size;

  final double landingRatio;

  /// 魚の幅の目安。
  double get characterSize => min(size.width * 0.24, 96.0);

  /// 上部の共通情報表示の下から開始する。
  double get startY => 78;

  /// 着地の線。深さ1で魚の口先がここに付く。
  /// 低い画面でも、吊り始めの魚の下に落ちる距離が残るようにする。
  double get landingY {
    final fishHeight = _Sprite.fishHeight * (characterSize / _Sprite.fishWidth);
    return max(size.height * landingRatio, startY + fishHeight + 60);
  }

  /// 自分は左、相手は右で固定し、常に見分けられるようにする。
  double laneX(bool isSelf) => size.width * (isSelf ? 0.26 : 0.74);

  /// 画像の拡大率。魚の幅を [characterSize] に合わせる。線の位置では変えない。
  /// 綱が画面の上端まで届かないときは、[_Racer] が綱を継ぎ足す。
  double get spriteScale => characterSize / _Sprite.fishWidth;

  /// 深さ0で魚の上端が [startY]、深さ1で口先が [landingY] に来る、口先のy。
  double fishBottomY(double depth) {
    final startBottom = startY + _Sprite.fishHeight * spriteScale;
    return startBottom + depth * (landingY - startBottom);
  }
}

/// アウトの線。魚の口先がここへ届いたら落ちたことになる。
class _LandingLine extends StatelessWidget {
  const _LandingLine({required this.layout});

  final _RaceLayout layout;

  static const thickness = 4.0;

  @override
  Widget build(BuildContext context) => Positioned(
    key: const Key('landing-line'),
    left: 0,
    right: 0,
    top: layout.landingY - thickness / 2,
    height: thickness,
    child: const ColoredBox(color: Color(0xFFD9483B)),
  );
}

class _Racer extends StatelessWidget {
  const _Racer({
    required this.layout,
    required this.isSelf,
    required this.participant,
    required this.depth,
  });

  final _RaceLayout layout;
  final bool isSelf;
  final Participant participant;
  final double depth;

  @override
  Widget build(BuildContext context) {
    final size = layout.characterSize;
    final scale = layout.spriteScale;
    final laneX = layout.laneX(isSelf);
    final bottom = layout.fishBottomY(depth);
    final fishTop = bottom - _Sprite.fishHeight * scale;
    final teamColor = switch (participant.team) {
      Team.red => const Color(0xFFB83F40),
      Team.blue => const Color(0xFF286CA8),
    };
    final nickname = participant.profile.nickname;
    final asset = _Sprite.assetFor(participant.team);
    final spriteLeft = laneX - _Sprite.ropeX * scale;
    final spriteTop = bottom - _Sprite.fishBottom * scale;
    final spriteWidth = _Sprite.width * scale;
    final spriteHeight = _Sprite.height * scale;
    // 画像の綱が画面の上端まで届かない分は、同じ画像の綱の部分を上へ継ぎ足す。
    final ropeTile = _Sprite.ropeOnlyHeight * scale;
    final ropeTiles = spriteTop > 0 ? (spriteTop / ropeTile).ceil() : 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (ropeTiles > 0)
          Positioned(
            left: spriteLeft,
            // 継ぎ目に隙間ができないよう、画像と1px重ねる。
            top: spriteTop + 1 - ropeTiles * ropeTile,
            width: spriteWidth,
            height: ropeTiles * ropeTile,
            child: Column(
              children: [
                for (var i = 0; i < ropeTiles; i++)
                  SizedBox(
                    height: ropeTile,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: spriteHeight,
                        maxHeight: spriteHeight,
                        child: Image.asset(
                          asset,
                          key: const Key('rope-segment'),
                          width: spriteWidth,
                          height: spriteHeight,
                          fit: BoxFit.fill,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          left: spriteLeft,
          top: spriteTop,
          width: spriteWidth,
          height: spriteHeight,
          // 読み込みに失敗したら例外が出て気づけるよう、代わりの表示は付けない。
          child: Image.asset(
            asset,
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        Positioned(
          left: laneX - size,
          width: size * 2,
          top: fishTop - 26,
          child: Center(
            child: _NameTag(label: isSelf ? 'あなた' : nickname, color: teamColor),
          ),
        ),
      ],
    );
  }
}

/// 列の上部に出す結果。止まった／落ちたらぎりぎり度を大きく出し、
/// 勝敗が決まったらその上に WIN / LOSE を出す。
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.layout,
    required this.isSelf,
    required this.decision,
    required this.wins,
  });

  final _RaceLayout layout;
  final bool isSelf;
  final RaceDecision decision;

  /// 勝敗が決まるまでは null。
  final bool? wins;

  static const _win = Color(0xFFE08A00);
  static const _lose = Color(0xFF5C6B78);
  static const _fell = Color(0xFFB83F40);

  @override
  Widget build(BuildContext context) {
    final width = layout.size.width * 0.44;
    final wins = this.wins;
    return Positioned(
      key: Key(isSelf ? 'result-self' : 'result-peer'),
      left: layout.laneX(isSelf) - width / 2,
      top: layout.startY - 6,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            // 文字拡大でも列の幅に収まるよう、はみ出す前に縮小する。
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (wins != null)
                    Text(
                      wins ? 'WIN' : 'LOSE',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: wins ? _win : _lose,
                      ),
                    ),
                  Text(
                    decision.fell ? 'ボチャン！' : '${decision.closeness}%',
                    style: TextStyle(
                      fontSize: decision.fell ? 30 : 52,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: decision.fell ? _fell : const Color(0xFF304D46),
                    ),
                  ),
                  Text(
                    decision.fell ? '線を越えた' : 'ぎりぎり度',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5C7772),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ),
  );
}
