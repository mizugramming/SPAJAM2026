import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/supabase/supabase_errors.dart';
import 'package:mayoi_quest/core/supabase/supabase_rows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('エラーの変換', () {
    test('MQ:コードはルール違反・権限・未発見になる', () {
      expect(
        toMatchException(const PostgrestException(message: 'MQ:roomNotRunning')),
        isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.roomNotRunning),
      );
      expect(toMatchException(const PostgrestException(message: 'MQ:permission')), isA<PermissionDenied>());
      expect(toMatchException(const PostgrestException(message: 'MQ:notFound')), isA<NotFound>());
      expect(
        toMatchException(const FunctionException(status: 409, details: {'error': 'MQ:alreadyFinished'})),
        isA<MatchRuleViolation>().having((e) => e.rule, 'rule', MatchRule.alreadyFinished),
      );
    });

    test('AI判定に届かない503は通信失敗', () {
      expect(
        toMatchException(const FunctionException(status: 503, details: {'error': 'judge_unavailable'})),
        isA<NetworkFailure>(),
      );
    });

    test('RLS・Storageの拒否は権限エラー', () {
      expect(toMatchException(const PostgrestException(message: 'denied', code: '42501')), isA<PermissionDenied>());
      expect(toMatchException(const StorageException('denied', statusCode: '403')), isA<PermissionDenied>());
    });

    test('それ以外は通信失敗', () {
      expect(toMatchException(Exception('socket closed')), isA<NetworkFailure>());
    });
  });

  group('行の変換', () {
    test('ルームと参加者', () {
      final room = roomFromRow({
        'id': 'r1',
        'code': '123456',
        'course_id': 'sample',
        'owner_id': 'u1',
        'status': 'running',
        'created_at': '2026-11-01T01:00:00+00:00',
        'started_at': '2026-11-01T01:05:00+00:00',
        'ends_at': '2026-11-01T01:35:00+00:00',
        'finished_at': null,
      });
      expect(room.status, RoomStatus.running);
      expect(room.endsAt!.difference(room.startedAt!), const Duration(minutes: 30));
      expect(room.finishedAt, isNull);

      final p = participantFromRow({
        'room_id': 'r1',
        'user_id': 'u2',
        'display_name': 'アリス',
        'joined_at': '2026-11-01T01:01:00Z',
        'start_scanned_at': null,
        'goal_at': null,
      });
      expect(p.isReady, isFalse);
    });

    test('コースはチェックポイントを並び順で持つ', () {
      final course = courseFromRows(
        {'id': 'c', 'name': 'コース', 'start_qr': 's', 'goal_qr': 'g', 'time_limit_seconds': 1800},
        [
          for (final (id, order) in [('b', 2), ('a', 1)])
            {
              'id': id,
              'course_id': 'c',
              'name': id,
              'floor': '1F',
              'qr': 'qr-$id',
              'mission': 'm',
              'points': 10,
              'required': true,
              'sort_order': order,
            },
        ],
      );
      expect(course.checkpoints.map((c) => c.id), ['a', 'b']);
      expect(course.timeLimit, const Duration(minutes: 30));
    });

    test('rpcの戻り値は1行のjsonでも配列でもよい', () {
      expect(singleRow({'id': 'x'})['id'], 'x');
      expect(
        singleRow([
          {'id': 'y'},
        ])['id'],
        'y',
      );
      expect(() => singleRow(const []), throwsA(isA<NotFound>()));
    });
  });
}
