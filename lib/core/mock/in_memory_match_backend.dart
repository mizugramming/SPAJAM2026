import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../models/models.dart';
import '../repository/match_repository.dart';
import '../rules/match_rules.dart';
import 'mock_photo_judge.dart';

/// サーバーの代わりをするメモリ上のモック。複数ユーザーで1つのデータを共有する。
///
/// 権限・時間・二重加点の判定はサーバー側の正本として振る舞うので、
/// Supabase 実装でも同じ規則を守る。アプリ再起動でデータは消える。
class InMemoryMatchBackend {
  InMemoryMatchBackend({
    required List<Course> courses,
    PhotoJudge? judge,
    DateTime Function()? clock,
    Random? random,
    this.latency = Duration.zero,
  }) : _courses = {for (final c in courses) c.id: c},
       judge = judge ?? ScriptedPhotoJudge(),
       _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final Map<String, Course> _courses;
  final PhotoJudge judge;
  final DateTime Function() _clock;
  final Random _random;

  /// 通信の遅延を再現する。
  final Duration latency;

  /// true の間は全操作が NetworkFailure になる。
  bool offline = false;

  final _rooms = <String, Room>{};
  final _participants = <String, Map<String, Participant>>{};
  final _clears = <String, List<CheckpointClear>>{};
  final _submissions = <String, List<PhotoSubmission>>{};
  final _photos = <String, Uint8List>{};
  final _changes = StreamController<String>.broadcast();
  var _nextId = 1;

  MatchRepository repositoryFor(String userId) => _InMemoryMatchRepository(this, userId);

  DateTime get now => _clock();

  String _newId(String prefix) => '$prefix-${_nextId++}';

  Future<void> _network() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (offline) throw const NetworkFailure();
  }

  void _notify(String roomId) => _changes.add(roomId);

  Room _room(String roomId) => _rooms[roomId] ?? (throw const NotFound('ルームが見つかりません'));

  Course _courseOf(Room room) => _courses[room.courseId]!;

  RoomSnapshot _snapshot(String roomId, String viewerId) {
    final room = _room(roomId);
    final isOwner = room.ownerId == viewerId;
    final submissions = _submissions[roomId] ?? const [];
    return RoomSnapshot(
      room: room,
      course: _courseOf(room),
      participants: List.unmodifiable(_participants[roomId]?.values ?? const <Participant>[]),
      clears: List.unmodifiable(_clears[roomId] ?? const <CheckpointClear>[]),
      // 参加者は自分の提出だけ見える。
      submissions: List.unmodifiable(isOwner ? submissions : submissions.where((s) => s.participantId == viewerId)),
    );
  }

  String _newRoomCode() {
    final active = _rooms.values.where((r) => r.statusAt(now) != RoomStatus.finished).map((r) => r.code).toSet();
    while (true) {
      final code = (_random.nextInt(900000) + 100000).toString();
      if (!active.contains(code)) return code;
    }
  }
}

class _InMemoryMatchRepository implements MatchRepository {
  _InMemoryMatchRepository(this._b, this.currentUserId);

  final InMemoryMatchBackend _b;

  @override
  final String currentUserId;

  Room _ownedRoom(String roomId) {
    final room = _b._room(roomId);
    if (room.ownerId != currentUserId) throw const PermissionDenied();
    return room;
  }

  Participant _me(String roomId) {
    _b._room(roomId);
    final p = _b._participants[roomId]?[currentUserId];
    if (p == null) throw const PermissionDenied('このルームに参加していません');
    return p;
  }

  /// 対戦中の参加者操作に共通する確認。
  ({Room room, Participant me}) _playing(String roomId) {
    final me = _me(roomId);
    final room = _b._room(roomId);
    switch (room.statusAt(_b.now)) {
      case RoomStatus.waiting:
        throw MatchRuleViolation(MatchRule.roomNotRunning);
      case RoomStatus.finished:
        throw MatchRuleViolation(room.status == RoomStatus.running ? MatchRule.timeUp : MatchRule.roomNotRunning);
      case RoomStatus.running:
        break;
    }
    if (me.hasFinished) throw MatchRuleViolation(MatchRule.alreadyFinished);
    return (room: room, me: me);
  }

  void _saveParticipant(Participant p) {
    _b._participants[p.roomId]![p.userId] = p;
    _b._notify(p.roomId);
  }

  @override
  Future<List<Course>> listCourses() async {
    await _b._network();
    return _b._courses.values.toList();
  }

  @override
  Future<Room> createRoom({required String courseId}) async {
    await _b._network();
    if (!_b._courses.containsKey(courseId)) throw const NotFound('コースが見つかりません');
    final room = Room(
      id: _b._newId('room'),
      code: _b._newRoomCode(),
      courseId: courseId,
      ownerId: currentUserId,
      status: RoomStatus.waiting,
      createdAt: _b.now,
    );
    _b._rooms[room.id] = room;
    _b._participants[room.id] = {};
    _b._clears[room.id] = [];
    _b._submissions[room.id] = [];
    _b._notify(room.id);
    return room;
  }

  @override
  Future<void> startRoom(String roomId) async {
    await _b._network();
    final room = _ownedRoom(roomId);
    if (room.status != RoomStatus.waiting) throw MatchRuleViolation(MatchRule.roomNotWaiting);
    final startedAt = _b.now;
    _b._rooms[roomId] = room.copyWith(
      status: RoomStatus.running,
      startedAt: startedAt,
      endsAt: startedAt.add(_b._courseOf(room).timeLimit),
    );
    _b._notify(roomId);
  }

  @override
  Future<void> finishRoom(String roomId) async {
    await _b._network();
    final room = _ownedRoom(roomId);
    if (room.status == RoomStatus.finished) return;
    final now = _b.now;
    final endsAt = room.endsAt;
    _b._rooms[roomId] = room.copyWith(
      status: RoomStatus.finished,
      // 時間切れ後に押された場合は終了時刻を正とする。
      finishedAt: endsAt != null && endsAt.isBefore(now) ? endsAt : now,
    );
    _b._notify(roomId);
  }

  @override
  Future<Room> findRoomByCode(String code) async {
    await _b._network();
    final matches = _b._rooms.values.where((r) => r.code == code.trim()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (matches.isEmpty) throw const NotFound('参加コードが見つかりません');
    return matches.first;
  }

  @override
  Future<Participant> joinRoom({required String roomId, required String displayName}) async {
    await _b._network();
    final room = _b._room(roomId);
    if (room.ownerId == currentUserId) throw const PermissionDenied('運営は参加者になれません');
    final existing = _b._participants[roomId]![currentUserId];
    // 再起動後の再参加は同じ参加者として扱う。
    if (existing != null) return existing;
    if (room.statusAt(_b.now) != RoomStatus.waiting) throw MatchRuleViolation(MatchRule.roomNotWaiting);
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName', '名前を入力してください');
    final p = Participant(userId: currentUserId, roomId: roomId, displayName: name, joinedAt: _b.now);
    _saveParticipant(p);
    return p;
  }

  @override
  Future<Checkpoint> scanCheckpoint({required String roomId, required String qr}) async {
    await _b._network();
    final (:room, me: _) = _playing(roomId);
    return _b._courseOf(room).checkpointByQr(qr) ?? (throw MatchRuleViolation(MatchRule.wrongQr));
  }

  @override
  Future<JudgeOutcome> submitPhoto({
    required String roomId,
    required String checkpointId,
    required Uint8List photo,
  }) async {
    await _b._network();
    final (:room, :me) = _playing(roomId);
    final checkpoint = _b._courseOf(room).checkpointById(checkpointId) ?? (throw const NotFound('チェックポイントが見つかりません'));

    final submittedAt = _b.now;
    final photoRef = 'photos/$roomId/${me.userId}/${_b._newId('photo')}.jpg';
    // NetworkFailure はそのまま投げ、判定できなかった提出は残さない。参加者は同じ写真を再送できる。
    final verdict = await _b.judge.judge(checkpoint: checkpoint, photo: photo);

    _b._photos[photoRef] = photo;
    final submission = PhotoSubmission(
      id: _b._newId('submission'),
      roomId: roomId,
      participantId: me.userId,
      checkpointId: checkpoint.id,
      photoRef: photoRef,
      submittedAt: submittedAt,
      status: verdict.passed ? JudgeStatus.passed : JudgeStatus.rejected,
      reason: verdict.reason,
      judgedAt: _b.now,
    );
    _b._submissions[roomId]!.add(submission);

    if (!verdict.passed) {
      _b._notify(roomId);
      return JudgeRejected(verdict.reason);
    }

    // 判定待ちの間に別の提出で合格していることがあるため、追加の直前に確認する。
    final clears = _b._clears[roomId]!;
    final alreadyCleared = clears.any((c) => c.participantId == me.userId && c.checkpointId == checkpoint.id);
    if (!alreadyCleared) {
      clears.add(
        CheckpointClear(
          participantId: me.userId,
          checkpointId: checkpoint.id,
          points: checkpoint.points,
          clearedAt: submittedAt,
          submissionId: submission.id,
        ),
      );
    }
    _b._notify(roomId);
    return JudgePassed(
      verdict.reason,
      pointsAwarded: alreadyCleared ? 0 : checkpoint.points,
      alreadyCleared: alreadyCleared,
    );
  }

  @override
  Future<void> scanGoal({required String roomId, required String qr}) async {
    await _b._network();
    final (:room, :me) = _playing(roomId);
    final course = _b._courseOf(room);
    if (qr != course.goalQr) throw MatchRuleViolation(MatchRule.wrongQr);
    final myClears = _b._clears[roomId]!.where((c) => c.participantId == me.userId);
    if (!hasClearedAllRequired(course, myClears)) throw MatchRuleViolation(MatchRule.requiredNotCleared);
    final goalAt = _b.now;
    _saveParticipant(me.copyWith(goalAt: goalAt, goalBonus: goalBonusFor(course, room, goalAt)));
  }

  @override
  Stream<RoomSnapshot> watchRoom(String roomId) {
    StreamSubscription<String>? changes;
    late final StreamController<RoomSnapshot> controller;
    controller = StreamController(
      onListen: () async {
        try {
          await _b._network();
          final room = _b._room(roomId);
          if (room.ownerId != currentUserId) _me(roomId);
        } catch (e, st) {
          controller.addError(e, st);
          await controller.close();
          return;
        }
        if (controller.isClosed) return;
        controller.add(_b._snapshot(roomId, currentUserId));
        changes = _b._changes.stream
            .where((changed) => changed == roomId)
            .listen((_) => controller.add(_b._snapshot(roomId, currentUserId)));
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Uint8List> loadPhoto({required String roomId, required String photoRef}) async {
    await _b._network();
    final room = _b._room(roomId);
    final submission = _b._submissions[roomId]!.where((s) => s.photoRef == photoRef).firstOrNull;
    if (submission == null) throw const NotFound('写真が見つかりません');
    if (room.ownerId != currentUserId && submission.participantId != currentUserId) {
      throw const PermissionDenied();
    }
    return _b._photos[photoRef]!;
  }
}
