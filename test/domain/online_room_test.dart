import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/online_room.dart';

Map<String, Object?> participant(String id, {Object? ready = true}) => {
  'id': id,
  'team': 'red',
  'profile': {'nickname': id, 'hobby': '音楽', 'comment': ''},
  'ready': ?ready,
};
Map<String, dynamic> snapshot() => {
  'code': 'ABCDEF012345',
  'mode': 'presentation',
  'status': 'lobby',
  'hostId': 'self',
  'selfId': 'self',
  'pairCode': 'ABCDEF01',
  'revision': 1,
  'serverNow': 1000,
  'participants': [participant('self')],
  'followers': [],
};

void main() {
  test('旧snapshotに応援メンバーがなくても従来の実参加者を読み込む', () {
    final room = OnlineRoom.fromJson(snapshot());
    expect(room.participants.single.id, 'self');
    expect(room.demoParticipants, isEmpty);
    expect(room.isProfileReady(room.participants.single), isTrue);
  });

  test('デモの人数と得点は実参加者・本人の子分とは別に保持する', () {
    final room = OnlineRoom.fromJson({
      ...snapshot(),
      'demoParticipants': [
        {
          ...participant('demo-red', ready: false),
          'normalCount': 1,
          'boneCount': 1,
          'power': 4,
          'playable': true,
          'busy': true,
          'nextKind': 'coop',
        },
        {
          ...participant('reserved', ready: false),
          'normalCount': 0,
          'boneCount': 0,
          'power': 0,
          'playable': false,
          'nextKind': null,
        },
      ],
    });
    expect(room.participants, hasLength(1));
    expect(room.followers, isEmpty);
    expect(room.readyParticipantIds, {'self'});
    final bot = room.demoParticipants.first;
    expect(bot.participant.id, 'demo-red');
    expect(bot.participant.isSelf, isFalse);
    expect(bot.normalCount, 1);
    expect(bot.boneCount, 1);
    expect(bot.power, 4);
    expect(bot.playable, isTrue);
    expect(bot.busy, isTrue);
    expect(bot.nextKind, 'coop');
    expect(room.demoParticipants.last.playable, isFalse);
    expect(room.demoParticipants.last.nextKind, isNull);
    expect(() => room.demoParticipants.clear(), throwsUnsupportedError);
    expect(() => room.readyParticipantIds.clear(), throwsUnsupportedError);
  });

  test('readyが明示falseならプロフィール文字列だけで準備完了にしない', () {
    final room = OnlineRoom.fromJson({
      ...snapshot(),
      'participants': [participant('self', ready: false)],
    });
    expect(room.isProfileReady(room.participants.single), isFalse);
    final legacy = OnlineRoom.fromJson({
      ...snapshot(),
      'participants': [participant('self', ready: null)],
    });
    expect(legacy.isProfileReady(legacy.participants.single), isTrue);
  });

  test('readyがtrueでも空の必須項目では開始できない', () {
    final room = OnlineRoom.fromJson({
      ...snapshot(),
      'participants': [
        {
          ...participant('self'),
          'profile': {'nickname': ' ', 'hobby': '音楽', 'comment': ''},
        },
      ],
    });
    expect(room.isProfileReady(room.participants.single), isFalse);
  });
}
