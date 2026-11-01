enum JudgeStatus { pending, passed, rejected }

/// 撮影写真の提出とAI判定結果。通信失敗は提出として残らない。
class PhotoSubmission {
  const PhotoSubmission({
    required this.id,
    required this.roomId,
    required this.participantId,
    required this.checkpointId,
    required this.photoRef,
    required this.submittedAt,
    required this.status,
    this.reason,
    this.judgedAt,
  });

  final String id;
  final String roomId;
  final String participantId;
  final String checkpointId;

  /// 保存先での写真の参照。表示は MatchRepository.loadPhoto で取得する。
  final String photoRef;
  final DateTime submittedAt;
  final JudgeStatus status;

  /// AIの判定理由。運営画面で閲覧する。
  final String? reason;
  final DateTime? judgedAt;
}

/// チェックポイントのクリア記録。参加者×チェックポイントで1件だけ存在し、二重加点を防ぐ。
class CheckpointClear {
  const CheckpointClear({
    required this.participantId,
    required this.checkpointId,
    required this.points,
    required this.clearedAt,
    required this.submissionId,
  });

  final String participantId;
  final String checkpointId;
  final int points;
  final DateTime clearedAt;
  final String submissionId;
}
