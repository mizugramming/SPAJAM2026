import 'course.dart';
import 'participant.dart';
import 'room.dart';
import 'submission.dart';

/// 1ルームの現在の状態一式。画面はこれを購読して描画する。
class RoomSnapshot {
  const RoomSnapshot({
    required this.room,
    required this.course,
    required this.participants,
    required this.clears,
    required this.submissions,
  });

  final Room room;
  final Course course;
  final List<Participant> participants;
  final List<CheckpointClear> clears;
  final List<PhotoSubmission> submissions;

  Participant? participant(String userId) {
    for (final p in participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  List<CheckpointClear> clearsOf(String userId) => clears.where((c) => c.participantId == userId).toList();

  List<PhotoSubmission> submissionsOf(String userId) => submissions.where((s) => s.participantId == userId).toList();

  /// チェックポイントの得点の合計。
  int checkpointScoreOf(String userId) => clearsOf(userId).fold(0, (sum, c) => sum + c.points);

  /// 合計得点：チェックポイントの得点＋ゴールボーナス。
  int scoreOf(String userId) => checkpointScoreOf(userId) + (participant(userId)?.goalBonus ?? 0);
}
