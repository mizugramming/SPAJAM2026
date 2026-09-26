import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../duel/sea_background.dart';
import 'soul_course.dart';
import 'soul_placement.dart';

/// 魂の描画位置・大きさ・透明度。
@immutable
class SoulPose {
  const SoulPose(this.center, {this.scale = 1, this.opacity = 1});

  final Offset center;
  final double scale;
  final double opacity;
}

/// 盤面の寸法と [SoulPlacement] から、缶・穴・魂の位置を決める。
///
/// 奇数番の缶があなた、偶数番の缶が相方。魂は1番から順に運ばれ、最後は空き缶へ入る。
/// 缶は配置が画面の端を越えていても、盤面の内側に収める。
class SoulLayout {
  SoulLayout(this.size, [this.placement = SoulPlacement.standard]);

  final Size size;
  final SoulPlacement placement;

  /// 魂の画像は 1345×1169。
  static const soulAspect = 1345 / 1169;

  double get soulHeight => min(size.width * 0.17, 72.0);
  double get soulWidth => soulHeight * soulAspect;

  /// tunakanaka.png の絵の部分（周りの透明な余白を除く）。
  static const canContent = Rect.fromLTRB(92, 536, 1156, 1168);

  /// hadakan.png の絵の部分。
  static const holeContent = Rect.fromLTRB(84, 68, 1444, 916);

  double get canWidth => min(size.width * 0.22, 88.0);
  double get canHeight => canWidth * canContent.height / canContent.width;

  /// 魂が飛ぶ弧の高さ。
  double get arcHeight => size.height * 0.07;

  /// 海（砂地の上端あたり）。魂はここを越えて沈む。
  double get seaY => size.height * 0.9;

  /// 最後の空き缶（hadakan）。
  double get holeWidth => min(size.width * 0.3, 120.0);
  double get holeHeight => holeWidth * holeContent.height / holeContent.width;
  double get holeTop =>
      _clamp(size.height * placement.hole.dy, 0, size.height - holeHeight);
  Offset get holeCenter => Offset(
    _clamp(
      size.width * placement.hole.dx,
      holeWidth / 2,
      size.width - holeWidth / 2,
    ),
    holeTop + holeHeight / 2,
  );

  /// [hop]番の缶の中心のx。
  double canX(int hop) => _clamp(
    size.width * placement.can(hop).dx,
    canWidth / 2,
    size.width - canWidth / 2,
  );

  /// [hop]番の缶の上端のy。
  double canTop(int hop) =>
      _clamp(size.height * placement.can(hop).dy, 0, size.height - canHeight);

  /// 画面がとても小さく範囲が逆転するときも、例外にせず下限を使う。
  static double _clamp(double value, double low, double high) =>
      high < low ? low : value.clamp(low, high);

  /// [hop]番の缶の傾き（ラジアン、時計回りが正）。缶は中心で回す。
  double canRadians(int hop) => placement.angle(hop) * pi / 180;

  /// 缶の中心から [local] だけ離れた点を、缶の傾きに合わせて回した位置。
  Offset _onCan(int hop, Offset local) {
    final center = Offset(canX(hop), canTop(hop) + canHeight / 2);
    final a = canRadians(hop);
    return center +
        Offset(
          local.dx * cos(a) - local.dy * sin(a),
          local.dx * sin(a) + local.dy * cos(a),
        );
  }

  /// 缶のふたの中央。傾けると一緒に回る。タップの目印の輪もここに出す。
  Offset lid(int hop) => _onCan(hop, Offset(0, -canHeight / 2));

  /// 缶の上に乗った魂の中心。傾けた缶では、ふたの向きに乗る。
  Offset standing(int hop) =>
      _onCan(hop, Offset(0, -canHeight / 2 - soulHeight * 0.4));

  /// 放す前に待つ位置。ここから最初の缶へ降りる。
  Offset get dropStart => Offset(canX(1), size.height * 0.10);

  /// 空き缶のふたの上。魂はここで小さくなって缶の中へ入る。
  Offset get holePoint =>
      Offset(holeCenter.dx, holeTop + holeHeight * 0.12 - soulHeight * 0.2);

  /// 時刻 [t] に、予定どおり飛んだときの魂の中心。
  Offset pathPoint(SoulRun run, Duration t) {
    if (t <= Duration.zero) return dropStart;
    final first = run.arrival(1);
    if (t < first) {
      final s = t.inMicroseconds / first.inMicroseconds;
      return Offset.lerp(dropStart, standing(1), s * s)!;
    }
    for (var hop = 1; hop <= SoulRun.hops; hop++) {
      final start = run.arrival(hop);
      final end = start + run.level.flight;
      if (t >= end) continue;
      final s = (t - start).inMicroseconds / run.level.flight.inMicroseconds;
      final to = hop < SoulRun.hops ? standing(hop + 1) : holePoint;
      return Offset.lerp(
        standing(hop),
        to,
        s,
      )!.translate(0, -arcHeight * 4 * s * (1 - s));
    }
    return holePoint;
  }

  /// 時刻 [t] の魂の姿。落ちたら落ちた場所から海へ、穴に着いたら小さくなる。
  SoulPose poseAt(SoulRun run, Duration t) {
    if (run.status == SoulStatus.fell && t > run.failedAt!) {
      final failedAt = run.failedAt!;
      final origin = pathPoint(run, failedAt);
      final progress =
          ((t - failedAt).inMicroseconds / SoulTiming.fall.inMicroseconds)
              .clamp(0.0, 1.0);
      final end = seaY + soulHeight * 0.4;
      final y = origin.dy + (end - origin.dy) * progress * progress;
      final opacity = y <= seaY ? 1.0 : (1 - (y - seaY) / (end - seaY));
      return SoulPose(Offset(origin.dx, y), opacity: opacity.clamp(0.0, 1.0));
    }
    final sink =
        ((t - run.holeArrival).inMicroseconds /
                SoulTiming.holeSink.inMicroseconds)
            .clamp(0.0, 1.0);
    return SoulPose(pathPoint(run, t), scale: 1 - sink, opacity: 1 - sink);
  }
}

/// 協力ゲームの盤面。背景・缶・穴・魂・タップの目印を描く。状態は持たない。
class SoulStage extends StatelessWidget {
  const SoulStage({
    super.key,
    required this.team,
    required this.selfName,
    required this.peerName,
    required this.run,
    required this.runTime,
    required this.elapsed,
    this.flashText,
    this.flashHop = 1,
    this.placement = SoulPlacement.standard,
  });

  final Team team;

  /// 缶と空き缶の置き場所。
  final SoulPlacement placement;
  final String selfName;
  final String peerName;
  final SoulRun run;

  /// 魂を放してからの経過時間。放す前は0以下。
  final Duration runTime;

  /// 背景のゆれに使うゲーム時計。止まっているときは動かない。
  final Duration elapsed;

  /// 運べたときに缶の近くへ出す短い言葉と、その缶。
  final String? flashText;
  final int flashHop;

  @override
  Widget build(BuildContext context) {
    final teamColor = switch (team) {
      Team.red => const Color(0xFFB83F40),
      Team.blue => const Color(0xFF286CA8),
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = SoulLayout(constraints.biggest, placement);
        final pose = layout.poseAt(run, runTime);
        final ring = _ring(layout);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: SeaBackground(elapsed: elapsed)),
            _Hole(layout: layout),
            for (var hop = 1; hop <= SoulRun.hops; hop++)
              _Can(layout: layout, hop: hop),
            _NameTag(
              left: layout.canX(1) - 40,
              top: layout.canTop(1) + layout.canHeight + 4,
              label: selfName,
              color: teamColor,
            ),
            _NameTag(
              left: layout.canX(2) - 40,
              top: layout.canTop(2) + layout.canHeight + 4,
              label: peerName,
              color: teamColor,
            ),
            ?ring,
            Positioned(
              left: pose.center.dx - layout.soulWidth / 2,
              top: pose.center.dy - layout.soulHeight / 2,
              width: layout.soulWidth,
              height: layout.soulHeight,
              child: Opacity(
                opacity: pose.opacity,
                child: Transform.scale(
                  scale: pose.scale,
                  // 読み込みに失敗したら例外が出て気づけるよう、代わりの表示は付けない。
                  child: Image.asset(
                    soulAsset,
                    cacheWidth: 320,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
            if (flashText != null)
              Positioned(
                // 端の缶でも画面の外へはみ出さないようにする。
                left: (layout.canX(flashHop) - 60).clamp(
                  0.0,
                  max(0.0, layout.size.width - 120),
                ),
                width: 120,
                top: layout.canTop(flashHop) - layout.soulHeight * 1.5,
                child: Text(
                  flashText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFE07B00),
                  ),
                ),
              ),
            if (run.status == SoulStatus.fell &&
                runTime >= run.failedAt! + SoulTiming.fall)
              Positioned(
                left: 0,
                right: 0,
                top: layout.seaY - 34,
                child: const Text(
                  'ボチャン！',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFB83F40),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static const soulAsset = 'assets/characters/tamashii.png';
  static const canAsset = 'assets/characters/tunakanaka.png';
  static const holeAsset = 'assets/characters/hadakan.png';

  /// 次に自分が押す缶の目印。輪が缶へ縮み、幅に入ると緑になる。
  Widget? _ring(SoulLayout layout) {
    final hop = run.nextHop;
    if (run.status != SoulStatus.flying ||
        hop > SoulRun.lastSelfHop ||
        !run.isSelfHop(hop)) {
      return null;
    }
    final arrival = run.arrival(hop);
    final start = arrival - run.level.flight;
    if (runTime < start) return null;
    final progress =
        ((runTime - start).inMicroseconds / run.level.flight.inMicroseconds)
            .clamp(0.0, 1.0);
    final radius = layout.canWidth * (1.5 - progress);
    final inWindow = (runTime - arrival).abs() <= run.level.window;
    final color = inWindow ? const Color(0xFF2E9E5B) : const Color(0xFFFF9800);
    final lid = layout.lid(hop);
    return Positioned(
      key: const Key('soul-ring'),
      left: lid.dx - radius,
      top: lid.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 4),
          ),
        ),
      ),
    );
  }
}

/// 画像の余白を除いた絵の部分（[content]、画像のピクセル座標）が、置き場所の箱に
/// ちょうど重なるように描く。元の画像ファイルは加工しない。
class _CroppedAsset extends StatelessWidget {
  const _CroppedAsset({
    required this.asset,
    required this.imageSize,
    required this.content,
  });

  final String asset;
  final Size imageSize;
  final Rect content;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = box.maxWidth / content.width;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -content.left * scale,
            top: -content.top * scale,
            width: imageSize.width * scale,
            height: imageSize.height * scale,
            // 読み込みに失敗したら例外が出て気づけるよう、代わりの表示は付けない。
            child: Image.asset(
              asset,
              fit: BoxFit.fill,
              cacheWidth: 400,
              excludeFromSemantics: true,
            ),
          ),
        ],
      );
    },
  );
}

/// 魂を運ぶツナ缶（tunakanaka、1254×1254）。
class _Can extends StatelessWidget {
  const _Can({required this.layout, required this.hop});

  final SoulLayout layout;
  final int hop;

  @override
  Widget build(BuildContext context) => Positioned(
    key: Key('soul-can-$hop'),
    left: layout.canX(hop) - layout.canWidth / 2,
    top: layout.canTop(hop),
    width: layout.canWidth,
    height: layout.canHeight,
    child: Transform.rotate(
      angle: layout.canRadians(hop),
      child: const SoulCanImage(),
    ),
  );
}

/// ツナ缶の絵。置き場所の箱いっぱいに描く。
class SoulCanImage extends StatelessWidget {
  const SoulCanImage({super.key});

  @override
  Widget build(BuildContext context) => const _CroppedAsset(
    asset: SoulStage.canAsset,
    imageSize: Size(1254, 1254),
    content: SoulLayout.canContent,
  );
}

/// 空き缶の絵。置き場所の箱いっぱいに描く。
class SoulHoleImage extends StatelessWidget {
  const SoulHoleImage({super.key});

  @override
  Widget build(BuildContext context) => const _CroppedAsset(
    asset: SoulStage.holeAsset,
    imageSize: Size(1518, 1036),
    content: SoulLayout.holeContent,
  );
}

/// 最後に魂が入る空の缶（hadakan、1518×1036）。
class _Hole extends StatelessWidget {
  const _Hole({required this.layout});

  final SoulLayout layout;

  @override
  Widget build(BuildContext context) => Positioned(
    key: const Key('soul-hole'),
    left: layout.holeCenter.dx - layout.holeWidth / 2,
    top: layout.holeTop,
    width: layout.holeWidth,
    height: layout.holeHeight,
    child: const SoulHoleImage(),
  );
}

class _NameTag extends StatelessWidget {
  const _NameTag({
    required this.left,
    required this.top,
    required this.label,
    required this.color,
  });

  final double left;
  final double top;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: 80,
    child: Center(
      child: DecoratedBox(
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
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    ),
  );
}
