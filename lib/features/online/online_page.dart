import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/conveyor_settings_scope.dart';
import '../../app/tsunagun_theme.dart';
import '../../data/online_controller.dart';
import '../../domain/conveyor_layout.dart';
import '../../domain/models.dart';
import '../../domain/online_room.dart';
import '../demo/can_stage.dart';
import '../demo/conveyor_editor.dart';
import '../demo/factory_backdrop.dart';
import '../demo/final_awards.dart';
import '../demo/font_comparison_controls.dart';
import '../demo/illustrated_details.dart';
import '../demo/result_sound_player.dart';
import '../demo/tug_of_war_finale.dart';
import 'online_game.dart';
import 'online_lifecycle.dart';
import 'qr_panel.dart';

/// The normal app flow. Every participant, game and reward comes from the room.
class OnlinePage extends StatefulWidget {
  const OnlinePage({
    super.key,
    required this.controller,
    this.resultSoundPlayer,
  });

  final OnlineController controller;

  /// Owned and disposed by the page, matching the single-device page contract.
  final ResultSoundPlayer? resultSoundPlayer;

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> with WidgetsBindingObserver {
  OnlineController get online => widget.controller;
  late final _sound =
      widget.resultSoundPlayer ?? const SilentResultSoundPlayer();
  final _nickname = TextEditingController();
  final _hobby = TextEditingController();
  final _comment = TextEditingController();
  final _scroll = ScrollController();
  int _minutes = 3;
  bool _presentation = false;
  bool _pairing = false;
  bool _returning = false;
  bool _returnSent = false;
  bool _awards = false;
  bool _foreground = true;
  bool _overlayOpen = false;
  bool _conveyorOpen = false;
  bool _profileEditing = false;
  String? _profileIdentity;
  String? _encounterIdentity;
  String? _presentedIdentity;
  String? _playedSound;
  AppPhase? _observedPhase;
  int _soundGeneration = 0;

  String? get _encounterKey {
    final encounter = online.encounter;
    return encounter == null ? null : '${encounter.id}:${encounter.round}';
  }

  Profile get _draft => Profile(
    nickname: _nickname.text,
    hobby: _hobby.text,
    comment: _comment.text,
  );

  bool get _profileComplete =>
      online.self != null && online.room?.isProfileReady(online.self!) == true;

  AppPhase get _phase {
    final room = online.room;
    if (room == null) return AppPhase.entry;
    if (online.finalSnapshot != null &&
        (room.status == 'finale' || room.status == 'ended')) {
      return _awards ? AppPhase.results : AppPhase.finale;
    }
    if (room.status == 'lobby') {
      return !_profileComplete || _profileEditing
          ? AppPhase.profile
          : AppPhase.lobby;
    }
    if (room.presentation && room.status == 'active' && !_profileComplete) {
      return AppPhase.profile;
    }
    if (online.encounter != null) {
      if (_returning && online.result != null) return AppPhase.returning;
      if (_presentedIdentity == _encounterKey && online.result != null) {
        return AppPhase.result;
      }
      return AppPhase.game;
    }
    return _pairing ? AppPhase.pairing : AppPhase.home;
  }

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = isOnlineForeground(state);
    WidgetsBinding.instance.addObserver(this);
    online.addListener(_observe);
    _observe();
  }

  @override
  void didUpdateWidget(OnlinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != online) {
      oldWidget.controller.removeListener(_observe);
      online.addListener(_observe);
      _profileIdentity = null;
      _observe();
    }
  }

  void _observe() {
    final identity = online.room == null
        ? null
        : '${online.room!.code}:${online.self?.id}';
    if (identity != _profileIdentity) {
      _profileIdentity = identity;
      final profile = online.self?.profile ?? const Profile.empty();
      _nickname.text = profile.nickname;
      _hobby.text = profile.hobby;
      _comment.text = profile.comment;
      _profileEditing = false;
      _pairing = false;
      _returning = false;
      _awards = false;
      _presentedIdentity = null;
      _playedSound = null;
    }
    if (_encounterIdentity != _encounterKey) {
      _encounterIdentity = _encounterKey;
      _presentedIdentity = null;
      _returning = false;
      _returnSent = false;
      if (_encounterIdentity != null) _pairing = false;
    }
    final phase = _phase;
    if (phase == _observedPhase) return;
    final previous = _observedPhase;
    _observedPhase = phase;
    _updateSound(previous);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (_overlayOpen &&
          !_conveyorOpen &&
          (phase == AppPhase.game || phase == AppPhase.finale)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  Future<void> _guardSound(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Sound cannot prevent a settled result or navigation being shown.
    }
  }

  void _updateSound(AppPhase? previous) {
    final generation = ++_soundGeneration;
    if (previous == AppPhase.result || _phase != AppPhase.game) {
      unawaited(_guardSound(_sound.stop));
    }
    if (_phase == AppPhase.game && _foreground) {
      unawaited(_guardSound(_sound.prepare));
    }
    final result = online.result;
    final identity = _encounterKey;
    if (_phase != AppPhase.result ||
        !_foreground ||
        identity == _playedSound ||
        result == null ||
        (result.outcome != Outcome.loss &&
            result.outcome != Outcome.coopFailure)) {
      return;
    }
    _playedSound = identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _soundGeneration ||
          !_foreground ||
          _phase != AppPhase.result ||
          identity != _encounterKey) {
        return;
      }
      unawaited(_guardSound(_sound.playShobone));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = isOnlineForeground(state);
    online.setForeground(_foreground);
    if (!_foreground) {
      _soundGeneration++;
      unawaited(_guardSound(_sound.stop));
    }
  }

  void _change(VoidCallback action) {
    setState(action);
    _observe();
  }

  Future<void> _finishReturn() async {
    if (_returnSent || !_returning) return;
    _returnSent = true;
    final identity = _encounterKey;
    final returned = await online.returnHome();
    if (!mounted || identity != _encounterKey) return;
    if (!returned) {
      _change(() {
        _returning = false;
        _returnSent = false;
      });
    }
  }

  Future<void> _disposeSound() async {
    await _guardSound(_sound.stop);
    await _guardSound(_sound.dispose);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    online.removeListener(_observe);
    _soundGeneration++;
    unawaited(_disposeSound());
    _nickname.dispose();
    _hobby.dispose();
    _comment.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: online,
    builder: (context, _) {
      final phase = _phase;
      final gameKey = _encounterKey;
      final inEvent = online.room != null && online.room!.status != 'lobby';
      return PopScope(
        canPop: phase == AppPhase.entry,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_pairing) _change(() => _pairing = false);
          if (phase == AppPhase.game) _confirmCancel();
        },
        child: Scaffold(
          body: SafeArea(
            child: online.restoring
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text('ルームに戻っています…'),
                      ],
                    ),
                  )
                : phase == AppPhase.game
                ? Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _confirmCancel,
                              tooltip: 'ゲームを中断',
                              icon: const Icon(Icons.close),
                            ),
                            Expanded(
                              child: Text(
                                online.room?.status == 'closing'
                                    ? '結果を受け付けています'
                                    : '残り ${_time(online.remaining)}',
                              ),
                            ),
                            if (!online.connected)
                              const Icon(
                                Icons.cloud_off_outlined,
                                semanticLabel: '再接続中',
                              ),
                          ],
                        ),
                      ),
                      if (online.error != null) _errorNotice(),
                      Expanded(
                        child: OnlineGame(
                          key: ValueKey(gameKey),
                          controller: online,
                          onPresentationComplete: () {
                            if (mounted &&
                                _encounterKey == gameKey &&
                                online.result != null) {
                              _change(() => _presentedIdentity = gameKey);
                            }
                          },
                        ),
                      ),
                    ],
                  )
                : FactoryBackdrop(
                    transitionKey: phase,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: phase == AppPhase.entry
                                ? (constraints.maxHeight - 38).clamp(
                                    0.0,
                                    double.infinity,
                                  )
                                : 0,
                          ),
                          child: Column(
                            mainAxisAlignment: phase == AppPhase.entry
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TsunagunWordmark(),
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('online-settings'),
                                    onPressed: _settings,
                                    tooltip: '設定',
                                    icon: const Icon(Icons.settings_outlined),
                                  ),
                                ],
                              ),
                              if (online.room != null) _connectionNotice(),
                              if (inEvent) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      online.self?.team.label ?? '',
                                      style: TextStyle(
                                        color: online.self?.team == Team.red
                                            ? TsunagunColors.red
                                            : TsunagunColors.blue,
                                      ),
                                    ),
                                    if (online.room!.status == 'active')
                                      Text('残り ${_time(online.remaining)}'),
                                    if (online.room!.status == 'closing')
                                      const Text('最後の結果を集めています'),
                                  ],
                                ),
                              ],
                              if (phase != AppPhase.finale &&
                                  phase != AppPhase.results) ...[
                                const SizedBox(height: 12),
                                CanStage(
                                  phase: phase,
                                  profile: phase == AppPhase.profile
                                      ? _draft
                                      : online.self?.profile ??
                                            const Profile.empty(),
                                  result: online.result,
                                  team: inEvent ? online.self?.team : null,
                                  onReturnComplete: _finishReturn,
                                  conveyorLayout:
                                      ConveyorSettingsScope.maybeOf(
                                        context,
                                      )?.value ??
                                      const ConveyorLayout(),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ..._panel(phase),
                              if (online.error != null) _errorNotice(),
                              if (online.busy)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      );
    },
  );

  Widget _connectionNotice() => online.connected
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('再接続しています。通信が戻るまでお待ちください。'),
          ),
        );

  Widget _errorNotice() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              online.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          IconButton(
            onPressed: online.clearError,
            tooltip: 'メッセージを閉じる',
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    ),
  );

  List<Widget> _panel(AppPhase phase) {
    final readyToAct = !online.busy && online.connected;
    switch (phase) {
      case AppPhase.entry:
        return [
          if (!online.configured)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('通信先が設定されていません。接続済みのアプリで開いてください。'),
            ),
          DropdownButtonFormField<int>(
            initialValue: _minutes,
            decoration: const InputDecoration(labelText: '交流する時間'),
            items: [3, 5, 10]
                .map((m) => DropdownMenuItem(value: m, child: Text('$m 分')))
                .toList(),
            onChanged: online.busy
                ? null
                : (value) => setState(() => _minutes = value!),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('発表用ルーム'),
            subtitle: const Text('主催者1人でもはじめられます。2人目は開始後も参加できます。'),
            value: _presentation,
            onChanged: online.busy
                ? null
                : (value) => setState(() => _presentation = value),
          ),
          FilledButton(
            key: const Key('create-online-room'),
            onPressed: online.busy || !online.configured
                ? null
                : () => online.createRoom(
                    presentation: _presentation,
                    duration: Duration(minutes: _minutes),
                  ),
            child: const Text('ルームをつくる'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('join-online-room'),
            onPressed: online.busy || !online.configured
                ? null
                : () => _scan(QrPurpose.room, camera: false),
            child: const Text('ルームに参加する'),
          ),
        ];
      case AppPhase.profile:
        return [
          _heading('あなたのラベル'),
          _field('ニックネーム', _nickname, 20, 'nickname'),
          _field('趣味', _hobby, 60, 'hobby'),
          _field('ひとこと（任意）', _comment, 80, 'comment'),
          FilledButton(
            key: const Key('save-online-profile'),
            onPressed: readyToAct
                ? () async {
                    FocusScope.of(context).unfocus();
                    final saved = await online.saveProfile(_draft);
                    if (mounted && saved) {
                      _change(() => _profileEditing = false);
                    }
                  }
                : null,
            child: const Text('この缶で参加する'),
          ),
        ];
      case AppPhase.lobby:
        final minimum = online.room!.presentation ? 1 : 2;
        final allReady =
            online.participants.length >= minimum &&
            online.participants.every(online.room!.isProfileReady);
        return [
          _heading('まもなく、交流の時間。'),
          _roomCodePanel(),
          const SizedBox(height: 16),
          Text('参加者 ${online.participants.length}人'),
          ...online.participants.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                online.room!.isProfileReady(p)
                    ? Icons.check_circle_outline
                    : Icons.edit_outlined,
              ),
              title: Text(
                p.profile.nickname.isEmpty
                    ? 'ラベルを作成中…'
                    : '${p.profile.nickname}${p.id == online.self?.id ? '（あなた）' : ''}',
              ),
            ),
          ),
          const Text('チームは開始時に決まります。'),
          const SizedBox(height: 16),
          if (online.isHost)
            FilledButton(
              key: const Key('start-online-room'),
              onPressed: readyToAct && allReady ? online.startRoom : null,
              child: const Text('交流をはじめる'),
            )
          else
            const Text('主催者の開始を待っています。', textAlign: TextAlign.center),
          if (online.room!.presentation)
            const Text(
              '主催者1人でもはじめられます。2人目は開始後も参加できます。',
              textAlign: TextAlign.center,
            ),
          if (online.isHost && !allReady)
            Text(
              online.room!.presentation
                  ? '参加者のラベルがそろうまで、お待ちください。'
                  : '2人以上のラベルがそろうと、はじめられます。',
              textAlign: TextAlign.center,
            ),
          TextButton(
            onPressed: online.busy
                ? null
                : () => _change(() => _profileEditing = true),
            child: const Text('ラベルを編集する'),
          ),
          if (online.room!.presentation &&
              online.room!.demoParticipants.isNotEmpty)
            _teamMembers(supportersOnly: true),
        ];
      case AppPhase.home:
        final followers = online.followers;
        return [
          _heading('${online.self?.profile.nickname ?? ''}の仲間たち'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in FollowerKind.values)
                TextButton.icon(
                  onPressed: () => _collection(kind),
                  icon: Image.asset(
                    kind == FollowerKind.normal
                        ? normalFollowerAsset
                        : boneFollowerAsset,
                    width: 28,
                    height: 28,
                    excludeFromSemantics: true,
                  ),
                  label: Text(
                    '${kind == FollowerKind.normal ? '子分' : '骨'} ${followers.where((f) => f.kind == kind).length} 匹',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'ちから ${followers.fold(0, (sum, follower) => sum + follower.power)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('online-connect'),
            onPressed: readyToAct && online.room!.status == 'active'
                ? () => _change(() => _pairing = true)
                : null,
            icon: const Icon(Icons.qr_code),
            label: const Text('ツナがる'),
          ),
          const SizedBox(height: 10),
          Text(
            online.room!.presentation
                ? '同じ相手と、対戦→協力を体験できます。'
                : '同じチームなら協力。違うチームなら対戦。',
          ),
          if (online.room!.presentation &&
              online.room!.status == 'active' &&
              online.participants.length == 1) ...[
            const SizedBox(height: 20),
            const Text(
              '1台でもデモの相手と遊べます。2人目もあとから参加できます。',
              key: Key('waiting-second-player'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            _roomCodePanel(),
          ] else if (online.room!.presentation &&
              online.participants.any(
                (participant) => !online.room!.isProfileReady(participant),
              )) ...[
            const SizedBox(height: 12),
            const Text(
              '相手がラベルを作成しています。',
              key: Key('waiting-peer-profile'),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          _teamMembers(),
          if (online.isHost && online.room!.status == 'active')
            TextButton(
              onPressed: readyToAct ? _confirmFinish : null,
              child: const Text('交流を終えて綱引きへ'),
            ),
          if (online.room!.status == 'closing')
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('まもなく、最後の大綱引き。'),
            ),
        ];
      case AppPhase.pairing:
        return [
          _heading('目の前の相手と、ツナがる。'),
          if (online.pairQr != null)
            SharedQrPanel(
              data: online.pairQr!,
              code: online.room!.pairCode,
              caption: '相手に、このQRを見せよう。',
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('scan-online-peer'),
            onPressed: readyToAct ? () => _scan(QrPurpose.pair) : null,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('相手のQRを読み取る'),
          ),
          TextButton(
            onPressed: readyToAct
                ? () => _scan(QrPurpose.pair, camera: false)
                : null,
            child: const Text('相手のコードを入力する'),
          ),
          if (online.room!.presentation &&
              online.room!.demoParticipants.any(
                (participant) => participant.playable,
              )) ...[
            const SizedBox(height: 24),
            _heading('デモの相手と遊ぶ'),
            const Text('相手は自動で操作します。対戦→協力を1回ずつ遊べます。'),
            const SizedBox(height: 12),
            for (final demo in online.room!.demoParticipants.where(
              (participant) => participant.playable,
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: ValueKey('pair-demo-${demo.participant.id}'),
                  onPressed:
                      readyToAct &&
                          !demo.busy &&
                          demo.nextKind != null &&
                          online.room!.status == 'active'
                      ? () => online.pairBot(demo.participant.id)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(demo.participant.profile.nickname),
                        Text(
                          '${demo.participant.team.label}・${demo.power}pt',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          demo.nextKind == null
                              ? '交流済み'
                              : demo.busy
                              ? 'ほかの人と遊んでいます'
                              : demo.nextKind == 'coop'
                              ? '次は協力'
                              : 'まずは対戦',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
          TextButton(
            onPressed: () => _change(() => _pairing = false),
            child: const Text('ホームへ戻る'),
          ),
        ];
      case AppPhase.result:
        final result = online.result!;
        final setback =
            result.outcome == Outcome.loss ||
            result.outcome == Outcome.coopFailure;
        final canSuggestCooperation =
            setback &&
            (!online.room!.presentation || result.outcome == Outcome.loss);
        return [
          Text(
            setback
                ? '骨の子分も、大切な仲間。'
                : result.promoted != null
                ? '${result.promoted!.profile.nickname}の子分が元気になった！'
                : '${result.peer.profile.nickname}の子分が仲間入り！',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (canSuggestCooperation || result.promoted != null) ...[
            const SizedBox(height: 10),
            Text(
              setback
                  ? online.room!.presentation
                        ? '次は協力して、元気にしよう！'
                        : '同じチームと協力して、元気にしよう！'
                  : '${result.peer.profile.nickname}と力を合わせて復活！',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.7),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'ちから +${result.delta}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('return-online-home'),
            onPressed: readyToAct
                ? () => _change(() => _returning = true)
                : null,
            child: const Text('ホームへ戻る'),
          ),
        ];
      case AppPhase.returning:
        return [_heading('仲間が、あなたの缶へ。')];
      case AppPhase.finale:
        return [
          TugOfWarFinale(
            snapshot: online.finalSnapshot!,
            serverStartAt: online.room!.finaleStartsAt,
            serverNow: () => online.serverNow,
            canStart: online.isHost && readyToAct,
            onStartRequested: online.startFinale,
            onShowResults: () => _change(() => _awards = true),
          ),
        ];
      case AppPhase.results:
        return [
          _heading('今日、つながった仲間。'),
          FinalAwards(snapshot: online.finalSnapshot!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _collection(null),
            child: const Text('集まった仲間を見る'),
          ),
          TextButton(
            onPressed: online.busy
                ? null
                : () async {
                    final close = await _confirm(
                      'ルームを閉じますか？',
                      'この端末からルームの参加情報を消します。集まった仲間は、この画面で見られなくなります。',
                      'ルームを閉じる',
                    );
                    if (close && mounted) await online.forgetSession();
                  },
            child: const Text('ルームを閉じる'),
          ),
        ];
      case AppPhase.game:
        return const [];
    }
  }

  Widget _roomCodePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('ルームコード', textAlign: TextAlign.center),
      const SizedBox(height: 8),
      SelectableText(
        online.room!.code.length == 5
            ? online.room!.code
            : online.room!.code
                  .replaceAllMapped(RegExp(r'.{4}'), (match) => '${match[0]} ')
                  .trim(),
        key: const Key('room-share-code'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, letterSpacing: 1.5),
      ),
      TextButton.icon(
        key: const Key('copy-room-code'),
        onPressed: _copyRoomCode,
        icon: const Icon(Icons.copy_outlined, size: 18),
        label: const Text('コードをコピー'),
      ),
      const Text('参加する人に、このコードを伝えよう。', textAlign: TextAlign.center),
    ],
  );

  Widget _teamMembers({bool supportersOnly = false}) {
    final supporters = online.room!.presentation
        ? online.room!.demoParticipants
        : const <OnlineDemoParticipant>[];
    return ExpansionTile(
      key: Key(supportersOnly ? 'lobby-demo-members' : 'online-team-members'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      title: Text(supportersOnly ? '応援メンバー（デモ）' : 'チームメンバー'),
      subtitle: Text(
        supportersOnly
            ? '${supporters.length}人'
            : '参加者 ${online.participants.length}人${supporters.isEmpty ? '' : '・応援 ${supporters.length}人（デモ）'}',
      ),
      children: [
        if (supporters.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '応援メンバーの得点も、綱引きに加わります。デモの相手は自動で操作します。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        for (final team in Team.values) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              team.label,
              style: TextStyle(
                color: team == Team.red
                    ? TsunagunColors.red
                    : TsunagunColors.blue,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!supportersOnly)
            for (final participant in online.participants.where(
              (p) => p.team == team,
            ))
              _memberRow(participant),
          for (final supporter in supporters.where(
            (p) => p.participant.team == team,
          ))
            _memberRow(supporter.participant, supporter: supporter),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _memberRow(
    Participant participant, {
    OnlineDemoParticipant? supporter,
  }) => Padding(
    key: ValueKey('team-member-${participant.id}'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(
          supporter == null ? parentAsset : normalFollowerAsset,
          width: 30,
          height: 28,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                participant.profile.nickname.isEmpty
                    ? 'ラベルを作成中…'
                    : '${participant.profile.nickname}${participant.id == online.self?.id ? '（あなた）' : ''}',
                style: TextStyle(
                  color: participant.team == Team.red
                      ? TsunagunColors.red
                      : TsunagunColors.blue,
                ),
              ),
              Text(
                supporter != null
                    ? '応援メンバー（デモ）'
                    : online.room!.isProfileReady(participant)
                    ? '参加者'
                    : 'ラベルを作成中',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        if (supporter != null) ...[
          const SizedBox(width: 8),
          Text(
            '${supporter.power}pt',
            key: ValueKey('demo-power-${participant.id}'),
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ],
    ),
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 23,
        height: 1.35,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller,
    int limit,
    String key,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: Key('online-$key'),
      controller: controller,
      maxLength: limit,
      textInputAction: key == 'comment'
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() {}),
    ),
  );

  String _time(Duration duration) {
    final seconds = duration.inSeconds.clamp(0, 99999);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _copyRoomCode() async {
    final code = online.room?.code;
    if (code == null) return;
    var message = 'ルームコードをコピーしました';
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (_) {
      message = 'コピーできませんでした。コードを長押しして選択してください。';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scan(QrPurpose purpose, {bool camera = true}) async {
    _overlayOpen = true;
    final roomCode = online.room?.code;
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            QrInputPage(purpose: purpose, cameraInitiallyEnabled: camera),
      ),
    );
    _overlayOpen = false;
    if (!mounted ||
        value == null ||
        roomCode != online.room?.code ||
        online.encounter != null) {
      return;
    }
    if (purpose == QrPurpose.room) {
      await online.joinRoom(value);
    } else {
      await online.pair(value);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('戻る'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmCancel() async {
    final encounter = _encounterKey;
    if (encounter == null) return;
    final confirmed = await _confirm(
      'ゲームを中断しますか？',
      'まだ決まっていない結果には、報酬がつきません。',
      '中断する',
    );
    if (mounted && confirmed && encounter == _encounterKey) {
      await online.cancelGame();
    }
  }

  Future<void> _confirmFinish() async {
    final confirmed = await _confirm(
      '最後の大綱引きへ進みますか？',
      '新しい交流をしめ切り、進行中のゲームの結果を待ちます。',
      '綱引きへ進む',
    );
    if (mounted && confirmed) await online.finishRoom();
  }

  Future<void> _settings() async {
    _overlayOpen = true;
    final edit = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading('設定'),
            OutlinedButton(
              onPressed:
                  ConveyorSettingsScope.maybeOf(context)?.isLoaded == true
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('ベルトコンベアを編集'),
            ),
            const FontComparisonControls(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
    _overlayOpen = false;
    if (mounted && edit == true) await _editConveyor();
  }

  Future<void> _editConveyor() async {
    final settings = ConveyorSettingsScope.maybeOf(context);
    if (settings == null || !settings.isLoaded) return;
    _overlayOpen = true;
    _conveyorOpen = true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => FractionallySizedBox(
        heightFactor: .96,
        child: SafeArea(
          top: false,
          child: ConveyorEditor(
            settings: settings,
            phase: _phase,
            profile: _phase == AppPhase.profile
                ? _draft
                : online.self?.profile ?? const Profile.empty(),
            result: online.result,
            team: online.room?.status == 'lobby' ? null : online.self?.team,
          ),
        ),
      ),
    );
    _overlayOpen = false;
    _conveyorOpen = false;
    if (mounted && saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置を保存しました')));
    }
  }

  Future<void> _collection(FollowerKind? kind) async {
    _overlayOpen = true;
    final followers = online.followers
        .where((f) => kind == null || f.kind == kind)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: .8,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _heading('あなたの缶の仲間'),
              if (followers.isEmpty) const Text('まだ仲間はいません。交流すると、ここに集まります。'),
              Expanded(
                child: ListView.builder(
                  itemCount: followers.length,
                  itemBuilder: (context, index) {
                    final follower = followers[index];
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Image.asset(
                        follower.kind == FollowerKind.bone
                            ? boneFollowerAsset
                            : normalFollowerAsset,
                        width: 52,
                      ),
                      title: Text(follower.profile.nickname),
                      subtitle: Text(follower.profile.hobby),
                      children: [
                        if (follower.profile.comment.isNotEmpty)
                          FollowerQuote(text: follower.profile.comment),
                        if (follower.revivedWith != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              '復活を手伝った仲間\n${follower.revivedWith!.profile.nickname}',
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
    _overlayOpen = false;
  }
}
