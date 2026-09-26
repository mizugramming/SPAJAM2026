import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/models.dart';
import 'race_course.dart';

/// 自分（self）から見た対戦結果。
enum DuelGameResult { win, loss }

/// シーチキンレース。
///
/// self と peer が綱に吊られたまま、シーチキン缶へ向かって加速しながら落ちていく。
/// 画面タップで自分だけ止まり、缶のふちより手前で止めるほど勝ち。缶を越えると海に落ちて負け。
///
/// peer は一台デモの仮想相手で、この対戦の間だけ決める行動（[RaceDecision]）を
/// 開始時に一度作り、self と同じ時計に沿って画面上で「落ちて・止まる」様子を見せる。
/// 将来の実通信では、この決定を相手の端末から受け取る形に差し替えられる。
class DuelGame extends StatefulWidget {
  const DuelGame({
    super.key,
    required this.self,
    required this.peer,
    required this.onCompleted,
    @visibleForTesting this.debugCourse,
    @visibleForTesting this.debugPeerDecision,
  });

  final Participant self;
  final Participant peer;
  final ValueChanged<DuelGameResult> onCompleted;

  /// テストで落下時間を固定するための差し替え。本番では常に null。
  final RaceCourse? debugCourse;

  /// テストで仮想相手の行動を固定するための差し替え。本番では常に null。
  final RaceDecision? debugPeerDecision;

  @override
  State<DuelGame> createState() => _DuelGameState();
}

class _DuelGameState extends State<DuelGame>
    with SingleTickerProviderStateMixin {
  /// 両者が決まってから結果を通知するまでの間（落ちる／止まる様子を見せる）。
  static const _settleDelay = Duration(milliseconds: 900);

  /// 落ちたキャラを描画する深さの上限（缶を過ぎて海の中）。
  static const _maxVisualDepth = 1.4;

  late final Ticker _ticker;
  late final RaceCourse _course;
  late final RaceDecision _peerDecision;

  Duration _elapsed = Duration.zero;
  RaceDecision? _selfDecision;
  Duration? _bothSettledAt;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _course =
        widget.debugCourse ?? RaceCourse.seeded(Random().nextInt(1 << 31));
    _peerDecision = widget.debugPeerDecision ?? _randomPeerDecision();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  RaceDecision _randomPeerDecision() {
    final random = Random();
    // 4回に1回くらいは相手も落ちる。止まるときは、そこそこぎりぎりを狙う。
    if (random.nextDouble() < 0.25) return const RaceDecision.fell();
    return RaceDecision.stopped(0.7 + random.nextDouble() * 0.29);
  }

  bool _peerSettled(double raw) =>
      _peerDecision.fell ? raw >= 1 : raw >= _peerDecision.depth;

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    final raw = _course.depthAt(elapsed);

    if (_selfDecision == null && raw >= 1) {
      _selfDecision = const RaceDecision.fell();
    }

    final selfDecision = _selfDecision;
    if (selfDecision != null && _peerSettled(raw)) {
      final settledAt = _bothSettledAt ??= elapsed;
      if (!_reported && elapsed - settledAt >= _settleDelay) {
        _reported = true;
        widget.onCompleted(
          selfWinsRace(selfDecision, _peerDecision)
              ? DuelGameResult.win
              : DuelGameResult.loss,
        );
      }
    }
    setState(() {});
  }

  void _onTap() {
    if (_selfDecision != null) return;
    final raw = _course.depthAt(_elapsed);
    setState(
      () => _selfDecision = raw >= 1
          ? const RaceDecision.fell()
          : RaceDecision.stopped(raw.clamp(0.0, 1.0)),
    );
  }

  /// 描画用の深さ。決着済みなら止めた位置、または海へ向けて描き進める。
  double _visualDepth(RaceDecision decision, double raw) {
    if (decision.fell) return min(raw, _maxVisualDepth);
    return min(raw, decision.depth);
  }

  @override
  Widget build(BuildContext context) {
    final raw = _course.depthAt(_elapsed);
    final selfDecision = _selfDecision;
    final selfDepth = selfDecision == null
        ? min(raw, 1.0)
        : _visualDepth(selfDecision, raw);
    final peerDepth = _visualDepth(_peerDecision, raw);
    final peerSettled = _peerSettled(raw);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _onTap(),
      child: ColoredBox(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _RaceLayout(constraints.biggest);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                _SeaChickenCan(layout: layout),
                _Racer(
                  layout: layout,
                  isSelf: true,
                  participant: widget.self,
                  depth: selfDepth,
                  decision: selfDecision,
                ),
                _Racer(
                  layout: layout,
                  isSelf: false,
                  participant: widget.peer,
                  depth: peerDepth,
                  decision: peerSettled ? _peerDecision : null,
                ),
                if (selfDecision == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: layout.size.height * 0.06,
                    child: const Text(
                      'タップでストップ！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF304D46),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 画面サイズから各要素の位置を決める。上部の情報表示・右下の缶と親分の領域は避ける。
class _RaceLayout {
  _RaceLayout(this.size);

  final Size size;

  double get characterSize => min(size.width * 0.24, 96.0);

  /// 上部の共通情報表示の下から開始する。
  double get startY => 78;

  /// シーチキン缶の上面（深さ1でキャラの足元がここに付く）。
  double get canTop => size.height * 0.55;
  double get canHeight => min(size.height * 0.07, 46.0);
  double get canWidth => characterSize * 1.1;

  /// 自分は左、相手は右で固定し、常に見分けられるようにする。
  double laneX(bool isSelf) => size.width * (isSelf ? 0.26 : 0.74);

  double characterTop(double depth) => startY + depth * (canTop - startY);
}

class _SeaChickenCan extends StatelessWidget {
  const _SeaChickenCan({required this.layout});

  final _RaceLayout layout;

  @override
  Widget build(BuildContext context) => Positioned(
    left: layout.size.width / 2 - layout.canWidth / 2,
    top: layout.canTop,
    width: layout.canWidth,
    height: layout.canHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3E9E6),
        border: Border.all(color: const Color(0xFF9CB3AC), width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      // 文字拡大でも缶の枠内に収まるよう、はみ出す前に縮小する。
      child: const Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'シーチキン',
              maxLines: 1,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Racer extends StatelessWidget {
  const _Racer({
    required this.layout,
    required this.isSelf,
    required this.participant,
    required this.depth,
    required this.decision,
  });

  final _RaceLayout layout;
  final bool isSelf;
  final Participant participant;
  final double depth;

  /// 止まった／落ちた後だけ、結果のラベルを出す。
  final RaceDecision? decision;

  @override
  Widget build(BuildContext context) {
    final size = layout.characterSize;
    final laneX = layout.laneX(isSelf);
    final top = layout.characterTop(depth);
    final teamColor = switch (participant.team) {
      Team.red => const Color(0xFFB83F40),
      Team.blue => const Color(0xFF286CA8),
    };
    final nickname = participant.profile.nickname;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 綱。上端から頭まで。
        Positioned(
          left: laneX - 1.5,
          top: 0,
          width: 3,
          height: max(0.0, top),
          child: const ColoredBox(color: Color(0xFF8D6E63)),
        ),
        Positioned(
          left: laneX - size / 2,
          top: top,
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: teamColor,
              border: Border.all(
                color: isSelf ? const Color(0xFFFFC94D) : Colors.white,
                width: isSelf ? 4 : 2,
              ),
            ),
            child: Center(
              child: Text(
                nickname.isEmpty ? '?' : nickname.characters.first,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: laneX - size,
          width: size * 2,
          top: top - 26,
          child: Center(
            child: _NameTag(label: isSelf ? 'あなた' : nickname, color: teamColor),
          ),
        ),
        if (decision != null)
          Positioned(
            left: laneX - size,
            width: size * 2,
            top: top + size + 4,
            child: Center(
              child: Text(
                decision!.fell ? 'ボチャン！' : 'ぎりぎり度 ${decision!.closeness}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: decision!.fell
                      ? const Color(0xFFB83F40)
                      : const Color(0xFF304D46),
                ),
              ),
            ),
          ),
      ],
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
