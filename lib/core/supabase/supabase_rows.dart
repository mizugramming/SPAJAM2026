import '../models/models.dart';

/// 接続仕様（docs/system_design.md）の行を共通モデルへ変換する。

typedef Row = Map<String, dynamic>;

DateTime _time(Object? v) => DateTime.parse(v! as String).toLocal();
DateTime? _timeOrNull(Object? v) => v == null ? null : _time(v);

/// rpc の戻り値は1行の json か、1行だけの配列のどちらでも受け付ける。
Row singleRow(Object? data) => switch (data) {
  final Map<String, dynamic> m => m,
  [final Map<String, dynamic> m, ...] => m,
  _ => throw const NotFound(),
};

Course courseFromRows(Row course, List<Row> checkpoints) {
  final sorted = [...checkpoints]..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
  return Course(
    id: course['id'] as String,
    name: course['name'] as String,
    startQr: course['start_qr'] as String,
    goalQr: course['goal_qr'] as String,
    timeLimit: Duration(seconds: course['time_limit_seconds'] as int),
    checkpoints: [
      for (final c in sorted)
        Checkpoint(
          id: c['id'] as String,
          name: c['name'] as String,
          floor: c['floor'] as String,
          qr: c['qr'] as String,
          mission: c['mission'] as String,
          points: c['points'] as int,
          required: c['required'] as bool,
        ),
    ],
  );
}

Room roomFromRow(Row r) => Room(
  id: r['id'] as String,
  code: r['code'] as String,
  courseId: r['course_id'] as String,
  ownerId: r['owner_id'] as String,
  status: RoomStatus.values.byName(r['status'] as String),
  createdAt: _time(r['created_at']),
  startedAt: _timeOrNull(r['started_at']),
  endsAt: _timeOrNull(r['ends_at']),
  finishedAt: _timeOrNull(r['finished_at']),
);

Participant participantFromRow(Row r) => Participant(
  userId: r['user_id'] as String,
  roomId: r['room_id'] as String,
  displayName: r['display_name'] as String,
  joinedAt: _time(r['joined_at']),
  startScannedAt: _timeOrNull(r['start_scanned_at']),
  goalAt: _timeOrNull(r['goal_at']),
);

PhotoSubmission submissionFromRow(Row r) => PhotoSubmission(
  id: r['id'] as String,
  roomId: r['room_id'] as String,
  participantId: r['participant_id'] as String,
  checkpointId: r['checkpoint_id'] as String,
  photoRef: r['photo_path'] as String,
  submittedAt: _time(r['submitted_at']),
  status: JudgeStatus.values.byName(r['status'] as String),
  reason: r['reason'] as String?,
  judgedAt: _timeOrNull(r['judged_at']),
);

CheckpointClear clearFromRow(Row r) => CheckpointClear(
  participantId: r['participant_id'] as String,
  checkpointId: r['checkpoint_id'] as String,
  points: r['points'] as int,
  clearedAt: _time(r['cleared_at']),
  submissionId: r['submission_id'] as String,
);
