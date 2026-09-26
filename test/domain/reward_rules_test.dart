import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/domain/reward_rules.dart';

const profile = Profile(nickname: '同じ名前', hobby: '音楽', comment: '');
const red = Participant(id: 'red', profile: profile, team: Team.red);
const blue = Participant(id: 'blue', profile: profile, team: Team.blue);
const third = Participant(id: 'third', profile: profile, team: Team.red);

Follower normal(String ownerId, String peerId) => Follower(
  id: '$ownerId:$peerId',
  ownerId: ownerId,
  peerId: peerId,
  profile: profile,
  kind: FollowerKind.normal,
  ordinal: 1,
);

void main() {
  const rules = RewardRules();

  test('同名を別IDで集計し同戦力は同順位・共同MVP、最終戦は引き分け', () {
    final snapshot = rules.summarize(
      [red, blue, third],
      {
        red.id: [normal(red.id, blue.id)],
        blue.id: [normal(blue.id, red.id)],
      },
    );
    expect(snapshot.redPower, 3);
    expect(snapshot.bluePower, 3);
    expect(snapshot.isDraw, isTrue);
    expect(snapshot.winnerTeam, isNull);
    expect(snapshot.rankings.map((row) => row.rank), [1, 1, 3]);
    expect(snapshot.mvpIds, unorderedEquals([red.id, blue.id]));
    expect(() => snapshot.rankings.clear(), throwsUnsupportedError);
    expect(() => snapshot.mvpIds.add('other'), throwsUnsupportedError);
  });

  test('二人の報酬を一括計算し元のコレクションを書き換えない', () {
    final first = <Follower>[];
    final second = <Follower>[];
    final result = rules.settle(
      self: red,
      peer: blue,
      outcome: Outcome.win,
      selfFollowers: first,
      peerFollowers: second,
    );
    expect(first, isEmpty);
    expect(second, isEmpty);
    expect(result.selfFollowers.single.power, 3);
    expect(result.peerFollowers.single.power, 1);
    expect(result.selfFollowers.single.peerId, blue.id);
    expect(result.peerFollowers.single.peerId, red.id);
    expect(result.peerResult.outcome, Outcome.loss);
    expect(() => result.selfFollowers.clear(), throwsUnsupportedError);
    expect(
      () => rules.settle(
        self: red,
        peer: blue,
        outcome: Outcome.win,
        selfFollowers: result.selfFollowers,
        peerFollowers: result.peerFollowers,
      ),
      throwsStateError,
    );
  });

  test('成長対象はリスト順でなく古い取得順から決める', () {
    Follower bone(String id, int ordinal) => Follower(
      id: id,
      ownerId: red.id,
      peerId: id,
      profile: Profile(nickname: id, hobby: '趣味', comment: 'ひとこと'),
      kind: FollowerKind.bone,
      ordinal: ordinal,
    );
    final newer = bone('newer', 2);
    final older = bone('older', 1);
    final result = rules.settle(
      self: red,
      peer: third,
      outcome: Outcome.coopSuccess,
      selfFollowers: [newer, older],
      peerFollowers: const [],
    );
    expect(result.selfResult.promoted!.id, older.id);
    expect(result.selfResult.promoted!.profile, same(older.profile));
    expect(result.selfFollowers.first.kind, FollowerKind.bone);
    expect(result.selfFollowers.last.ordinal, older.ordinal);
    expect(result.selfFollowers.length, 2);
    expect(result.selfResult.newFollower, isNull);
    expect(result.selfResult.delta, 2);
    expect(result.selfResult.rewardFollower, same(result.selfResult.promoted));
    expect(result.selfResult.promoted!.revivedWith, same(third));
    expect(result.selfResult.promoted!.peerId, older.peerId);
    expect(older.kind, FollowerKind.bone);
    expect(older.revivedWith, isNull);
  });

  for (final selfHasBone in [false, true]) {
    for (final peerHasBone in [false, true]) {
      test('協力成功は各自の手持ちで分岐する: 自分の骨=$selfHasBone 相手の骨=$peerHasBone', () {
        Follower bone(Participant owner) => Follower(
          id: '${owner.id}:past',
          ownerId: owner.id,
          peerId: 'past',
          profile: const Profile(
            nickname: '前に出会った人',
            hobby: '本',
            comment: 'またね',
          ),
          kind: FollowerKind.bone,
          ordinal: 4,
        );
        final selfBefore = [if (selfHasBone) bone(red)];
        final peerBefore = [if (peerHasBone) bone(third)];
        final result = rules.settle(
          self: red,
          peer: third,
          outcome: Outcome.coopSuccess,
          selfFollowers: selfBefore,
          peerFollowers: peerBefore,
        );

        void verifyReward(
          List<Follower> before,
          List<Follower> after,
          EncounterResult reward,
          Participant helper,
        ) {
          expect(after, hasLength(1));
          final follower = after.single;
          expect(follower.kind, FollowerKind.normal);
          expect(reward.rewardFollower, same(follower));
          if (before.isEmpty) {
            expect(reward.delta, 3);
            expect(reward.promoted, isNull);
            expect(reward.newFollower, same(follower));
            expect(follower.peerId, helper.id);
            expect(follower.profile, same(helper.profile));
            expect(follower.revivedWith, isNull);
          } else {
            final original = before.single;
            expect(reward.delta, 2);
            expect(reward.newFollower, isNull);
            expect(reward.promoted, same(follower));
            expect(follower.id, original.id);
            expect(follower.ownerId, original.ownerId);
            expect(follower.peerId, original.peerId);
            expect(follower.profile, same(original.profile));
            expect(follower.ordinal, original.ordinal);
            expect(follower.revivedWith, same(helper));
            expect(original.kind, FollowerKind.bone);
          }
        }

        verifyReward(
          selfBefore,
          result.selfFollowers,
          result.selfResult,
          third,
        );
        verifyReward(peerBefore, result.peerFollowers, result.peerResult, red);
        expect(
          () => rules.settle(
            self: red,
            peer: third,
            outcome: Outcome.coopSuccess,
            selfFollowers: result.selfFollowers,
            peerFollowers: result.peerFollowers,
          ),
          throwsStateError,
        );
        final snapshot = rules.summarize(
          [red, third],
          {red.id: result.selfFollowers, third.id: result.peerFollowers},
        );
        expect(snapshot.redPower, 6);
        expect(snapshot.rankings.every((row) => row.normalCount == 1), isTrue);
        expect(snapshot.rankings.every((row) => row.boneCount == 0), isTrue);
      });
    }
  }

  test('復活相手の記録だけが片側に残る場合も二重決済を拒否する', () {
    Follower revived(Participant owner, Participant helper) => Follower(
      id: '${owner.id}:past',
      ownerId: owner.id,
      peerId: 'past',
      profile: profile,
      kind: FollowerKind.normal,
      ordinal: 1,
      revivedWith: helper,
    );
    for (final recordedOnSelf in [false, true]) {
      expect(
        () => rules.settle(
          self: red,
          peer: third,
          outcome: Outcome.coopSuccess,
          selfFollowers: [if (recordedOnSelf) revived(red, third)],
          peerFollowers: [if (!recordedOnSelf) revived(third, red)],
        ),
        throwsStateError,
      );
    }
  });

  test('協力失敗は手持ちの骨を変更せず双方に相手の骨を1匹追加する', () {
    final oldBone = Follower(
      id: 'red:past',
      ownerId: red.id,
      peerId: 'past',
      profile: profile,
      kind: FollowerKind.bone,
      ordinal: 7,
    );
    final result = rules.settle(
      self: red,
      peer: third,
      outcome: Outcome.coopFailure,
      selfFollowers: [oldBone],
      peerFollowers: const [],
    );
    expect(result.selfFollowers, hasLength(2));
    expect(result.selfFollowers.first, same(oldBone));
    expect(result.selfFollowers.last.ordinal, 8);
    expect(result.selfResult.promoted, isNull);
    expect(result.selfResult.newFollower!.peerId, third.id);
    expect(result.selfResult.rewardFollower.kind, FollowerKind.bone);
    expect(result.selfResult.delta, 1);
    expect(result.peerFollowers.single.peerId, red.id);
    expect(result.peerResult.promoted, isNull);
    expect(result.peerResult.rewardFollower.kind, FollowerKind.bone);
    expect(result.peerResult.delta, 1);
  });
}
