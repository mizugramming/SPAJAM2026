class Participant {
  const Participant({
    required this.userId,
    required this.roomId,
    required this.displayName,
    required this.joinedAt,
    this.goalAt,
    this.goalBonus = 0,
  });

  final String userId;
  final String roomId;
  final String displayName;
  final DateTime joinedAt;
  final DateTime? goalAt;

  /// ゴール時の残り時間に応じたボーナス点。サーバーがゴール時に確定する。
  final int goalBonus;

  bool get hasFinished => goalAt != null;

  Participant copyWith({DateTime? goalAt, int? goalBonus}) {
    return Participant(
      userId: userId,
      roomId: roomId,
      displayName: displayName,
      joinedAt: joinedAt,
      goalAt: goalAt ?? this.goalAt,
      goalBonus: goalBonus ?? this.goalBonus,
    );
  }
}
