import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/models.dart';
import 'race_course.dart';
import 'race_field.dart';

/// 自分（self）から見た対戦結果。
enum DuelGameResult { win, loss }

/// シーチキンレース。
///
/// 最初のタップでスタートし、self と peer が綱に吊られたまま、下の海へ向かって加速しながら落ちていく。
/// 次のタップで自分だけ止まり、アウトの線の手前ぎりぎりで止めるほど勝ち。線を越えると海に落ちて負け。
/// スタートするまでは時計も背景も動かさない。
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
  static const _settleDelay = Duration(milliseconds: 1800);

  late final Ticker _ticker;
  late final RaceCourse _course;
  late final RaceDecision _peerDecision;

  Duration _elapsed = Duration.zero;
  bool _started = false;
  RaceDecision? _selfDecision;
  Duration? _bothSettledAt;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _course =
        widget.debugCourse ?? RaceCourse.seeded(Random().nextInt(1 << 31));
    _peerDecision = widget.debugPeerDecision ?? _randomPeerDecision();
    // 最初のタップまで開始しない。親の再描画では作り直さない。
    _ticker = createTicker(_onTick);
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
    if (!_started) {
      // 最初のタップは開始だけ。落下も背景もここから動く。
      setState(() => _started = true);
      _ticker.start();
      return;
    }
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
    if (decision.fell) return min(raw, RaceField.maxDepth);
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
          builder: (context, constraints) => Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: RaceField(
                  self: widget.self,
                  peer: widget.peer,
                  elapsed: _elapsed,
                  selfDepth: selfDepth,
                  peerDepth: peerDepth,
                  selfDecision: selfDecision,
                  peerDecision: peerSettled ? _peerDecision : null,
                  selfWins: selfDecision != null && peerSettled
                      ? selfWinsRace(selfDecision, _peerDecision)
                      : null,
                ),
              ),
              // 遊び方の説明。スタート前は中央に大きく出し、最初のタップで消す。
              // 吊られた魚（上）とアウトの線（下）の間の空いた所に、枠に合わせて縮めて出す。
              Positioned(
                left: 16,
                right: 16,
                top: constraints.maxHeight * 0.3,
                height: constraints.maxHeight * 0.4,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    key: const Key('duel-guide'),
                    opacity: _started ? 0 : 1,
                    duration: const Duration(milliseconds: 400),
                    child: const _StartGuide(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// スタート前に中央へ大きく出す遊び方。
///
/// 見出しは幅に入りきらないときだけ縮め、説明は大きい文字のまま枠の幅で折り返す。
/// 文字拡大などで縦に入りきらないときだけ、全体を縮める。
class _StartGuide extends StatelessWidget {
  const _StartGuide();

  static const _color = Color(0xFF304D46);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: box.maxWidth,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'タップでスタート！',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: _color,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                '魚がいっしょに落ちはじめる。\n赤い線のぎりぎりで、もう一度タップして止めよう！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.35,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
