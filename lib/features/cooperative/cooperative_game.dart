import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/models.dart';
import 'soul_course.dart';
import 'soul_stage.dart';

enum CooperativeGameResult { success, failure }

/// 魂を運ぶ協力ゲーム。
///
/// 復活の魂が上から降りてきて、両端のツナ缶へ右・左・右・左・右・左と運ばれ、最後に穴へ入る。
/// 魂が缶に着くタイミングで、右の缶はあなた、左の缶は相方が押して運ぶ。タイミングを
/// 外すと魂はツナの海へ落ちる。レベルは3つで、クリアすると1・2・3ptの魂ポイントを得る。
/// 途中で落ちても、そこまでに運んだレベルの魂ポイントは残る。3レベルすべて運べば成功。
///
/// 相方は一台デモの仮想の相手（[SoulPartner]）で、左の缶を自動で押す。将来の実通信では、
/// 相手の端末からのタップ時刻に差し替えられる。魂ポイントの蓄積・骨の子分の復活は
/// 共通の報酬側の担当で、このゲームは画面に得たポイントを見せるだけ（保存はしない）。
///
/// 最初のタップでスタートし、それまでは時計も背景も動かさない。
/// 結果が確定したら onCompleted を一度だけ呼ぶ。報酬・期限・画面遷移は親が担当する。
class CooperativeGame extends StatefulWidget {
  const CooperativeGame({
    super.key,
    required this.self,
    required this.peer,
    required this.onCompleted,
    @visibleForTesting this.debugPartnerOffsets,
  });

  final Participant self;
  final Participant peer;
  final ValueChanged<CooperativeGameResult> onCompleted;

  /// テストで相方の押す時刻を固定するための差し替え。本番では常に null。
  final PartnerOffsets? debugPartnerOffsets;

  @override
  State<CooperativeGame> createState() => _CooperativeGameState();
}

enum _Phase { waiting, intro, playing, falling, clearing, finished }

class _CooperativeGameState extends State<CooperativeGame>
    with SingleTickerProviderStateMixin {
  /// 運べたときの言葉を見せておく時間。
  static const _flashTime = Duration(milliseconds: 700);

  late final Ticker _ticker;
  final SoulPartner _partner = SoulPartner();

  Duration _elapsed = Duration.zero;
  _Phase _phase = _Phase.waiting;
  int _levelIndex = 0;
  int _points = 0;
  late SoulRun _run;

  /// 「レベルN」を出し始めた時刻、または最後の結果を出し始めた時刻。
  Duration _phaseStart = Duration.zero;

  /// 魂を放した時刻。
  Duration _runStart = Duration.zero;
  bool _success = false;
  bool _reported = false;

  String? _flashText;
  int _flashHop = 1;
  Duration _flashUntil = Duration.zero;

  SoulLevel get _level => SoulLevel.all[_levelIndex];
  Duration get _runTime => _elapsed - _runStart;

  @override
  void initState() {
    super.initState();
    _run = _newRun(0);
    // 最初のタップまで開始しない。親の再描画では作り直さない。
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  SoulRun _newRun(int levelIndex) {
    final level = SoulLevel.all[levelIndex];
    return SoulRun(
      level: level,
      partnerOffsets:
          widget.debugPartnerOffsets?.call(level) ?? _partner.offsetsFor(level),
    );
  }

  void _startIntro(int levelIndex) {
    _levelIndex = levelIndex;
    _run = _newRun(levelIndex);
    _phase = _Phase.intro;
    _phaseStart = _elapsed;
  }

  void _finish(bool success) {
    _success = success;
    _phase = _Phase.finished;
    _phaseStart = _elapsed;
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    switch (_phase) {
      case _Phase.waiting:
        break;
      case _Phase.intro:
        if (elapsed - _phaseStart >= SoulTiming.intro) {
          _runStart = elapsed;
          _phase = _Phase.playing;
        }
      case _Phase.playing:
        _run.advance(_runTime);
        _syncRunPhase();
      case _Phase.falling:
        if (_runTime >=
            _run.failedAt! + SoulTiming.fall + SoulTiming.fallLinger) {
          _finish(false);
        }
      case _Phase.clearing:
        if (_runTime >=
            _run.holeArrival + SoulTiming.holeSink + SoulTiming.clearLinger) {
          if (_levelIndex == SoulLevel.all.length - 1) {
            _finish(true);
          } else {
            _startIntro(_levelIndex + 1);
          }
        }
      case _Phase.finished:
        if (!_reported && elapsed - _phaseStart >= SoulTiming.finalPanel) {
          _reported = true;
          widget.onCompleted(
            _success
                ? CooperativeGameResult.success
                : CooperativeGameResult.failure,
          );
        }
    }
    setState(() {});
  }

  /// 魂が落ちた／穴に着いたら、次の場面へ移る。魂ポイントはクリアしたレベルの分だけ増える。
  void _syncRunPhase() {
    if (_run.status == SoulStatus.fell) {
      _phase = _Phase.falling;
    } else if (_run.status == SoulStatus.cleared) {
      _points += _level.points;
      _phase = _Phase.clearing;
    }
  }

  void _onTap() {
    switch (_phase) {
      case _Phase.waiting:
        // 最初のタップは開始だけ。時計も背景もここから動く。
        setState(() {
          _phase = _Phase.intro;
          _phaseStart = Duration.zero;
        });
        _ticker.start();
      case _Phase.playing:
        final result = _run.tap(_runTime);
        setState(() {
          if (result.kind == SoulTapKind.carried) {
            _flashText = result.just ? 'ジャスト！' : 'ナイス！';
            _flashHop = _run.carriedHops;
            _flashUntil = _elapsed + _flashTime;
          }
          _syncRunPhase();
        });
      case _Phase.intro:
      case _Phase.falling:
      case _Phase.clearing:
      case _Phase.finished:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showFlash = _flashText != null && _elapsed < _flashUntil;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _onTap(),
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Keep the status within the available width, and let its wrapped
                // height reserve space before the first soul/can instead of
                // covering them when the system text size is enlarged.
                Padding(
                  key: const Key('coop-status'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _Hud(
                    level: _level.number,
                    levelCount: SoulLevel.all.length,
                    points: _points,
                    carried: _run.carriedHops,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SizedBox.expand(
                      key: const Key('coop-playfield'),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: SoulStage(
                              team: widget.self.team,
                              selfName: 'あなた',
                              peerName: widget.peer.profile.nickname,
                              run: _run,
                              runTime:
                                  _phase == _Phase.waiting ||
                                      _phase == _Phase.intro
                                  ? Duration.zero
                                  : _runTime,
                              elapsed: _elapsed,
                              flashText: showFlash ? _flashText : null,
                              flashHop: _flashHop,
                            ),
                          ),
                          ..._overlays(constraints),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Brief feedback may cover the HUD, but never the shared header.
            // This keeps enlarged result text out of the smaller playfield.
            ..._feedback(),
          ],
        ),
      ),
    );
  }

  List<Widget> _overlays(BoxConstraints constraints) {
    // 両端の缶の列を避けた、中央の空いた幅。
    final side = SoulLayout(constraints.biggest).canWidth + 12;
    return [
      // 遊び方の説明。スタート前は中央に大きく出し、最初のタップで消す。
      Positioned(
        left: side,
        right: side,
        top: constraints.maxHeight * 0.25,
        height: constraints.maxHeight * 0.55,
        child: IgnorePointer(
          child: AnimatedOpacity(
            key: const Key('coop-guide'),
            opacity: _phase == _Phase.waiting ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: const _StartGuide(),
          ),
        ),
      ),
    ];
  }

  List<Widget> _feedback() => [
    if (_phase == _Phase.intro)
      _Banner(
        key: const Key('coop-intro'),
        title: 'レベル ${_level.number}',
        body: 'クリアで ${_level.points}pt',
      ),
    if (_phase == _Phase.clearing && _runTime >= _run.holeArrival)
      _Banner(
        key: const Key('coop-cleared'),
        title: 'レベルクリア！',
        body: '魂ポイント +${_level.points}pt',
      ),
    if (_phase == _Phase.finished)
      _Banner(
        key: const Key('coop-final'),
        title: _success ? 'ぜんぶ運べた！' : 'ざんねん…',
        body: '魂ポイント +$_points pt\n（ポイントの保存は、デモではまだ動きません）',
      ),
  ];
}

/// スタート前に中央へ大きく出す説明。
///
/// 両端の缶の列に挟まれて幅が狭いので、どちらも2行にする。
/// 幅や高さに入りきらないときだけ縮める。
class _StartGuide extends StatelessWidget {
  const _StartGuide();

  static const _color = Color(0xFF304D46);

  @override
  Widget build(BuildContext context) => const Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'タップで\nスタート！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 44,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: _color,
            ),
          ),
          SizedBox(height: 20),
          Text(
            '輪が小さくなったら\nタップ！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              height: 1.3,
              fontWeight: FontWeight.bold,
              color: _color,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 上部の状況表示。レベル・得た魂ポイント・運んだ缶の数。
class _Hud extends StatelessWidget {
  const _Hud({
    required this.level,
    required this.levelCount,
    required this.points,
    required this.carried,
  });

  final int level;
  final int levelCount;
  final int points;
  final int carried;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レベル $level/$levelCount　魂 $points pt',
            key: const Key('coop-hud'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < SoulRun.hops; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < carried
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFD5DCD9),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 画面中央付近の大きな言葉。操作は受けない。
class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 32,
    right: 32,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.25),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFB74D), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF304D46),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
