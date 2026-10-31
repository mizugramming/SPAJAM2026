// 実際の Supabase に接続して SupabaseMatchRepository を確認する。テスト用の匿名ユーザーとルームを作る。
// 実行：flutter test test/live --dart-define-from-file=config/supabase.json
// 接続設定がなければスキップする（CI では動かない）。
@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/repository/match_repository.dart';
import 'package:mayoi_quest/core/supabase/supabase_match_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<SupabaseMatchRepository> _signedIn() async {
  final client = SupabaseClient(
    _url,
    _key,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit, autoRefreshToken: false),
  );
  await client.auth.signInAnonymously();
  return SupabaseMatchRepository(client);
}

/// 条件を満たすスナップショットが届くまで待つ。
Future<RoomSnapshot> _until(Stream<RoomSnapshot> stream, bool Function(RoomSnapshot) test, [String step = '']) {
  debugPrint('待機中: $step');
  return stream.firstWhere(test).timeout(const Duration(seconds: 20));
}

void main() {
  final skip = _url.isEmpty || _key.isEmpty ? 'config/supabase.json が渡されていない' : null;

  test(
    '運営と参加者で一連の流れが動き、変更が Realtime で届く',
    () async {
      final owner = await _signedIn();
      final player = await _signedIn();

      final courses = await owner.listCourses();
      final course = courses.firstWhere((c) => c.id == 'sample');

      final room = await owner.createRoom(courseId: course.id);
      expect(room.status, RoomStatus.waiting);
      expect(room.ownerId, owner.currentUserId);

      // 運営の画面と同じく、ルームを購読しておく。
      final ownerView = owner.watchRoom(room.id).asBroadcastStream();
      debugPrint('待機中: 最初の状態');
      final first = await ownerView.first.timeout(const Duration(seconds: 20));
      expect(first.participants, isEmpty);

      final found = await player.findRoomByCode(room.code);
      expect(found.id, room.id);
      await player.joinRoom(roomId: room.id, displayName: 'ライブテスト');
      final joined = await _until(ownerView, (s) => s.participants.length == 1, '参加');
      expect(joined.participants.single.displayName, 'ライブテスト');

      await expectLater(player.startRoom(room.id), throwsA(isA<PermissionDenied>()));

      await player.scanStart(roomId: room.id, qr: course.startQr);
      await _until(ownerView, (s) => s.participants.single.isReady, 'スタートQR');

      await owner.startRoom(room.id);
      final running = await _until(ownerView, (s) => s.room.status == RoomStatus.running, '開始');
      expect(running.room.endsAt!.difference(running.room.startedAt!), course.timeLimit);

      final cp = await player.scanCheckpoint(roomId: room.id, qr: course.checkpoints.first.qr);
      expect(cp.id, course.checkpoints.first.id);
      await expectLater(
        player.scanCheckpoint(roomId: room.id, qr: 'wrong'),
        throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.wrongQr)),
      );
      await expectLater(
        player.scanGoal(roomId: room.id, qr: course.goalQr),
        throwsA(isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.requiredNotCleared)),
      );

      // 写真の判定（結果は AI 次第なので、合格・不合格のどちらかが記録されることだけ確認する）。
      final outcome = await player.submitPhoto(roomId: room.id, checkpointId: cp.id, photo: _grayJpeg);
      expect(outcome, anyOf(isA<JudgePassed>(), isA<JudgeRejected>()));
      final judged = await _until(ownerView, (s) => s.submissions.isNotEmpty, '提出');
      final submission = judged.submissions.single;
      expect(submission.reason, isNotEmpty);
      final photo = await owner.loadPhoto(roomId: room.id, photoRef: submission.photoRef);
      expect(photo, isNotEmpty);

      // 参加者には自分の提出だけが見える。
      final playerSnapshot = await player.watchRoom(room.id).first.timeout(const Duration(seconds: 20));
      expect(playerSnapshot.submissions.every((s) => s.participantId == player.currentUserId), isTrue);

      await owner.finishRoom(room.id);
      await _until(ownerView, (s) => s.room.status == RoomStatus.finished, '終了');
      await expectLater(
        player.scanCheckpoint(roomId: room.id, qr: course.checkpoints.first.qr),
        throwsA(isA<MatchRuleViolation>()),
      );
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

/// 640x480 の灰色 JPEG（短辺 480px 以上なので判定まで進む）。
final Uint8List _grayJpeg = File('test/live/gray_640x480.jpg').readAsBytesSync();
