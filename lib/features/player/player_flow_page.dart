import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/repository/match_repository.dart';
import '../../core/rules/match_rules.dart';
import '../../core/session/session_store.dart';
import '../../core/ui/messages.dart';
import 'player_capture_view.dart';
import 'player_course_map.dart';
import 'player_join_view.dart';
import 'player_judgement_view.dart';
import 'player_map_view.dart';
import 'player_media.dart';
import 'player_qr_view.dart';
import 'player_ranking_view.dart';
import 'player_result_view.dart';
import 'player_start_waiting_view.dart';
import 'player_ui.dart';

enum _Screen { map, checkpointQr, capture, review, judgement, goalQr, ranking, freeMissions }

enum _QrPurpose { checkpoint, goal }

/// Player entry body. PlayerShell and the application router own the Scaffold.
/// Only transient navigation, the current photo and pending actions live here;
/// room state, scores, eligibility and persisted sessions use the common API.
class PlayerFlowPage extends ConsumerStatefulWidget {
  const PlayerFlowPage({super.key, this.resumeRoomId});

  final String? resumeRoomId;

  @override
  ConsumerState<PlayerFlowPage> createState() => _PlayerFlowPageState();
}

class _PlayerFlowPageState extends ConsumerState<PlayerFlowPage> {
  String? _roomId;
  String _roomCode = '';
  String _displayName = '';
  _Screen _screen = _Screen.map;
  Checkpoint? _checkpoint;
  Uint8List? _photo;
  int _photoNumber = 0;
  int _generation = 0;
  bool _actionBusy = false;
  bool _savingSession = false;
  bool _closing = false;
  bool _sessionNeedsSave = false;
  bool _returnToJoinAfterClose = false;
  String? _joinError;
  String? _scanError;
  String? _captureError;
  String? _judgeError;
  String? _sessionError;
  JudgeOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _roomId = widget.resumeRoomId;
  }

  @override
  void didUpdateWidget(covariant PlayerFlowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resumeRoomId != oldWidget.resumeRoomId) {
      _generation++;
      _roomId = widget.resumeRoomId;
      _screen = _Screen.map;
      _checkpoint = null;
      _photo = null;
      _outcome = null;
      _joinError = _scanError = _captureError = _judgeError = _sessionError = null;
      _actionBusy = _savingSession = _closing = false;
      _sessionNeedsSave = false;
    }
  }

  DateTime get _now => ref.read(tickerProvider).value ?? DateTime.now();

  RoomSnapshot? get _snapshot {
    final roomId = _roomId;
    return roomId == null ? null : ref.read(roomSnapshotProvider(roomId)).value;
  }

  bool _isCurrent(int generation, String? roomId) => mounted && generation == _generation && roomId == _roomId;

  bool get _canPlay {
    final roomId = _roomId;
    if (roomId == null || _closing) return false;
    final state = ref.read(roomSnapshotProvider(roomId));
    final data = state.value;
    if (state.isLoading || state.hasError || data == null) return false;
    final me = data.participant(ref.read(matchRepositoryProvider).currentUserId);
    return me != null && !me.hasFinished && data.room.statusAt(_now) == RoomStatus.running;
  }

  bool get _knownFinished {
    final data = _snapshot;
    if (data == null) return false;
    return data.room.statusAt(_now) == RoomStatus.finished ||
        (data.participant(ref.read(matchRepositoryProvider).currentUserId)?.hasFinished ?? false);
  }

  Future<void> _join(String code, String name) async {
    if (_actionBusy) return;
    final generation = ++_generation;
    final repo = ref.read(matchRepositoryProvider);
    final store = ref.read(sessionStoreProvider);
    setState(() {
      _actionBusy = true;
      _joinError = null;
      _roomCode = code;
      _displayName = name;
    });
    try {
      final room = await repo.findRoomByCode(code);
      if (!_isCurrent(generation, null)) return;
      await repo.joinRoom(roomId: room.id, displayName: name);
      if (!_isCurrent(generation, null)) return;
      // Joining is already committed by the repository, even if saving the
      // local resume pointer fails. Keep that membership and offer a retry.
      String? saveError;
      try {
        await store.save(ActiveSession(role: SessionRole.player, roomId: room.id));
      } catch (_) {
        saveError = '参加は完了しましたが、続きから開くための記録を保存できませんでした。';
      }
      if (!_isCurrent(generation, null)) return;
      ref.invalidate(activeSessionProvider);
      setState(() {
        _roomId = room.id;
        _screen = _Screen.map;
        _sessionError = saveError;
        _sessionNeedsSave = saveError != null;
      });
    } catch (error) {
      if (_isCurrent(generation, null)) setState(() => _joinError = describeError(error));
    } finally {
      if (mounted && generation == _generation) setState(() => _actionBusy = false);
    }
  }

  Future<void> _retrySessionSave() async {
    final roomId = _roomId;
    if (roomId == null || _savingSession || _closing) return;
    final generation = _generation;
    setState(() => _savingSession = true);
    try {
      await ref.read(sessionStoreProvider).save(ActiveSession(role: SessionRole.player, roomId: roomId));
      if (!_isCurrent(generation, roomId)) return;
      ref.invalidate(activeSessionProvider);
      setState(() {
        _sessionError = null;
        _sessionNeedsSave = false;
      });
    } catch (_) {
      // Keep the original warning and the joined room, without joining again.
    } finally {
      if (_isCurrent(generation, roomId)) setState(() => _savingSession = false);
    }
  }

  void _refresh() {
    final roomId = _roomId;
    if (roomId != null) ref.invalidate(roomSnapshotProvider(roomId));
  }

  void _show(_Screen screen, {bool clearMission = false}) {
    if (_actionBusy || _closing || _savingSession) return;
    setState(() {
      _generation++;
      _screen = screen;
      _scanError = _captureError = _judgeError = null;
      if (clearMission) {
        _checkpoint = null;
        _photo = null;
        _outcome = null;
      }
    });
  }

  Future<void> _scan(_QrPurpose purpose, String code) async {
    final roomId = _roomId;
    if (roomId == null || _actionBusy || _closing) return;
    final snapshotState = ref.read(roomSnapshotProvider(roomId));
    final data = snapshotState.value;
    if (snapshotState.isLoading || snapshotState.hasError || data == null) return;
    if (!_canPlay) return;
    final repo = ref.read(matchRepositoryProvider);
    final generation = ++_generation;
    setState(() {
      _actionBusy = true;
      _scanError = null;
    });
    try {
      switch (purpose) {
        case _QrPurpose.checkpoint:
          final checkpoint = await repo.scanCheckpoint(roomId: roomId, qr: code);
          if (!_isCurrent(generation, roomId) || !_canPlay) return;
          setState(() {
            _checkpoint = checkpoint;
            _photo = null;
            _outcome = null;
            _captureError = _judgeError = null;
            _screen = _Screen.capture;
          });
        case _QrPurpose.goal:
          await repo.scanGoal(roomId: roomId, qr: code);
          if (!_isCurrent(generation, roomId)) return;
          setState(() => _screen = _Screen.map);
          _refresh();
      }
    } catch (error) {
      if (_isCurrent(generation, roomId)) setState(() => _scanError = describeError(error));
    } finally {
      if (_isCurrent(generation, roomId)) setState(() => _actionBusy = false);
    }
  }

  Future<void> _capture() async {
    final roomId = _roomId;
    if (roomId == null || _actionBusy || !_canPlay || _checkpoint == null) return;
    final generation = ++_generation;
    final picker = ref.read(playerPhotoPickerProvider);
    setState(() {
      _actionBusy = true;
      _captureError = null;
    });
    try {
      final photo = await picker.capturePhoto();
      if (!_isCurrent(generation, roomId) || _knownFinished) return;
      if (photo == null) {
        setState(() => _captureError = '撮影をキャンセルしました。もう一度撮影できます。');
      } else if (photo.isEmpty) {
        setState(() => _captureError = '写真を読み込めませんでした。もう一度撮影してください。');
      } else {
        setState(() {
          _photo = photo;
          _photoNumber++;
          _outcome = null;
          _judgeError = null;
          _screen = _Screen.review;
        });
      }
    } catch (error) {
      if (_isCurrent(generation, roomId)) {
        setState(() => _captureError = error is PlayerMediaException ? error.message : '写真を取得できませんでした。もう一度撮影してください。');
      }
    } finally {
      if (_isCurrent(generation, roomId)) setState(() => _actionBusy = false);
    }
  }

  Future<void> _submit() async {
    final roomId = _roomId;
    final checkpoint = _checkpoint;
    final photo = _photo;
    if (roomId == null || checkpoint == null || photo == null || _actionBusy || !_canPlay) return;
    final generation = ++_generation;
    final repo = ref.read(matchRepositoryProvider);
    setState(() {
      _actionBusy = true;
      _judgeError = null;
      _outcome = null;
      _screen = _Screen.judgement;
    });
    try {
      final outcome = await repo.submitPhoto(roomId: roomId, checkpointId: checkpoint.id, photo: photo);
      if (!_isCurrent(generation, roomId)) return;
      if (!_knownFinished) setState(() => _outcome = outcome);
      _refresh();
    } catch (error) {
      if (!_isCurrent(generation, roomId) || _knownFinished) return;
      setState(() => _judgeError = describeError(error));
      if (error is MatchRuleViolation) _refresh();
    } finally {
      if (_isCurrent(generation, roomId)) setState(() => _actionBusy = false);
    }
  }

  Future<void> _close({bool returnToJoin = false}) async {
    if (_closing || _savingSession) return;
    final roomId = _roomId;
    final generation = ++_generation;
    final store = ref.read(sessionStoreProvider);
    setState(() {
      _closing = true;
      _actionBusy = false;
      _sessionError = null;
      _sessionNeedsSave = false;
      _returnToJoinAfterClose = returnToJoin;
    });
    try {
      final session = await store.load();
      if (!_isCurrent(generation, roomId)) return;
      if (session?.role == SessionRole.player && session?.roomId == roomId) await store.clear();
      if (!_isCurrent(generation, roomId)) return;
      ref.invalidate(activeSessionProvider);
      setState(() {
        _closing = false;
        _roomId = null;
        _screen = _Screen.map;
        _checkpoint = null;
        _photo = null;
        _outcome = null;
        _joinError = null;
      });
      if (!returnToJoin) {
        // Release PopScope's closing guard before asking the route to pop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && generation == _generation && _roomId == null) Navigator.of(context).maybePop();
        });
      }
    } catch (_) {
      if (_isCurrent(generation, roomId)) {
        setState(() {
          _closing = false;
          _sessionError = '続きから開くための記録を消せませんでした。もう一度お試しください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final roomId = _roomId;
    final state = roomId == null ? null : ref.watch(roomSnapshotProvider(roomId));
    final snapshot = state?.value;
    final me = snapshot?.participant(ref.watch(matchRepositoryProvider).currentUserId);
    final terminal =
        snapshot != null && (snapshot.room.statusAt(now) == RoomStatus.finished || (me?.hasFinished ?? false));
    final internalBack = _screen == _Screen.ranking || (!terminal && _screen != _Screen.map);
    final busyBlocksBack = _closing || _savingSession || (_actionBusy && !terminal);
    Widget body;
    if (_sessionError != null) {
      body = _sessionIssuePage();
    } else if (roomId == null) {
      body = PlayerJoinView(
        onJoin: _join,
        initialRoomCode: _roomCode,
        initialDisplayName: _displayName,
        errorMessage: _joinError,
      );
    } else if (state!.hasError) {
      body = _connectionPage(describeError(state.error!));
    } else if (snapshot == null || state.isLoading) {
      body = const PlayerPage(
        title: '参加状況を確認中',
        children: [PlayerNotice(message: 'ルームの状態を読み込んでいます…', busy: true)],
      );
    } else if (me == null) {
      body = _connectionPage('このルームへの参加を確認できません。参加コードから入り直してください。');
    } else if (_screen == _Screen.ranking) {
      body = _ranking(snapshot, now, terminal);
    } else if (terminal) {
      body = _result(snapshot, me, now);
    } else if (snapshot.room.statusAt(now) == RoomStatus.waiting) {
      body = PlayerStartWaitingView(
        roomName: snapshot.course.name,
        playerName: me.displayName,
        startsAtLabel: '運営の一斉開始の合図で始まります',
      );
    } else {
      body = _playing(snapshot, me, now, state.isLoading);
    }
    return Theme(
      data: PlayerNight.themeOf(context),
      child: PopScope(
        canPop: !busyBlocksBack && !internalBack,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !busyBlocksBack && internalBack) _show(_Screen.map);
        },
        child: body,
      ),
    );
  }

  Widget _sessionIssuePage() => PlayerPage(
    title: '端末の記録を更新できません',
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _closing || _savingSession
              ? null
              : _sessionNeedsSave
              ? _retrySessionSave
              : () => _close(returnToJoin: _returnToJoinAfterClose),
          child: Text(_sessionNeedsSave ? '続きから開く記録を保存し直す' : '記録の削除を再試行'),
        ),
        TextButton(
          onPressed: _closing || _savingSession
              ? null
              : () => setState(() {
                  _sessionError = null;
                  _sessionNeedsSave = false;
                }),
          child: Text(_sessionNeedsSave ? '記録せずに参加を続ける' : '前の画面に戻る'),
        ),
      ],
    ),
    children: [PlayerNotice(message: _sessionError!, isError: true)],
  );

  Widget _connectionPage(String error) => PlayerPage(
    title: '参加状況を確認できません',
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('もう一度確認する')),
        TextButton(onPressed: _closing ? null : () => _close(returnToJoin: true), child: const Text('参加画面に戻る')),
      ],
    ),
    children: [PlayerNotice(message: error, isError: true)],
  );

  Widget _qr(RoomSnapshot snapshot, _QrPurpose purpose, {required bool enabled}) {
    final builder = ref.watch(playerQrScannerBuilderProvider);
    final (title, instruction) = switch (purpose) {
      _QrPurpose.checkpoint => ('チェックポイントQR', '挑戦する地点のQRを読み取ってください。指定・自由のどちらも読み取れます。'),
      _QrPurpose.goal => ('ゴールQRを読み取る', '会場のゴールQRを読み取って、探索を完了してください。'),
    };
    return PlayerQrView(
      key: ValueKey('qr-$_roomId-$purpose'),
      title: title,
      instruction: instruction,
      scanner: builder(context, (code) => _scan(purpose, code), enabled && !_actionBusy && !_closing),
      isProcessing: _actionBusy || !enabled,
      feedback: _scanError,
    );
  }

  Widget _playing(RoomSnapshot snapshot, Participant me, DateTime now, bool refreshing) {
    final canAct = !refreshing && !_actionBusy && !_closing;
    final checkpoint = _checkpoint;
    final photo = _photo;
    switch (_screen) {
      case _Screen.checkpointQr:
        return _qr(snapshot, _QrPurpose.checkpoint, enabled: !refreshing);
      case _Screen.goalQr:
        return _qr(snapshot, _QrPurpose.goal, enabled: !refreshing);
      case _Screen.capture when checkpoint != null:
        return PlayerCaptureView(
          key: ValueKey('capture-${snapshot.room.id}-${checkpoint.id}'),
          preview: const PlayerNotice(
            message: '「撮影する」で端末のカメラを開きます。撮影後に写真を確認して提出できます。',
            icon: Icons.camera_alt_outlined,
          ),
          instruction: checkpoint.mission,
          cameraReady: !refreshing,
          onCapture: _capture,
          errorMessage: _captureError,
        );
      case _Screen.review when checkpoint != null && photo != null:
        return PlayerPhotoReviewView(
          key: ValueKey('review-${snapshot.room.id}-${checkpoint.id}-$_photoNumber'),
          photo: Image.memory(
            photo,
            key: ValueKey('photo-$_photoNumber'),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => const Center(child: Text('写真を表示できません。撮り直してください。')),
          ),
          instruction: checkpoint.mission,
          onSubmit: _submit,
          onRetake: () => _show(_Screen.capture),
        );
      case _Screen.judgement when checkpoint != null && photo != null:
        final outcome = _outcome;
        return PlayerJudgementView(
          state: _actionBusy
              ? PlayerJudgementDisplayState.processing
              : _judgeError != null
              ? PlayerJudgementDisplayState.error
              : outcome is JudgePassed
              ? PlayerJudgementDisplayState.success
              : PlayerJudgementDisplayState.retake,
          message: _actionBusy ? '写真を提出して判定結果を確認しています。' : _judgeError ?? outcome?.reason ?? '写真を撮り直してください。',
          awardedScoreLabel: outcome is JudgePassed
              ? (outcome.alreadyCleared ? '達成済み（追加${outcome.pointsAwarded}点）' : '+${outcome.pointsAwarded}点')
              : null,
          onContinue: canAct ? () => _show(_Screen.map, clearMission: true) : null,
          onRetake: canAct ? () => _show(_Screen.capture) : null,
          onRetry: canAct ? _submit : null,
        );
      case _Screen.freeMissions:
        return _freeMissions(snapshot);
      default:
        return _map(snapshot, me, now, canAct);
    }
  }

  Widget _map(RoomSnapshot snapshot, Participant me, DateTime now, bool canAct) {
    final clears = snapshot.clearsOf(me.userId);
    final clearedIds = clears.map((clear) => clear.checkpointId).toSet();
    final required = snapshot.course.requiredCheckpoints.toList();
    final clearedRequired = required.where((checkpoint) => clearedIds.contains(checkpoint.id)).length;
    final floors = snapshot.course.checkpoints.map((checkpoint) => checkpoint.floor).toSet();
    final endsAt = snapshot.room.endsAt;
    return PlayerMapView(
      key: ValueKey('map-${snapshot.room.id}'),
      courseName: snapshot.course.name,
      remainingTimeLabel: endsAt == null ? '確認中' : formatRemaining(endsAt.difference(now)),
      progressLabel: '指定ポイント $clearedRequired / ${required.length} 達成',
      floors: {
        for (final floor in floors)
          floor: InteractiveViewer(
            panEnabled: false,
            scaleEnabled: false,
            minScale: 1,
            maxScale: 1,
            child: PlayerCourseMap(
              floor: floor,
              checkpoints: snapshot.course.checkpoints,
              clearedCheckpointIds: clearedIds,
            ),
          ),
      },
      canScanGoal: canAct && hasClearedAllRequired(snapshot.course, clears),
      goalStatusLabel: hasClearedAllRequired(snapshot.course, clears)
          ? '指定ポイントを達成しました。ゴールQRを読み取れます。'
          : '指定ポイントをすべて達成するとゴールQRを読み取れます。',
      onScanCheckpoint: canAct ? () => _show(_Screen.checkpointQr) : null,
      onScanGoal: canAct ? () => _show(_Screen.goalQr) : null,
      onOpenRanking: () => _show(_Screen.ranking),
      onOpenFreeMissions: snapshot.course.checkpoints.any((checkpoint) => !checkpoint.required)
          ? () => _show(_Screen.freeMissions)
          : null,
    );
  }

  Widget _freeMissions(RoomSnapshot snapshot) {
    final userId = ref.read(matchRepositoryProvider).currentUserId;
    final clearedIds = snapshot.clearsOf(userId).map((clear) => clear.checkpointId).toSet();
    return PlayerPage(
      title: '自由ミッション',
      description: '挑戦する場合は、その地点のQRを読み取ってください。',
      actions: ElevatedButton.icon(
        onPressed: _canPlay ? () => _show(_Screen.checkpointQr) : null,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('チェックポイントQRを読み取る'),
      ),
      children: [
        for (final checkpoint in snapshot.course.checkpoints.where((checkpoint) => !checkpoint.required)) ...[
          PlayerSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(checkpoint.name, style: PlayerNight.themeOf(context).textTheme.titleMedium),
                Text(
                  '${checkpoint.floor} · ${checkpoint.points}点 · ${clearedIds.contains(checkpoint.id) ? '達成済み' : '未達成'}',
                ),
                const SizedBox(height: 8),
                Text(checkpoint.mission),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<PlayerRankingRow> _rankingRows(RoomSnapshot snapshot) => [
    for (final standing in standingsOf(snapshot))
      PlayerRankingRow(
        key: ValueKey('standing-${standing.participant.userId}'),
        rankLabel: '${standing.rank}位',
        playerName: standing.participant.displayName,
        scoreLabel: '${standing.score}点',
        isCurrentPlayer: standing.participant.userId == ref.read(matchRepositoryProvider).currentUserId,
      ),
  ];

  Widget _ranking(RoomSnapshot snapshot, DateTime now, bool terminal) => Column(
    children: [
      Expanded(
        child: PlayerRankingView(
          rows: _rankingRows(snapshot),
          statusLabel: snapshot.room.statusAt(now) == RoomStatus.finished ? '最終順位です。' : '対戦中の暫定順位です。',
          onRefresh: _refresh,
        ),
      ),
      TextButton(onPressed: () => _show(_Screen.map), child: Text(terminal ? '結果へ戻る' : 'マップへ戻る')),
    ],
  );

  Widget _result(RoomSnapshot snapshot, Participant me, DateTime now) {
    final finalResult = snapshot.room.statusAt(now) == RoomStatus.finished;
    final standings = standingsOf(snapshot);
    final mine = standings.where((row) => row.participant.userId == me.userId).firstOrNull;
    return PlayerResultView(
      title: me.hasFinished ? 'ゴール！' : '探索終了',
      statusLabel: finalResult ? '対戦が終了しました。最終結果をご確認ください。' : 'ゴールを受け付けました。対戦終了までは得点・順位が変わる場合があります。',
      scoreLabel: '${snapshot.scoreOf(me.userId)}点',
      rankLabel: mine == null ? '集計中' : '${mine.rank}位 / ${standings.length}人',
      isFinal: finalResult,
      scoreBreakdown: [
        for (final clear in snapshot.clearsOf(me.userId))
          Text('${snapshot.course.checkpointById(clear.checkpointId)?.name ?? clear.checkpointId}：${clear.points}点'),
        if (me.hasFinished) Text('ゴールボーナス（残り時間）：${me.goalBonus}点'),
      ],
      onOpenRanking: _closing ? null : () => _show(_Screen.ranking),
      onClose: _closing || _savingSession ? null : _close,
    );
  }
}
