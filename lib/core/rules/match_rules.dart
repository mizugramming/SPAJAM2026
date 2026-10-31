import '../models/course.dart';
import '../models/participant.dart';
import '../models/room_snapshot.dart';
import '../models/submission.dart';

/// 得点・ゴール・順位の判定。サーバー側（Supabase）の処理もこの規則に合わせる。

bool hasClearedAllRequired(Course course, Iterable<CheckpointClear> clears) {
  final cleared = clears.map((c) => c.checkpointId).toSet();
  return course.requiredCheckpoints.every((c) => cleared.contains(c.id));
}

class Standing {
  const Standing({required this.rank, required this.participant, required this.score, required this.clearedCount});

  final int rank;
  final Participant participant;
  final int score;
  final int clearedCount;
}

/// 暫定の順位：得点の高い順 → ゴール済みが先 → ゴールが早い順。
/// 順位の決め方は未確定（docs/system_design.md）。
List<Standing> standingsOf(RoomSnapshot snapshot) {
  final rows = [
    for (final p in snapshot.participants)
      (p: p, score: snapshot.scoreOf(p.userId), cleared: snapshot.clearsOf(p.userId).length),
  ];
  rows.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final aGoal = a.p.goalAt, bGoal = b.p.goalAt;
    if (aGoal != null && bGoal != null) return aGoal.compareTo(bGoal);
    if (aGoal != null) return -1;
    if (bGoal != null) return 1;
    return a.p.joinedAt.compareTo(b.p.joinedAt);
  });

  final result = <Standing>[];
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final prev = i > 0 ? rows[i - 1] : null;
    final tied = prev != null && prev.score == r.score && prev.p.goalAt == r.p.goalAt;
    result.add(
      Standing(rank: tied ? result.last.rank : i + 1, participant: r.p, score: r.score, clearedCount: r.cleared),
    );
  }
  return result;
}
