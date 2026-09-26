import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';

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

Future<void> returnHome(WidgetTester tester) async {
  final button = find.byKey(const Key('return-home'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
  // Finish the timed return before settling its indeterminate indicator.
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pumpAndSettle();
}

Future<void> checkProfile(
  WidgetTester tester,
  String countLabel,
  Profile profile,
) async {
  await tap(tester, find.text(countLabel));
  await tap(tester, find.text(profile.nickname));
  expect(find.text(profile.hobby), findsOneWidget);
  expect(find.text(profile.comment), findsOneWidget);
  await tap(tester, find.text('閉じる').last);
  await tap(tester, find.text('閉じる'));
}

void main() {
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

  testWidgets('敗北で骨の子分を獲得し、元の相手を保って成長した後に最終順位へ進む', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final opponent = demo.peers.firstWhere((p) => p.team != demo.self.team);
    final partner = demo.peers.firstWhere((p) => p.team == demo.self.team);
    await meet(tester, opponent);
    await key(tester, 'negative-outcome');
    expect(demo.phase, AppPhase.result);
    expect(find.text('ショBONE'), findsOneWidget);
    final parent = tester.widget<Image>(
      find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '親分'),
    );
    expect((parent.image as AssetImage).assetName, parentAsset);
    final child = tester.widget<Image>(
      find.byWidgetPredicate((w) => w is Image && w.semanticLabel == '骨の子分'),
    );
    expect((child.image as AssetImage).assetName, boneFollowerAsset);
    await returnHome(tester);
    await checkProfile(tester, '骨 1 匹', opponent.profile);
    await meet(tester, partner);
    await key(tester, 'positive-outcome');
    expect(
      find.text('${opponent.profile.nickname}さんの骨が、元気な子分に成長しました。'),
      findsOneWidget,
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

  testWidgets('360幅・文字2倍・キーボード表示中でも入力と決定へ到達できる', (tester) async {
    final demo = await launch(tester, textScale: 2);
    await key(tester, 'create-room');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await fillProfile(tester);
    await key(tester, 'save-profile');
    expect(demo.phase, AppPhase.lobby);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await key(tester, 'start-event');
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await key(tester, 'negative-outcome');
    await returnHome(tester);
    await checkProfile(tester, '骨 1 匹', peer.profile);
    await key(tester, 'expire-event');
    await key(tester, 'show-results');
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

  testWidgets('プロフィールを重ねて表示中も期限で両シートを閉じ、確定報酬を残す', (tester) async {
    final demo = await launch(tester);
    await start(tester);
    final peer = demo.peers.firstWhere((p) => p.team != demo.self.team);
    await meet(tester, peer);
    await key(tester, 'negative-outcome');
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

  testWidgets('PCでは全画面と子分シートを共通412幅に収める', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await launch(tester, size: const Size(1200, 1000));
      expect(tester.getSize(find.byType(Scaffold)), const Size(412, 900));
      expect(
        MediaQuery.of(tester.element(find.byType(CanStage))).size,
        const Size(412, 900),
      );
      await start(tester);
      await tap(tester, find.text('子分 0 匹'));
      expect(tester.getSize(find.byType(BottomSheet)).width, 412);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
