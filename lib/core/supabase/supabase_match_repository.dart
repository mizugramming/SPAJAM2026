import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repository/match_repository.dart';
import 'supabase_errors.dart';
import 'supabase_rows.dart';

/// Supabase を使う MatchRepository。接続仕様は docs/system_design.md。
/// 書き込みはすべてサーバーの関数・Edge Function に任せ、アプリは結果を読むだけ。
class SupabaseMatchRepository implements MatchRepository {
  SupabaseMatchRepository(this._client);

  final SupabaseClient _client;
  final _courses = <String, Course>{};

  static const _photoBucket = 'photos';

  @override
  String get currentUserId => _client.auth.currentUser!.id;

  Future<Object?> _rpc(String fn, Map<String, dynamic> params) => guard(() => _client.rpc(fn, params: params));

  @override
  Future<List<Course>> listCourses() => guard(() async {
    final courses = await _client.from('courses').select().order('id');
    final checkpoints = await _client.from('checkpoints').select();
    final result = [
      for (final c in courses) courseFromRows(c, checkpoints.where((cp) => cp['course_id'] == c['id']).toList()),
    ];
    _courses
      ..clear()
      ..addEntries(result.map((c) => MapEntry(c.id, c)));
    return result;
  });

  Future<Course> _course(String courseId) async {
    final cached = _courses[courseId];
    if (cached != null) return cached;
    await listCourses();
    return _courses[courseId] ?? (throw const NotFound('コースが見つかりません'));
  }

  @override
  Future<Room> createRoom({required String courseId}) async =>
      roomFromRow(singleRow(await _rpc('create_room', {'p_course_id': courseId})));

  @override
  Future<void> startRoom(String roomId) => _rpc('start_room', {'p_room_id': roomId});

  @override
  Future<void> finishRoom(String roomId) => _rpc('finish_room', {'p_room_id': roomId});

  @override
  Future<Room> findRoomByCode(String code) async =>
      roomFromRow(singleRow(await _rpc('find_room_by_code', {'p_code': code.trim()})));

  @override
  Future<Participant> joinRoom({required String roomId, required String displayName}) async {
    final name = displayName.trim();
    if (name.isEmpty) throw ArgumentError.value(displayName, 'displayName', '名前を入力してください');
    return participantFromRow(singleRow(await _rpc('join_room', {'p_room_id': roomId, 'p_display_name': name})));
  }

  @override
  Future<Checkpoint> scanCheckpoint({required String roomId, required String qr}) async {
    final checkpointId = await _rpc('scan_checkpoint', {'p_room_id': roomId, 'p_qr': qr}) as String;
    final room = await _fetchRoom(roomId);
    final course = await _course(room.courseId);
    return course.checkpointById(checkpointId) ?? (throw const NotFound('チェックポイントが見つかりません'));
  }

  @override
  Future<JudgeOutcome> submitPhoto({required String roomId, required String checkpointId, required Uint8List photo}) =>
      guard(() async {
        final path = '$roomId/$currentUserId/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await _client.storage
            .from(_photoBucket)
            .uploadBinary(path, photo, fileOptions: const FileOptions(contentType: 'image/jpeg'));
        final response = await _client.functions.invoke(
          'judge-photo',
          body: {'room_id': roomId, 'checkpoint_id': checkpointId, 'photo_path': path},
        );
        final data = response.data as Map<String, dynamic>;
        final reason = data['reason'] as String? ?? '';
        return switch (data['outcome']) {
          'passed' => JudgePassed(
            reason,
            pointsAwarded: data['points_awarded'] as int? ?? 0,
            alreadyCleared: data['already_cleared'] as bool? ?? false,
          ),
          'rejected' => JudgeRejected(reason),
          _ => throw const NetworkFailure('AI判定の応答が不正です'),
        };
      });

  @override
  Future<void> scanGoal({required String roomId, required String qr}) =>
      _rpc('scan_goal', {'p_room_id': roomId, 'p_qr': qr});

  @override
  Future<Uint8List> loadPhoto({required String roomId, required String photoRef}) =>
      guard(() => _client.storage.from(_photoBucket).download(photoRef));

  Future<Room> _fetchRoom(String roomId) => guard(() async {
    final row = await _client.from('rooms').select().eq('id', roomId).maybeSingle();
    // RLS で見えない場合も null になる。
    return row == null ? throw const NotFound('ルームが見つかりません') : roomFromRow(row);
  });

  Future<RoomSnapshot> _fetchSnapshot(String roomId) async {
    final room = await _fetchRoom(roomId);
    return guard(() async {
      final (course, participants, clears, submissions) = await (
        _course(room.courseId),
        _client.from('participants').select().eq('room_id', roomId).order('joined_at'),
        _client.from('checkpoint_clears').select().eq('room_id', roomId),
        _client.from('submissions').select().eq('room_id', roomId).order('submitted_at'),
      ).wait;
      return RoomSnapshot(
        room: room,
        course: course,
        participants: participants.map(participantFromRow).toList(),
        clears: clears.map(clearFromRow).toList(),
        submissions: submissions.map(submissionFromRow).toList(),
      );
    });
  }

  /// Realtime の通知が抜けた場合でも、この間隔で読み直して追いつく。
  static const _pollInterval = Duration(seconds: 10);

  @override
  Stream<RoomSnapshot> watchRoom(String roomId) {
    RealtimeChannel? channel;
    Timer? poll;
    late final StreamController<RoomSnapshot> controller;
    var fetching = false;
    var fetchAgain = false;

    // 変更通知が続いても読み直しは1本ずつにし、最後の変更を必ず反映する。
    Future<void> refresh() async {
      if (fetching) {
        fetchAgain = true;
        return;
      }
      fetching = true;
      do {
        fetchAgain = false;
        try {
          final snapshot = await _fetchSnapshot(roomId);
          if (!controller.isClosed) controller.add(snapshot);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(toMatchException(e), st);
        }
      } while (fetchAgain && !controller.isClosed);
      fetching = false;
    }

    void listen(String table, String column) {
      channel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: column, value: roomId),
        callback: (_) => refresh(),
      );
    }

    controller = StreamController(
      onListen: () {
        channel = _client.channel('room:$roomId');
        listen('rooms', 'id');
        listen('participants', 'room_id');
        listen('checkpoint_clears', 'room_id');
        listen('submissions', 'room_id');
        channel!.subscribe((status, error) {
          // 購読開始・再接続のたびに読み直し、切断中の変更を取りこぼさない。
          if (status == RealtimeSubscribeStatus.subscribed) refresh();
        });
        // 購読直後や通信が不安定なときは通知が届かないことがあるため、定期的にも読み直す。
        poll = Timer.periodic(_pollInterval, (_) => refresh());
        refresh();
      },
      onCancel: () async {
        poll?.cancel();
        final c = channel;
        if (c != null) await _client.removeChannel(c);
      },
    );
    return controller.stream;
  }
}
