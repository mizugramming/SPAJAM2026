enum RoomStatus { waiting, running, finished }

/// 対戦ルーム。開始・終了時刻はサーバー側の時刻を正本とする。
class Room {
  const Room({
    required this.id,
    required this.code,
    required this.courseId,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endsAt,
    this.finishedAt,
  });

  final String id;

  /// 参加者が入力する参加コード。
  final String code;
  final String courseId;

  /// ルームを作成した運営ユーザー。権限判定に使う。
  final String ownerId;
  final RoomStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final DateTime? finishedAt;

  /// 時間切れを反映した状態。保存値が running でも終了時刻を過ぎていれば finished。
  RoomStatus statusAt(DateTime now) {
    if (status == RoomStatus.running && endsAt != null && !now.isBefore(endsAt!)) {
      return RoomStatus.finished;
    }
    return status;
  }

  Room copyWith({RoomStatus? status, DateTime? startedAt, DateTime? endsAt, DateTime? finishedAt}) {
    return Room(
      id: id,
      code: code,
      courseId: courseId,
      ownerId: ownerId,
      status: status ?? this.status,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}
