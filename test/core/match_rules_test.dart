import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/core/mock/sample_course.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/rules/match_rules.dart';

void main() {
  final t0 = DateTime(2026, 11, 1, 10);

  Participant player(String id, {DateTime? goalAt, int joinOrder = 0}) => Participant(
    userId: id,
    roomId: 'r',
    displayName: id,
    joinedAt: t0.add(Duration(seconds: joinOrder)),
    goalAt: goalAt,
  );

  CheckpointClear clear(String userId, String cpId, int points) =>
      CheckpointClear(participantId: userId, checkpointId: cpId, points: points, clearedAt: t0, submissionId: 's');

  RoomSnapshot snapshot(List<Participant> ps, List<CheckpointClear> clears) => RoomSnapshot(
    room: Room(id: 'r', code: '123456', courseId: 'sample', ownerId: 'o', status: RoomStatus.running, createdAt: t0),
    course: sampleCourse,
    participants: ps,
    clears: clears,
    submissions: const [],
  );

  test('指定チェックポイントが全てそろうとゴール条件を満たす', () {
    final required = sampleCourse.requiredCheckpoints.toList();
    expect(hasClearedAllRequired(sampleCourse, [clear('a', required.first.id, 10)]), isFalse);
    expect(hasClearedAllRequired(sampleCourse, [for (final c in required) clear('a', c.id, 10)]), isTrue);
  });

  test('順位は得点→ゴール済み→ゴールが早い順', () {
    final s = snapshot(
      [
        player('slow', goalAt: t0.add(const Duration(minutes: 20))),
        player('fast', goalAt: t0.add(const Duration(minutes: 10)), joinOrder: 1),
        player('high', joinOrder: 2),
        player('none', joinOrder: 3),
      ],
      [clear('high', 'cp-a', 30), clear('slow', 'cp-a', 10), clear('fast', 'cp-a', 10)],
    );
    final order = standingsOf(s).map((st) => (st.participant.userId, st.rank)).toList();
    expect(order, [('high', 1), ('fast', 2), ('slow', 3), ('none', 4)]);
  });

  test('得点もゴール時刻も同じなら同順位', () {
    final s = snapshot([player('a'), player('b', joinOrder: 1)], const []);
    expect(standingsOf(s).map((st) => st.rank), [1, 1]);
  });
}
