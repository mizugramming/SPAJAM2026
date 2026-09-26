import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/cooperative/cooperative_game.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/duel/duel_game.dart';

Future<DemoController> launch(
  WidgetTester tester, {
  Size size = const Size(360, 740),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final demo = DemoController(autoTick: false);
  addTearDown(demo.dispose);
  await tester.pumpWidget(TsunagunApp(controller: demo));
  await tester.pumpAndSettle();
  return demo;
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> key(WidgetTester tester, String id) =>
    tap(tester, find.byKey(Key(id)));
Future<void> type(WidgetTester tester, String id, String value) async {
  final field = find.byKey(Key(id));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> fillProfile(WidgetTester tester) async {
  await type(tester, 'nickname', 'わたし');
  await type(tester, 'hobby', '写真');
  await type(tester, 'comment', '一緒に遊びましょう');
}

Future<void> start(WidgetTester tester) async {
  await key(tester, 'create-room');
  await fillProfile(tester);
  await key(tester, 'save-profile');
  await key(tester, 'start-event');
}

Future<void> meet(WidgetTester tester, Participant peer) async {
  await key(tester, 'meet-peer');
  await key(tester, 'peer-${peer.id}');
  await key(tester, 'confirm-peer');
}

Future<void> chooseOutcome(WidgetTester tester, String outcomeKey) async {
  await key(tester, 'game-demo-menu');
  await key(tester, outcomeKey);
}

Future<void> returnHome(WidgetTester tester) async {
  final button = find.byKey(const Key('return-home'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
  expect(
    find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '親分'),
    findsNothing,
  );
  await tester.pumpAndSettle();
  final parent = tester.widget<Image>(
    find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '親分'),
  );
  expect((parent.image as AssetImage).assetName, parentAsset);
}

Future<void> checkProfile(
  WidgetTester tester,
  String countLabel,
  Profile profile,
) async {
  await tap(tester, find.text(countLabel));
  await tap(tester, find.text(profile.nickname));
  final detailSheet = find.byType(BottomSheet).last;
  expect(
    find.descendant(of: detailSheet, matching: find.text(profile.hobby)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: detailSheet, matching: find.text(profile.comment)),
    findsOneWidget,
  );
  await tap(tester, find.text('閉じる').last);
  await tap(tester, find.text('閉じる'));
}

void expectFollowerResult(
  WidgetTester tester, {
  required String asset,
  required String title,
}) {
  expect(
    find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '親分'),
    findsNothing,
  );
  final child = find.descendant(
    of: find.byType(CanStage),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == asset,
    ),
  );
  expect(child, findsOneWidget);
  final canRect = tester.getRect(find.byType(TunaCan));
  final childRect = tester.getRect(child);
  expect(childRect.center.dx, closeTo(canRect.center.dx, 1));
  expect(childRect.width, greaterThanOrEqualTo(canRect.width * .5));
  final label = find.text(title);
  expect(label, findsOneWidget);
  expect(tester.getSize(label).height, greaterThanOrEqualTo(32));
}

void expectBoneResult(WidgetTester tester) {
  expectFollowerResult(tester, asset: boneFollowerAsset, title: 'ショBONE');
  expect(find.text('骨の子分も、大切な仲間。'), findsOneWidget);
  expect(find.text('同じチームと協力ゲーム！\n力を合わせて、元気にしよう。'), findsOneWidget);
}

void main() {
  testWidgets('入口は縦中央に置き、小画面・文字2倍・キーボード表示でも参加できる', (tester) async {
    final demo = await launch(tester, size: const Size(412, 900));
    final top = tester.getRect(find.byKey(const Key('demo-info'))).top;
    final bottom = tester.getRect(find.byKey(const Key('join-room'))).bottom;
    expect((top + bottom) / 2, closeTo(450, 20));

    tester.view.physicalSize = const Size(360, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await type(tester, 'room-code', 'NG');
    await key(tester, 'join-room');
    expect(demo.phase, AppPhase.entry);
    expect(find.text('デモの参加コードは TSUNA です。'), findsOneWidget);
    await type(tester, 'room-code', 'TSUNA');
    await key(tester, 'join-room');
    expect(demo.phase, AppPhase.profile);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空の缶へ入力を即時反映し、必須項目のエラーでも入力を保つ', (tester) async {
    final demo = await launch(tester);
    expect(find.text('はだ缶'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    await key(tester, 'create-room');
    await key(tester, 'save-profile');
    expect(find.text('ニックネームを入力してください。'), findsOneWidget);
    await type(tester, 'nickname', '入力中の名前');
    expect(
      tester.widget<Text>(find.byKey(const Key('can-nickname'))).data,
      '入力中の名前',
    );
    await type(tester, 'comment', '消さないひとこと');
    expect(
      find.descendant(
        of: find.byType(TunaCan),
        matching: find.text('消さないひとこと'),
      ),
      findsOneWidget,
    );
    await key(tester, 'save-profile');
    expect(find.text('趣味を入力してください。'), findsOneWidget);
    expect(demo.profileDraft.comment, '消さないひとこと');
    await type(tester, 'hobby', '散歩');
    await key(tester, 'save-profile');
    expect(demo.phase, AppPhase.lobby);
    expect(find.text('チームは開始時に決まります。'), findsOneWidget);
    expect(demo.self.profile.nickname, '入力中の名前');
    expect(tester.takeException(), isNull);
  });

  testWidgets('開いた缶への帰還完了を待ち、時計更新でも演出や報酬を繰り返さない', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await chooseOutcome(tester, 'negative-outcome');
    final followerIds = demo.followers.map((f) => f.id).toList();
    final returnButton = find.byKey(const Key('return-home'));
    await tester.ensureVisible(returnButton);
    await tester.pumpAndSettle();
    await tester.tap(returnButton);
    await tester.pump();
    expect(demo.phase, AppPhase.returning);
    expect(
      find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '親分'),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<TunaCan>(find.byType(TunaCan)).opening,
      greaterThan(0),
    );
    // The normal event-clock rebuild must not restart the dive.
    demo.advance(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(demo.phase, AppPhase.returning);
    expect(demo.followers.map((f) => f.id), followerIds);

    await tester.pump(const Duration(milliseconds: 600));
    expect(demo.phase, AppPhase.home);
    await tester.pumpAndSettle();
    expect(tester.widget<TunaCan>(find.byType(TunaCan)).opening, 0);
    expect(demo.followers.map((f) => f.id), followerIds);
    expect(demo.boneCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帰還演出中の期限で最終戦へ進み、遅れた完了でホームへ戻らない', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await chooseOutcome(tester, 'negative-outcome');
    final returnButton = find.byKey(const Key('return-home'));
    await tester.ensureVisible(returnButton);
    await tester.pumpAndSettle();
    await tester.tap(returnButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(demo.phase, AppPhase.returning);

    demo.advance(demo.remaining);
    final snapshot = demo.finalSnapshot;
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(demo.phase, AppPhase.finale);
    expect(demo.finalSnapshot, same(snapshot));
    expect(snapshot!.redPower, 1);
    expect(snapshot.bluePower, 3);
    expect(demo.boneCount, 1);
    expect(find.byKey(const Key('meet-peer')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('敗北で骨の子分を獲得し、元の相手を保って成長した後に最終順位へ進む', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final opponent = demo.peers.firstWhere((p) => p.team != demo.self.team);
    final partner = demo.peers.firstWhere((p) => p.team == demo.self.team);
    await meet(tester, opponent);
    await chooseOutcome(tester, 'negative-outcome');
    expect(demo.phase, AppPhase.result);
    expectBoneResult(tester);
    await returnHome(tester);
    await checkProfile(tester, '骨 1 匹', opponent.profile);
    await meet(tester, partner);
    await chooseOutcome(tester, 'positive-outcome');
    expectFollowerResult(tester, asset: normalFollowerAsset, title: 'REBORN');
    expect(find.text('${opponent.profile.nickname}の子分が、元気に！'), findsOneWidget);
    final newBone = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == boneFollowerAsset,
    );
    expect(newBone, findsOneWidget);
    expect(tester.getSize(newBone).width, lessThanOrEqualTo(80));
    expect(
      tester.getCenter(newBone).dx,
      greaterThan(tester.getCenter(find.byType(TunaCan)).dx),
    );
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 1);
    await returnHome(tester);
    await checkProfile(tester, '子分 1 匹', opponent.profile);
    await key(tester, 'expire-event');
    expect(demo.phase, AppPhase.finale);
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(demo.finalSnapshot!.redPower, 7);
    expect(demo.finalSnapshot!.bluePower, 3);
    await key(tester, 'show-results');
    expect(find.text('このルームのランキング'), findsOneWidget);
    expect(find.text('わたし（あなた）'), findsOneWidget);
    expect(find.text('今日のMVP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('参加コードの失敗後に参加し、仮想主催者の開始を待つ', (tester) async {
    final demo = await launch(tester);
    await type(tester, 'room-code', 'NG');
    await key(tester, 'join-room');
    expect(find.text('デモの参加コードは TSUNA です。'), findsOneWidget);
    expect(demo.phase, AppPhase.entry);
    await type(tester, 'room-code', 'TSUNA');
    await key(tester, 'join-room');
    await fillProfile(tester);
    await key(tester, 'save-profile');
    expect(demo.isHost, isFalse);
    expect(find.text('仮想主催者が開始（デモ）'), findsOneWidget);
    await key(tester, 'start-event');
    expect(demo.phase, AppPhase.home);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360幅・文字2倍で上限まで入力しても缶の中に全文を保ち、ゲームと結果へ進める', (tester) async {
    final demo = await launch(tester, textScale: 2);
    final profile = Profile(
      nickname: List.filled(10, 'ツナ').join(),
      hobby: List.filled(6, 'CAMERA2026').join(),
      comment: List.filled(10, '一緒に遊ぼうね！').join(),
    );
    // Japanese and an unbroken ASCII word exercise different line wrapping.
    expect(profile.nickname.length, 20);
    expect(profile.hobby.length, 60);
    expect(profile.comment.length, 80);

    void expectFullLabel() {
      final can = find.byType(TunaCan);
      final canRect = tester.getRect(can).inflate(.1);
      for (final value in [profile.nickname, profile.hobby, profile.comment]) {
        final text = find.descendant(of: can, matching: find.text(value));
        expect(text, findsOneWidget);
        final textRect = tester.getRect(text);
        expect(canRect.contains(textRect.topLeft), isTrue);
        expect(canRect.contains(textRect.bottomRight), isTrue);
      }
      expect(tester.takeException(), isNull);
    }

    await key(tester, 'create-room');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await type(tester, 'nickname', profile.nickname);
    await type(tester, 'hobby', profile.hobby);
    await type(tester, 'comment', profile.comment);
    expectFullLabel();
    await key(tester, 'save-profile');
    expect(demo.phase, AppPhase.lobby);
    expect(demo.self.profile.nickname, profile.nickname);
    expect(demo.self.profile.hobby, profile.hobby);
    expect(demo.self.profile.comment, profile.comment);
    expectFullLabel();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await key(tester, 'start-event');
    expectFullLabel();
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    expect(find.byType(TunaCan), findsNothing);
    expect(find.byType(DuelGame), findsOneWidget);
    expect(demo.self.profile.nickname, profile.nickname);
    expect(demo.self.profile.hobby, profile.hobby);
    expect(demo.self.profile.comment, profile.comment);
    await chooseOutcome(tester, 'negative-outcome');
    expectFullLabel();
    await returnHome(tester);
    await checkProfile(tester, '骨 1 匹', peer.profile);
    await key(tester, 'expire-event');
    await key(tester, 'show-results');
    expect(tester.takeException(), isNull);
  });

  testWidgets('実ゲームのタップ操作から結果・帰還・最終発表まで接続する', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final opponent = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, opponent);
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(DuelGame));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.result);
    expect(demo.lastResult!.outcome, anyOf(Outcome.win, Outcome.loss));
    expect(demo.followers, hasLength(1));
    await returnHome(tester);

    final partner = demo.peers.firstWhere((p) => p.team == demo.self.team);
    await meet(tester, partner);
    await tester.tap(find.byType(CooperativeGame));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Tap before the first arrival to exercise the game's own failure callback.
    await tester.tap(find.byType(CooperativeGame));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.result);
    expect(demo.lastResult!.outcome, Outcome.coopFailure);
    expect(demo.followers, hasLength(2));
    expect(demo.lastResult!.newFollower.kind, FollowerKind.bone);
    await returnHome(tester);
    await key(tester, 'expire-event');
    expect(demo.phase, AppPhase.finale);
    await key(tester, 'show-results');
    expect(demo.phase, AppPhase.results);
    expect(demo.followers, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('詳細シート中でも期限で終了し、全員0点ならMVPを作らない', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    await tap(tester, find.text('子分 0 匹'));
    expect(find.byType(BottomSheet), findsOneWidget);
    demo.advance(demo.remaining);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(demo.phase, AppPhase.finale);
    expect(find.text('引き分け！'), findsOneWidget);
    await key(tester, 'show-results');
    expect(find.text('今回は該当者なし'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ゲームは安全領域全体を使い、DEMOを開いたときだけ結果を選べる', (tester) async {
    final demo = await launch(tester);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpAndSettle();
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    expect(
      tester.getRect(find.byKey(const Key('game-surface'))),
      const Rect.fromLTWH(0, 24, 360, 700),
    );
    expect(find.byKey(const Key('positive-outcome')), findsNothing);
    expect(find.byKey(const Key('negative-outcome')), findsNothing);
    expect(find.byKey(const Key('expire-event')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    await key(tester, 'game-demo-menu');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('positive-outcome')), findsOneWidget);
    expect(find.byKey(const Key('negative-outcome')), findsOneWidget);
    await key(tester, 'positive-outcome');
    expect(find.byType(BottomSheet), findsNothing);
    expect(demo.phase, AppPhase.result);
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ゲームのDEMOメニュー中も終了猶予が尽きれば閉じ、未確定の報酬を付けない', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await key(tester, 'game-demo-menu');
    demo.advance(demo.remaining);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.game);
    expect(demo.isClosing, isTrue);
    expect(find.byType(BottomSheet), findsOneWidget);
    demo.advance(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('positive-outcome')), findsNothing);
    expect(demo.phase, AppPhase.finale);
    expect(demo.finalSnapshot!.redPower, 0);
    expect(demo.finalSnapshot!.bluePower, 0);
    expect(demo.followers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ゲーム差込口の完了でメニューを閉じ、重複と別相手への遅延通知を拒否する', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final opponent = demo.peers.firstWhere((p) => p.team != demo.self.team);
    final partner = demo.peers.firstWhere((p) => p.team == demo.self.team);
    await meet(tester, opponent);
    expect(find.byType(CooperativeGame), findsNothing);
    final duel = tester.widget<DuelGame>(find.byType(DuelGame));
    expect(duel.self.id, demo.self.id);
    expect(duel.peer.id, opponent.id);
    await key(tester, 'game-demo-menu');
    duel.onCompleted(DuelGameResult.loss);
    duel.onCompleted(DuelGameResult.win);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(demo.phase, AppPhase.result);
    expect(demo.normalCount, 0);
    expect(demo.boneCount, 1);
    await returnHome(tester);
    await meet(tester, partner);
    expect(find.byType(DuelGame), findsNothing);
    final cooperative = tester.widget<CooperativeGame>(
      find.byType(CooperativeGame),
    );
    expect(cooperative.self.id, demo.self.id);
    expect(cooperative.peer.id, partner.id);
    duel.onCompleted(DuelGameResult.win);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.game);
    expect(demo.followers, hasLength(1));
    cooperative.onCompleted(CooperativeGameResult.success);
    cooperative.onCompleted(CooperativeGameResult.failure);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.result);
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 1);
    expect(demo.completedPeerIds, {opponent.id, partner.id});
    expect(tester.takeException(), isNull);
  });

  testWidgets('ゲーム差込口の勝利・協力失敗を反映し、再開始後は同じ相手への旧通知を拒否する', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final opponent = demo.peers.firstWhere((p) => p.team != demo.self.team);
    final partner = demo.peers.firstWhere((p) => p.team == demo.self.team);
    await meet(tester, opponent);
    final previousDuel = tester.widget<DuelGame>(find.byType(DuelGame));
    previousDuel.onCompleted(DuelGameResult.win);
    await tester.pumpAndSettle();
    expectFollowerResult(tester, asset: normalFollowerAsset, title: 'やった！');
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 0);
    await returnHome(tester);
    await meet(tester, partner);
    tester
        .widget<CooperativeGame>(find.byType(CooperativeGame))
        .onCompleted(CooperativeGameResult.failure);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.result);
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 1);
    expectBoneResult(tester);
    await returnHome(tester);
    await key(tester, 'expire-event');
    await key(tester, 'show-results');
    await key(tester, 'reset-demo');
    await start(tester);
    await meet(tester, opponent);
    previousDuel.onCompleted(DuelGameResult.loss);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.game);
    expect(demo.followers, isEmpty);
    tester
        .widget<DuelGame>(find.byType(DuelGame))
        .onCompleted(DuelGameResult.win);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.result);
    expect(demo.normalCount, 1);
    expect(demo.boneCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('プロフィールを重ねて表示中も期限で両シートを閉じ、確定報酬を残す', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await chooseOutcome(tester, 'negative-outcome');
    await returnHome(tester);
    await tap(tester, find.text('骨 1 匹'));
    await tap(tester, find.text(peer.profile.nickname));
    expect(find.text(peer.profile.comment), findsOneWidget);
    demo.advance(demo.remaining);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(demo.phase, AppPhase.finale);
    expect(demo.finalSnapshot!.redPower, 1);
    expect(demo.finalSnapshot!.bluePower, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PCでは通常画面・ゲーム・シートを共通412幅に収める', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final demo = await launch(tester, size: const Size(1200, 1000));
      expect(tester.getSize(find.byType(Scaffold)), const Size(412, 900));
      expect(
        MediaQuery.of(tester.element(find.byType(CanStage))).size,
        const Size(412, 900),
      );
      await start(tester);
      await tap(tester, find.text('子分 0 匹'));
      expect(tester.getSize(find.byType(BottomSheet)).width, 412);
      await tap(tester, find.text('閉じる'));
      final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
      await meet(tester, peer);
      expect(
        tester.getRect(find.byKey(const Key('game-surface'))),
        tester.getRect(find.byType(Scaffold)),
      );
      await key(tester, 'game-demo-menu');
      expect(tester.getSize(find.byType(BottomSheet)).width, 412);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
