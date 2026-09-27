import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../data/online_controller.dart';
import '../../domain/models.dart';
import '../../domain/online_room.dart';
import '../cooperative/soul_course.dart';
import '../cooperative/soul_stage.dart';
import '../duel/race_course.dart';
import '../duel/race_field.dart';
import '../duel/sea_background.dart';
import '../duel/win_dance.dart';
import 'online_game_timing.dart';
import '../../app/online_lifecycle.dart';

/// Two game actors, one server clock. This widget sends the human inputs only;
/// results and rewards always come from the authoritative room snapshot.
class OnlineGame extends StatefulWidget {
  const OnlineGame({
    super.key,
    required this.controller,
    required this.onPresentationComplete,
  });

  final OnlineController controller;
  final VoidCallback onPresentationComplete;

  @override
  State<OnlineGame> createState() => _OnlineGameState();
}

class _OnlineGameState extends State<OnlineGame>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  Duration? _finishedAt;
  String? _generation;
  final Set<String> _sent = {};
  RaceDecision? _pendingDecision;
  int? _lastTickAt;
  int? _observedBefore;
  String? _observedInput;
  String? _flashInput;
  int? _flashAt;
  int _flashHop = 1;
  bool _foreground = true;
  bool _reported = false;
  bool _inputFailed = false;
  bool _wasConnected = false;

  OnlineController get _controller => widget.controller;
  OnlineEncounter? get _encounter => _controller.encounter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = isOnlineForeground(WidgetsBinding.instance.lifecycleState);
    _controller.addListener(_changed);
    _synchronize();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(covariant OnlineGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != _controller) {
      oldWidget.controller.removeListener(_changed);
      _controller.addListener(_changed);
      _generation = null;
    }
    _synchronize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = isOnlineForeground(state);
    if (_foreground == foreground) return;
    _foreground = foreground;
    _observedBefore = null;
    _lastTickAt = null;
    // Preserve observations when a visible web window merely loses focus.
    // Real background transitions close the socket in OnlinePage/Controller;
    // never turn a pause or a frame gap into a local loss.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() {
    _synchronize();
    if (mounted) setState(() {});
  }

  void _synchronize() {
    final encounter = _encounter;
    final generation = encounter == null
        ? null
        : '${encounter.id}:${encounter.round}';
    if (_generation != generation) {
      _generation = generation;
      _sent.clear();
      _pendingDecision = null;
      _finishedAt = null;
      _reported = false;
      _inputFailed = false;
      _observedBefore = null;
      _observedInput = null;
      _flashInput = null;
      _flashAt = null;
    }
    if (_wasConnected != _controller.connected) {
      _observedBefore = null;
      _lastTickAt = null;
      _wasConnected = _controller.connected;
    }
    if (encounter?.status == 'finished' && encounter?.result != null) {
      _finishedAt ??= _elapsed;
    }
    if (encounter?.cooperative ?? false) {
      final hits = encounter!.coop['hits'];
      if (hits is List && hits.isNotEmpty && hits.last is Map) {
        final hit = hits.last as Map;
        final stamp = '${encounter.coop['level']}:${hit['hop']}:${hit['at']}';
        if (_flashInput != stamp) {
          _flashInput = stamp;
          _flashHop = (hit['hop'] as num?)?.toInt() ?? 1;
          _flashAt = (hit['at'] as num?)?.toInt();
          if (_foreground &&
              hit['playerId'] == _controller.self?.id &&
              _flashAt != null &&
              (_controller.serverNow - _flashAt!).abs() < 700) {
            unawaited(HapticFeedback.mediumImpact());
          }
        }
      }
    }
  }

  bool _canPlay(OnlineEncounter encounter) =>
      _foreground &&
      _controller.connected &&
      !_inputFailed &&
      !_reported &&
      (encounter.status == 'playing' || encounter.status == 'countdown') &&
      encounter.startAt != null &&
      _controller.serverNow >= encounter.startAt!;

  String _inputKey(OnlineEncounter encounter) => encounter.cooperative
      ? '${encounter.id}:${encounter.round}:${encounter.coop['level']}:${encounter.coop['hop']}'
      : '${encounter.id}:${encounter.round}:duel';

  void _tick(Duration elapsed) {
    _elapsed = elapsed;
    final encounter = _encounter;
    final now = _controller.serverNow;
    final continuous = _lastTickAt == null || (now - _lastTickAt!).abs() < 500;
    _lastTickAt = now;
    if (!continuous) _observedBefore = null;
    if (encounter != null && _canPlay(encounter)) {
      final input = _inputKey(encounter);
      if (_observedInput != input) {
        _observedInput = input;
        _observedBefore = null;
      }
      if (!_sent.contains(input)) {
        if (encounter.cooperative) {
          final run = _soulRun(encounter);
          if (run.ownedBy(
            selfId: _controller.self!.id,
            playerIds: encounter.playerIds,
          )) {
            final deadline = run.targetAt + run.level.window.inMilliseconds;
            if (now <= deadline) {
              _observedBefore ??= now;
            } else if (_observedBefore != null &&
                _observedBefore! <=
                    run.targetAt - run.level.window.inMilliseconds &&
                continuous) {
              _sendCoop(encounter, miss: true, at: now);
            }
          }
        } else if (!encounter.decisions.containsKey(_controller.self?.id)) {
          final waterAt = encounter.startAt! + encounter.fallMs;
          if (now < waterAt) {
            _observedBefore ??= now;
          } else if (_observedBefore != null &&
              _observedBefore! <= encounter.startAt! + 250 &&
              continuous) {
            _sendDuel(encounter, at: waterAt, fell: true);
          }
        }
      }
    }
    final finishedAt = _finishedAt;
    if (_foreground &&
        encounter?.status == 'finished' &&
        encounter?.result != null &&
        finishedAt != null &&
        !_reported) {
      final wins = encounter!.result!.outcome == Outcome.win;
      final duration = wins ? 8000 : 1800;
      if ((_elapsed - finishedAt).inMilliseconds >= duration) _complete();
    }
    if (mounted && _foreground) setState(() {});
  }

  void _complete() {
    if (_reported || _encounter?.status != 'finished') return;
    _reported = true;
    widget.onPresentationComplete();
  }

  void _tap() {
    final encounter = _encounter;
    if (encounter == null || !_foreground) return;
    if (encounter.status == 'finished') {
      if (_finishedAt != null &&
          (_elapsed - _finishedAt!).inMilliseconds >= 2000) {
        _complete();
      }
      return;
    }
    if (!_canPlay(encounter) || _sent.contains(_inputKey(encounter))) return;
    final now = _controller.serverNow;
    if (encounter.cooperative) {
      final run = _soulRun(encounter);
      if (now < run.startAt ||
          !run.ownedBy(
            selfId: _controller.self!.id,
            playerIds: encounter.playerIds,
          )) {
        return;
      }
      // A real early/late tap is sent as such. The server decides success.
      _sendCoop(encounter, miss: false, at: now);
    } else if (!encounter.decisions.containsKey(_controller.self?.id)) {
      final waterAt = encounter.startAt! + encounter.fallMs;
      _sendDuel(encounter, at: math.min(now, waterAt), fell: now >= waterAt);
    }
    setState(() {});
  }

  void _sendDuel(
    OnlineEncounter encounter, {
    required int at,
    required bool fell,
  }) {
    final key = _inputKey(encounter);
    if (!_sent.add(key)) return;
    final depth = math.pow((at - encounter.startAt!) / encounter.fallMs, 2);
    _pendingDecision = fell
        ? const RaceDecision.fell()
        : RaceDecision.stopped(depth.toDouble().clamp(0, 1));
    if (fell) unawaited(HapticFeedback.heavyImpact());
    _send('duelInput', {
      'encounterId': encounter.id,
      'round': encounter.round,
      'at': at,
      'fell': fell,
    }, generation: _generation);
  }

  void _sendCoop(
    OnlineEncounter encounter, {
    required bool miss,
    required int at,
  }) {
    if (!_sent.add(_inputKey(encounter))) return;
    _send('coopInput', {
      'encounterId': encounter.id,
      'round': encounter.round,
      'level': encounter.coop['level'],
      'hop': encounter.coop['hop'],
      'at': at,
      'miss': miss,
    }, generation: _generation);
  }

  void _send(
    String type,
    Map<String, Object?> payload, {
    required String? generation,
  }) {
    unawaited(() async {
      final accepted = await _controller.sendGameInput(type, payload);
      if (!mounted || generation != _generation || accepted) return;
      if (_encounter?.status == 'finished' ||
          _encounter?.status == 'cancelled' ||
          _encounter?.status == 'draw') {
        return;
      }
      // Failed delivery is not a game loss. Stop this generation's inputs and
      // wait for the authoritative reconnect/cancellation snapshot.
      setState(() => _inputFailed = true);
    }());
  }

  OnlineSoulRun _soulRun(OnlineEncounter encounter) => OnlineSoulRun(
    state: encounter.coop,
    serverNow: _controller.serverNow,
    fallbackStartAt: encounter.startAt ?? _controller.serverNow,
    failed: encounter.result?.outcome == Outcome.coopFailure,
  );

  RaceDecision? _decision(OnlineEncounter encounter, String id) {
    final raw = encounter.decisions[id];
    if (raw is! Map) return null;
    return raw['fell'] == true
        ? const RaceDecision.fell()
        : RaceDecision.stopped((raw['depth'] as num?)?.toDouble() ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final encounter = _encounter;
    final self = _controller.self;
    if (encounter == null || self == null) {
      return const Center(child: Text('ルームの状態を確認しています…'));
    }
    Participant? peer;
    for (final id in encounter.playerIds) {
      if (id != self.id) {
        peer = _controller.participantById(id);
        if (peer != null) break;
      }
    }
    if (peer == null) {
      return const Center(child: Text('相手の接続を確認しています…'));
    }
    final now = _controller.serverNow;
    final startAt = encounter.startAt;
    final countdown = startAt != null && now < startAt;
    final terminal =
        encounter.status == 'cancelled' || encounter.status == 'draw';
    final waiting = encounter.status == 'offered';
    final disconnected = !_controller.connected || !_foreground || _inputFailed;
    final resultElapsed = _finishedAt == null
        ? Duration.zero
        : _elapsed - _finishedAt!;
    final dance =
        encounter.status == 'finished' &&
        encounter.result?.outcome == Outcome.win &&
        resultElapsed.inMilliseconds >= 1000;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        GestureDetector(
          key: const Key('online-game-input'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: encounter.cooperative
              ? _cooperativeField(encounter, self, peer)
              : _duelField(encounter, self, peer),
        ),
        if (dance)
          Positioned.fill(
            child: IgnorePointer(
              child: WinDance(
                elapsed: resultElapsed - const Duration(seconds: 1),
              ),
            ),
          ),
        if (dance && resultElapsed.inMilliseconds >= 2000)
          const Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: IgnorePointer(child: _Hint(text: 'タップして結果へ')),
          ),
        if (waiting || terminal)
          _StatePanel(
            title: terminal
                ? encounter.status == 'draw'
                      ? 'ぴったり同点！'
                      : 'ゲームを中断しました'
                : encounter.cooperative
                ? '力を合わせて運ぼう！'
                : 'シーチキンレース',
            body: terminal
                ? encounter.status == 'draw'
                      ? '今回は報酬なし。もう一度勝負しよう！'
                      : encounter.message ?? '通信と相手の準備を確認して、もう一度。'
                : encounter.cooperative
                ? _cooperativeGuide(encounter, self)
                : '魚がいっしょに落ちはじめる。\n赤い線のぎりぎりで、タップして止めよう！',
            children: [
              if (encounter.status != 'cancelled')
                FilledButton(
                  key: const Key('online-game-ready'),
                  onPressed:
                      disconnected ||
                          _controller.busy ||
                          encounter.readyIds.contains(self.id)
                      ? null
                      : () => unawaited(_controller.readyGame()),
                  child: Text(
                    encounter.readyIds.contains(self.id)
                        ? '相手の準備を待っています'
                        : terminal
                        ? 'もう一度、準備OK！'
                        : '準備OK！',
                  ),
                ),
              TextButton(
                onPressed: _controller.busy
                    ? null
                    : () => unawaited(
                        terminal
                            ? _controller.returnHome()
                            : _controller.cancelGame(),
                      ),
                child: Text(terminal ? 'ホームへ戻る' : '今回はやめる'),
              ),
            ],
          ),
        if (countdown && !terminal && !waiting)
          _StatePanel(
            title: '${((startAt - now) / 1000).ceil()}',
            body: 'ふたりのタイミングを合わせて…',
          ),
        if (disconnected && !terminal && encounter.status != 'finished')
          _StatePanel(
            title: '通信を確認しています…',
            body: '入力を止めています。\nつながるまで、少し待ってね。',
            children: [
              if (_inputFailed && _controller.connected)
                TextButton(
                  onPressed: _controller.busy
                      ? null
                      : () => unawaited(_controller.cancelGame()),
                  child: const Text('いったん中断する'),
                ),
            ],
          ),
      ],
    );
  }

  String _cooperativeGuide(OnlineEncounter encounter, Participant self) {
    final right = encounter.playerIds.first == self.id;
    return 'あなたは${right ? '右' : '左'}の缶。\n自分の缶の輪が小さくなったらタップ！\nふたりで交互に、最後の空き缶まで運ぼう。';
  }

  Widget _duelField(
    OnlineEncounter encounter,
    Participant self,
    Participant peer,
  ) {
    final now = _controller.serverNow;
    final elapsed = Duration(
      milliseconds: math.max(0, now - (encounter.startAt ?? now)),
    );
    final raw = RaceCourse(
      fallDuration: Duration(milliseconds: encounter.fallMs),
    ).depthAt(elapsed);
    final selfDecision = _decision(encounter, self.id) ?? _pendingDecision;
    final peerDecision = _decision(encounter, peer.id);
    double depth(RaceDecision? decision) => decision == null
        ? math.min(raw, 1)
        : decision.fell
        ? math.min(raw, RaceField.maxDepth)
        : decision.depth;
    final outcome = encounter.result?.outcome;
    return Stack(
      fit: StackFit.expand,
      children: [
        RaceField(
          self: self,
          peer: peer,
          elapsed: elapsed,
          selfDepth: depth(selfDecision),
          peerDepth: depth(peerDecision),
          selfDecision: selfDecision,
          peerDecision: peerDecision,
          selfWins: encounter.status == 'finished'
              ? outcome == Outcome.win
              : null,
        ),
        if (_canPlay(encounter))
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: IgnorePointer(
              child: _Hint(
                text: selfDecision == null ? 'タップでストップ！' : 'ふたりの結果を確認しています…',
              ),
            ),
          ),
      ],
    );
  }

  Widget _cooperativeField(
    OnlineEncounter encounter,
    Participant self,
    Participant peer,
  ) {
    final run = _soulRun(encounter);
    final right = encounter.playerIds.first == self.id;
    final ownTurn = run.ownedBy(
      selfId: self.id,
      playerIds: encounter.playerIds,
    );
    final intro =
        encounter.startAt != null &&
        _controller.serverNow >= encounter.startAt! &&
        _controller.serverNow < run.startAt;
    final flash =
        _flashAt != null && (_controller.serverNow - _flashAt!).abs() < 650;
    return Stack(
      fit: StackFit.expand,
      children: [
        SeaBackground(elapsed: run.elapsed),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: _Hint(
                key: const Key('online-coop-role'),
                text:
                    'レベル ${run.level.number}/3　${run.carriedHops}/6\nあなたは${right ? '右' : '左'}の缶',
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    SoulStage(
                      team: self.team,
                      selfName: right ? 'あなた' : peer.profile.nickname,
                      peerName: right ? peer.profile.nickname : 'あなた',
                      run: run,
                      runTime: run.visualTime,
                      flashText: flash ? 'ナイス！' : null,
                      flashHop: _flashHop,
                    ),
                    if (_canPlay(encounter) && ownTurn && !intro)
                      ..._ring(SoulLayout(constraints.biggest), run),
                    if (_canPlay(encounter) && !intro)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 8,
                        child: IgnorePointer(
                          child: _Hint(
                            text: run.nextHop > SoulRun.hops
                                ? '空き缶へ、あと少し！'
                                : ownTurn
                                ? _sent.contains(_inputKey(encounter))
                                      ? '入力を届けています…'
                                      : 'あなたの番！ 輪に合わせてタップ'
                                : '${peer.profile.nickname}の番。応援しよう！',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (intro)
          _StatePanel(title: 'レベル ${run.level.number}', body: '次の缶へ、息を合わせよう！'),
        if (run.status == SoulStatus.cleared && encounter.status != 'finished')
          const _StatePanel(title: 'レベルクリア！', body: 'いいコンビ！'),
        if (encounter.status == 'finished' &&
            encounter.result?.outcome == Outcome.coopSuccess)
          const _StatePanel(title: 'ぜんぶ運べた！', body: 'ふたりでつないだ、ひとつの魂。'),
      ],
    );
  }

  List<Widget> _ring(SoulLayout layout, OnlineSoulRun run) {
    if (run.status != SoulStatus.flying || run.nextHop > SoulRun.hops) {
      return [];
    }
    final arrival = run.arrival(run.nextHop);
    final begin = arrival - run.level.flight;
    if (run.elapsed < begin) return [];
    final progress =
        ((run.elapsed - begin).inMicroseconds / run.level.flight.inMicroseconds)
            .clamp(0.0, 1.0);
    final radius = layout.canWidth * (1.5 - progress);
    final lid = layout.lid(run.nextHop);
    final inWindow = (run.elapsed - arrival).abs() <= run.level.window;
    return [
      Positioned(
        key: const Key('online-soul-ring'),
        left: lid.dx - radius,
        top: lid.dy - radius,
        width: radius * 2,
        height: radius * 2,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: inWindow
                    ? const Color(0xFF2E9E5B)
                    : const Color(0xFFFF9800),
                width: 4,
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .88),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.title,
    required this.body,
    this.children = const [],
  });

  final String title;
  final String body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Colors.white.withValues(alpha: .75),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(body, textAlign: TextAlign.center),
                  if (children.isNotEmpty) const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
