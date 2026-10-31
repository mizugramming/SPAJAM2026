class Participant {
  const Participant({
    required this.userId,
    required this.roomId,
    required this.displayName,
    required this.joinedAt,
    this.startScannedAt,
    this.goalAt,
  });

  final String userId;
  final String roomId;
  final String displayName;
  final DateTime joinedAt;

  /// 共通スタートQRを読んだ時刻。運営の待機画面で準備済みとして表示する。
  final DateTime? startScannedAt;

  final DateTime? goalAt;

  bool get isReady => startScannedAt != null;
  bool get hasFinished => goalAt != null;

  Participant copyWith({DateTime? startScannedAt, DateTime? goalAt}) {
    return Participant(
      userId: userId,
      roomId: roomId,
      displayName: displayName,
      joinedAt: joinedAt,
      startScannedAt: startScannedAt ?? this.startScannedAt,
      goalAt: goalAt ?? this.goalAt,
    );
  }
}
