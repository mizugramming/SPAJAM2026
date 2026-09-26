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
    expect(result.selfFollowers.last.ordinal, 3);
    expect(result.selfFollowers.length, 3);
  });
}
