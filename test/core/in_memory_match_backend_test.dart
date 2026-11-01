import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/core/mock/in_memory_match_backend.dart';
import 'package:mayoi_quest/core/mock/mock_photo_judge.dart';
import 'package:mayoi_quest/core/mock/sample_course.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/repository/match_repository.dart';

void main() {
  late DateTime now;
  late ScriptedPhotoJudge judge;
  late InMemoryMatchBackend backend;
  late MatchRepository owner;
  late MatchRepository alice;
  final photo = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    now = DateTime(2026, 11, 1, 10);
    judge = ScriptedPhotoJudge();
    backend = InMemoryMatchBackend(courses: const [sampleCourse], judge: judge, clock: () => now);
    owner = backend.repositoryFor('owner');
    alice = backend.repositoryFor('alice');
  });

  /// 作成→参加→開始まで進めたルームID。
  Future<String> runningRoom() async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    await alice.joinRoom(roomId: room.id, displayName: 'アリス');
    await owner.startRoom(room.id);
    return room.id;
  }

  test('参加コードでルームを見つけて参加できる', () async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    final found = await alice.findRoomByCode(room.code);
    final p = await alice.joinRoom(roomId: found.id, displayName: ' アリス ');
    expect(p.displayName, 'アリス');

    // 再参加は同じ参加者として扱う（復帰）。
    final again = await alice.joinRoom(roomId: found.id, displayName: '別名');
    expect(again.displayName, 'アリス');
  });

  test('運営と参加者の権限を区別する', () async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    await alice.joinRoom(roomId: room.id, displayName: 'アリス');

    expect(() => alice.startRoom(room.id), throwsA(isA<PermissionDenied>()));
    expect(() => owner.joinRoom(roomId: room.id, displayName: '運営'), throwsA(isA<PermissionDenied>()));
    expect(() => backend.repositoryFor('stranger').watchRoom(room.id).first, throwsA(isA<PermissionDenied>()));
  });

  test('開始時刻と終了時刻はサーバーが決める', () async {
    final roomId = await runningRoom();
    final s = await owner.watchRoom(roomId).first;
    expect(s.room.status, RoomStatus.running);
    expect(s.room.startedAt, now);
    expect(s.room.endsAt, now.add(sampleCourse.timeLimit));
  });

  test('開始後は参加できない', () async {
    final roomId = await runningRoom();
    expect(
      () => backend.repositoryFor('bob').joinRoom(roomId: roomId, displayName: 'ボブ'),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.roomNotWaiting)),
    );
  });

  test('合格で加点し、同じチェックポイントは二重加点しない', () async {
    final roomId = await runningRoom();
    final cp = sampleCourse.checkpoints.first;

    final first = await alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo);
    expect(first, isA<JudgePassed>().having((o) => o.pointsAwarded, 'points', cp.points));

    final second = await alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo);
    expect(second, isA<JudgePassed>().having((o) => o.alreadyCleared, 'alreadyCleared', true));

    final s = await owner.watchRoom(roomId).first;
    expect(s.scoreOf('alice'), cp.points);
    expect(s.clears, hasLength(1));
    expect(s.submissions, hasLength(2));
  });

  test('同時に提出しても加点は1回だけ', () async {
    final roomId = await runningRoom();
    final cp = sampleCourse.checkpoints.first;
    final results = await Future.wait([
      alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo),
      alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo),
    ]);
    final awarded = results.whereType<JudgePassed>().fold(0, (sum, r) => sum + r.pointsAwarded);
    expect(awarded, cp.points);
  });

  test('AI不合格と通信失敗を区別する', () async {
    final roomId = await runningRoom();
    final cp = sampleCourse.checkpoints.first;

    judge.enqueueReject('対象が写っていません');
    final rejected = await alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo);
    expect(rejected, isA<JudgeRejected>().having((o) => o.reason, 'reason', '対象が写っていません'));

    judge.enqueueNetworkFailure();
    await expectLater(
      alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo),
      throwsA(isA<NetworkFailure>()),
    );

    backend.offline = true;
    await expectLater(
      alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo),
      throwsA(isA<NetworkFailure>()),
    );
    backend.offline = false;

    final s = await owner.watchRoom(roomId).first;
    // 通信失敗は提出として残らない。不合格は理由つきで残る。
    expect(s.submissions, hasLength(1));
    expect(s.submissions.single.status, JudgeStatus.rejected);
    expect(s.scoreOf('alice'), 0);
  });

  test('参加者は自分の提出だけ、運営は全員の写真を見られる', () async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    final bob = backend.repositoryFor('bob');
    for (final (repo, name) in [(alice, 'アリス'), (bob, 'ボブ')]) {
      await repo.joinRoom(roomId: room.id, displayName: name);
    }
    await owner.startRoom(room.id);
    final cp = sampleCourse.checkpoints.first;
    await alice.submitPhoto(roomId: room.id, checkpointId: cp.id, photo: photo);

    final ownerView = await owner.watchRoom(room.id).first;
    final ref = ownerView.submissions.single.photoRef;
    expect(await owner.loadPhoto(roomId: room.id, photoRef: ref), photo);
    expect((await bob.watchRoom(room.id).first).submissions, isEmpty);
    expect(() => bob.loadPhoto(roomId: room.id, photoRef: ref), throwsA(isA<PermissionDenied>()));
  });

  test('開始前はチェックポイントに進めない', () async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    await alice.joinRoom(roomId: room.id, displayName: 'アリス');
    expect(
      () => alice.scanCheckpoint(roomId: room.id, qr: sampleCourse.checkpoints.first.qr),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.roomNotRunning)),
    );
  });

  test('違うQRは受け付けない', () async {
    final roomId = await runningRoom();
    expect(
      () => alice.scanCheckpoint(roomId: roomId, qr: 'other'),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.wrongQr)),
    );
    final cp = await alice.scanCheckpoint(roomId: roomId, qr: sampleCourse.checkpoints[1].qr);
    expect(cp.id, sampleCourse.checkpoints[1].id);
  });

  test('指定チェックポイントを全てクリアするとゴールできる', () async {
    final roomId = await runningRoom();
    await expectLater(
      alice.scanGoal(roomId: roomId, qr: sampleCourse.goalQr),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.requiredNotCleared)),
    );
    for (final cp in sampleCourse.requiredCheckpoints) {
      await alice.submitPhoto(roomId: roomId, checkpointId: cp.id, photo: photo);
    }
    now = now.add(const Duration(minutes: 5));
    await alice.scanGoal(roomId: roomId, qr: sampleCourse.goalQr);

    final s = await owner.watchRoom(roomId).first;
    expect(s.participant('alice')!.goalAt, now);
    // 制限30分・開始5分後にゴール → 残り25分 × 1点。
    expect(s.participant('alice')!.goalBonus, 25);
    final checkpointPoints = sampleCourse.requiredCheckpoints.fold(0, (sum, c) => sum + c.points);
    expect(s.scoreOf('alice'), checkpointPoints + 25);
    await expectLater(
      alice.scanGoal(roomId: roomId, qr: sampleCourse.goalQr),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.alreadyFinished)),
    );
  });

  test('時間切れ後は操作できない', () async {
    final roomId = await runningRoom();
    now = now.add(sampleCourse.timeLimit);
    final s = await owner.watchRoom(roomId).first;
    expect(s.room.statusAt(now), RoomStatus.finished);
    expect(
      () => alice.submitPhoto(roomId: roomId, checkpointId: sampleCourse.checkpoints.first.id, photo: photo),
      throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.timeUp)),
    );
  });

  test('運営が終了すると参加者は操作できない', () async {
    final roomId = await runningRoom();
    await owner.finishRoom(roomId);
    final s = await owner.watchRoom(roomId).first;
    expect(s.room.status, RoomStatus.finished);
    expect(
      () => alice.scanCheckpoint(roomId: roomId, qr: sampleCourse.checkpoints.first.qr),
      throwsA(isA<MatchRuleViolation>()),
    );
  });

  test('変更は購読中の全員に流れる', () async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    final received = <int>[];
    final sub = owner.watchRoom(room.id).listen((s) => received.add(s.participants.length));
    await pumpEventQueue();
    await alice.joinRoom(roomId: room.id, displayName: 'アリス');
    await pumpEventQueue();
    await sub.cancel();
    expect(received, [0, 1]);
  });
}
