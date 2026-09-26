import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/models.dart';

DemoController started({Duration duration = const Duration(minutes: 5)}) {
  final controller = DemoController(autoTick: false);
  controller.createRoom(duration);
  controller.setProfile(nickname: 'わたし', hobby: '読書', comment: 'よろしくお願いします');
  expect(controller.saveProfile(), isNull);
  controller.startEvent();
  addTearDown(controller.dispose);
  return controller;
}

void enterGame(DemoController controller, String peerId) {
  controller.openPairing();
  expect(controller.selectPeer(peerId), isTrue);
  expect(controller.confirmPeer(), isTrue);
}

void returnToCan(DemoController controller) {
  controller.returnHome();
  expect(controller.phase, AppPhase.returning);
  controller.finishReturn();
  expect(controller.phase, AppPhase.home);
}

void main() {
  test('プロフィール入力を即時共有し、入力失敗でも本人の値を保つ', () {
    final controller = DemoController(autoTick: false);
    addTearDown(controller.dispose);
    controller.createRoom(const Duration(minutes: 3));
    expect(controller.profileDraft.nickname, isEmpty);
    controller.setProfile(nickname: ' 新しい名前 ', comment: '自分のひとこと');
    expect(controller.profileDraft.nickname, ' 新しい名前 ');
    expect(controller.saveProfile(), isNotNull);
    expect(controller.phase, AppPhase.profile);
    expect(controller.profileDraft.comment, '自分のひとこと');
    controller.setProfile(hobby: '写真');
    expect(controller.saveProfile(), isNull);
    expect(controller.phase, AppPhase.lobby);
    expect(controller.self.profile.nickname, '新しい名前');
    expect(controller.self.profile.comment, '自分のひとこと');
    controller.setProfile(nickname: '開始後の変更');
    expect(controller.self.profile.nickname, '新しい名前');
  });

  test('プロフィールは結合絵文字を一文字として上限を検証する', () {
    final controller = DemoController(autoTick: false);
    addTearDown(controller.dispose);
    controller.createRoom(const Duration(minutes: 3));
    controller.setProfile(nickname: '👩‍👩‍👧‍👦' * 21, hobby: '絵');
    expect(controller.saveProfile(), contains('20文字'));
    controller.setProfile(nickname: '👩‍👩‍👧‍👦' * 20, hobby: '絵' * 61);
    expect(controller.saveProfile(), contains('60文字'));
    controller.setProfile(hobby: '絵', comment: 'a' * 81);
    expect(controller.saveProfile(), contains('80文字'));
    controller.setProfile(comment: '');
    expect(controller.saveProfile(), isNull);
    expect(controller.self.profile.comment, isEmpty);
  });

  test('参加コードの失敗で遷移せず、仮想主催者の開始まで時間は減らない', () {
    final controller = DemoController(autoTick: false);
    addTearDown(controller.dispose);
    expect(controller.joinRoom('OTHER'), isNotNull);
    expect(controller.phase, AppPhase.entry);
    expect(controller.joinRoom(' tsuna '), isNull);
    expect(controller.isHost, isFalse);
    controller.setProfile(nickname: '参加者', hobby: '散歩');
    expect(controller.saveProfile(), isNull);
    controller.advance(const Duration(days: 1));
    expect(controller.phase, AppPhase.lobby);
    expect(controller.remaining, DemoController.defaultDuration);
    controller.startEvent();
    final members = [controller.self, ...controller.peers];
    expect(members.where((member) => member.team == Team.red).length, 3);
    expect(members.where((member) => member.team == Team.blue).length, 3);
  });

  test('対戦結果は双方へ一度だけ反映し、再戦と誤った種類の結果を拒否する', () {
    final controller = started();
    final peer = controller.peers.firstWhere(
      (p) => p.team != controller.self.team,
    );
    enterGame(controller, peer.id);
    expect(controller.injectOutcome(Outcome.coopSuccess), isFalse);
    expect(controller.phase, AppPhase.game);
    expect(controller.injectOutcome(Outcome.loss), isTrue);
    expect(controller.injectOutcome(Outcome.loss), isFalse);
    expect(controller.followers.single.kind, FollowerKind.bone);
    expect(controller.followers.single.profile, same(peer.profile));
    returnToCan(controller);
    controller.openPairing();
    expect(controller.selectPeer(peer.id), isFalse);
    expect(controller.selectPeer(controller.self.id), isFalse);
    controller.advance(controller.remaining);
    final snapshot = controller.finalSnapshot!;
    expect(snapshot.redPower, 1);
    expect(snapshot.bluePower, 3);
    expect(
      snapshot.rankings.fold(
        0,
        (n, row) => n + row.normalCount + row.boneCount,
      ),
      2,
    );
    final counterpart = snapshot.rankings.singleWhere(
      (r) => r.participant.id == peer.id,
    );
    expect(counterpart.normalCount, 1);
  });

  test('協力で古い骨だけを復活し、元の相手と協力相手を同じ子分に残す', () {
    final controller = started();
    final opponent = controller.peers.firstWhere(
      (p) => p.team != controller.self.team,
    );
    final partner = controller.peers.firstWhere(
      (p) => p.team == controller.self.team,
    );
    enterGame(controller, opponent.id);
    controller.injectOutcome(Outcome.loss);
    final bone = controller.followers.single;
    returnToCan(controller);
    enterGame(controller, partner.id);
    expect(controller.injectOutcome(Outcome.coopSuccess), isTrue);
    expect(controller.followers.length, 1);
    final promoted = controller.followers.singleWhere((f) => f.id == bone.id);
    expect(promoted.kind, FollowerKind.normal);
    expect(promoted.ordinal, bone.ordinal);
    expect(promoted.profile, same(opponent.profile));
    expect(promoted.peerId, opponent.id);
    expect(promoted.revivedWith, same(partner));
    expect(controller.lastResult!.newFollower, isNull);
    expect(controller.lastResult!.promoted!.id, bone.id);
    expect(controller.lastResult!.delta, 2);
    expect(controller.lastResult!.rewardFollower, same(promoted));
    expect(controller.power, 3);
    expect(controller.injectOutcome(Outcome.coopSuccess), isFalse);
    returnToCan(controller);
    controller.openPairing();
    expect(controller.selectPeer(partner.id), isFalse);
    controller.advance(controller.remaining);
    expect(controller.finalSnapshot!.redPower, 6);
    expect(controller.finalSnapshot!.bluePower, 3);
  });

  test('骨なしの協力成功は相手の普通子分を迎え、協力失敗は骨を迎える', () {
    final controller = started();
    final partners = controller.peers
        .where((p) => p.team == controller.self.team)
        .toList();
    enterGame(controller, partners.first.id);
    controller.injectOutcome(Outcome.coopSuccess);
    expect(controller.followers.single.kind, FollowerKind.normal);
    expect(
      controller.lastResult!.newFollower,
      same(controller.followers.single),
    );
    expect(controller.lastResult!.promoted, isNull);
    expect(controller.lastResult!.delta, 3);
    expect(controller.followers.single.peerId, partners.first.id);
    expect(controller.followers.single.revivedWith, isNull);
    returnToCan(controller);
    enterGame(controller, partners.last.id);
    controller.injectOutcome(Outcome.coopFailure);
    expect(controller.lastResult!.promoted, isNull);
    expect(controller.normalCount, 1);
    expect(controller.boneCount, 1);
    controller.advance(controller.remaining);
    expect(controller.finalSnapshot!.redPower, 8);
    expect(controller.finalSnapshot!.bluePower, 0);
  });

  test('開始前の連打や再開始で残り時間を延長しない', () {
    final controller = started(duration: const Duration(seconds: 10));
    controller.advance(const Duration(seconds: 3));
    controller.startEvent();
    controller.createRoom(const Duration(days: 1));
    expect(controller.remaining, const Duration(seconds: 7));
  });

  test('相手確認中の期限切れは即終了し、全員0点ならMVPなし', () {
    final controller = started(duration: const Duration(seconds: 1));
    controller.openPairing();
    controller.selectPeer(controller.peers.first.id);
    controller.advance(const Duration(seconds: 1));
    expect(controller.phase, AppPhase.finale);
    expect(controller.confirmPeer(), isFalse);
    expect(controller.finalSnapshot!.isDraw, isTrue);
    expect(controller.finalSnapshot!.mvpIds, isEmpty);
    expect(
      controller.finalSnapshot!.rankings.every((r) => r.rank == 1),
      isTrue,
    );
    controller.openPairing();
    expect(controller.phase, AppPhase.finale);
  });

  test('ゲーム中だけ30秒猶予を与え、猶予内の結果を双方の集計へ含める', () {
    final controller = started(duration: const Duration(seconds: 1));
    final peer = controller.peers.firstWhere(
      (p) => p.team != controller.self.team,
    );
    enterGame(controller, peer.id);
    controller.advance(const Duration(seconds: 1));
    expect(controller.phase, AppPhase.game);
    expect(controller.isClosing, isTrue);
    controller.advance(const Duration(seconds: 29));
    expect(controller.injectOutcome(Outcome.win), isTrue);
    expect(controller.phase, AppPhase.finale);
    expect(controller.finalSnapshot!.redPower, 3);
    expect(controller.finalSnapshot!.bluePower, 1);
  });

  test('猶予を超える大きな時間進行でも未完了結果を採用せず固定する', () {
    final controller = started(duration: const Duration(seconds: 1));
    enterGame(controller, controller.peers.first.id);
    controller.advance(const Duration(minutes: 2));
    expect(controller.phase, AppPhase.finale);
    expect(controller.injectOutcome(Outcome.coopSuccess), isFalse);
    expect(controller.followers, isEmpty);
    final snapshot = controller.finalSnapshot;
    controller.advance(const Duration(minutes: 2));
    controller.finishReturn();
    expect(controller.finalSnapshot, same(snapshot));
  });

  for (final returning in [false, true]) {
    test('結果${returning ? "帰還" : "表示"}中の期限切れでも報酬は残り、ホームへ再開しない', () {
      final controller = started(duration: const Duration(seconds: 1));
      enterGame(controller, controller.peers.first.id);
      controller.injectOutcome(Outcome.coopFailure);
      if (returning) controller.returnHome();
      controller.advance(const Duration(seconds: 1));
      expect(controller.phase, AppPhase.finale);
      expect(controller.finalSnapshot!.redPower, 2);
      controller.returnHome();
      controller.finishReturn();
      expect(controller.phase, AppPhase.finale);
      controller.showResults();
      expect(controller.phase, AppPhase.results);
      expect(controller.injectOutcome(Outcome.coopFailure), isFalse);
    });
  }

  test('リセットで本人情報・子分・相手・期限・集計を消し再現を開始できる', () {
    final controller = started();
    enterGame(controller, controller.peers.first.id);
    controller.injectOutcome(Outcome.coopFailure);
    controller.advance(controller.remaining);
    controller.reset();
    expect(controller.phase, AppPhase.entry);
    expect(controller.profileDraft.nickname, isEmpty);
    expect(controller.followers, isEmpty);
    expect(controller.completedPeerIds, isEmpty);
    expect(controller.activePeer, isNull);
    expect(controller.lastResult, isNull);
    expect(controller.finalSnapshot, isNull);
    expect(controller.remaining, DemoController.defaultDuration);
    expect(controller.joinRoom('TSUNA'), isNull);
  });

  testWidgets('稼働中のタイマーをreset/disposeで停止し、廃棄後に通知しない', (tester) async {
    final controller = DemoController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    void start() {
      controller.createRoom(const Duration(minutes: 1));
      controller.setProfile(nickname: 'テスト', hobby: 'テスト');
      controller.saveProfile();
      controller.startEvent();
    }

    start();
    controller.reset();
    final afterReset = notifications;
    await tester.pump(const Duration(seconds: 2));
    expect(notifications, afterReset);
    start();
    controller.dispose();
    final afterDispose = notifications;
    await tester.pump(const Duration(seconds: 2));
    controller.advance(const Duration(minutes: 1));
    controller.reset();
    expect(notifications, afterDispose);
  });
}
