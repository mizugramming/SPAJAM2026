import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/tug_of_war_finale.dart';

FinalSnapshot snapshot(int red, int blue) => FinalSnapshot(
  redPower: red,
  bluePower: blue,
  rankings: [
    for (final team in Team.values)
      RankEntry(
        participant: Participant(
          id: team.name,
          profile: const Profile.empty(),
          team: team,
        ),
        normalCount: (team == Team.red ? red : blue) ~/ 3,
        boneCount: (team == Team.red ? red : blue) % 3,
        power: team == Team.red ? red : blue,
        rank: 1,
      ),
  ],
  mvpIds: const [],
);

Widget scene(
  FinalSnapshot result, {
  bool reduceMotion = false,
  double scale = 1,
  VoidCallback? onShowResults,
}) => MaterialApp(
  theme: tsunagunTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: TextScaler.linear(scale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: TugOfWarFinale(
          snapshot: result,
          onShowResults: onShowResults ?? () {},
        ),
      ),
    ),
  ),
);

void narrowScreen(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('準備から決着まで自動進行し、再描画で再開始せず、最後に順位へ進める', (tester) async {
    narrowScreen(tester);
    final result = snapshot(7, 3);
    var resultsOpened = 0;
    Widget currentScene() =>
        scene(result, onShowResults: () => resultsOpened++);
    await tester.pumpWidget(currentScene());
    expect(find.text('よーい…'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('赤チームの勝利！'), findsNothing);
    expect(find.byKey(const Key('show-results')), findsNothing);
    expect(find.byKey(const Key('tug-red-power')), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('オーエス！ オーエス！'), findsOneWidget);
    await tester.pumpWidget(currentScene());
    expect(find.text('よーい…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2800));
    expect(find.text('あと、ひと引き！'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('tug-red-power'))).data,
      '7',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('tug-blue-power'))).data,
      '3',
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(currentScene());
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(resultsOpened, 0);
    await tester.ensureVisible(find.byKey(const Key('show-results')));
    await tester.tap(find.byKey(const Key('show-results')));
    expect(resultsOpened, 1);
    expect(result.redPower, 7);
    expect(result.bluePower, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('スキップは確定済みの青勝利を表示し、新しい集計でだけ演出をやり直す', (tester) async {
    narrowScreen(tester);
    final blueWins = snapshot(1, 3);
    await tester.pumpWidget(scene(blueWins));
    await tester.tap(find.byKey(const Key('skip-tug-animation')));
    await tester.pumpAndSettle();
    expect(find.text('青チームの勝利！'), findsOneWidget);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(scene(snapshot(4, 4)));
    expect(find.text('よーい…'), findsOneWidget);
    expect(find.text('青チームの勝利！'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('引き分け！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通常演出・文字2倍でもカウントと掛け声がキャラクターに重ならない', (tester) async {
    narrowScreen(tester);
    await tester.pumpWidget(scene(snapshot(7, 3), scale: 2));

    void expectClearStage(Finder caption) {
      final captionRect = tester.getRect(caption);
      for (final actor in find.byType(Image).evaluate()) {
        final actorRect = tester.getRect(find.byWidget(actor.widget));
        expect(captionRect.bottom + 8, lessThan(actorRect.top));
        expect(actorRect.left, greaterThanOrEqualTo(0));
        expect(actorRect.right, lessThanOrEqualTo(360));
      }
      expect(tester.takeException(), isNull);
    }

    final countdown = find.byKey(const Key('tug-countdown'));
    expect(tester.widget<Text>(countdown).style!.fontSize, 56);
    expectClearStage(countdown);
    await tester.pump(const Duration(milliseconds: 600));
    expectClearStage(countdown);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expectClearStage(find.text('ぐぐぐ…！'));
    await tester.pumpAndSettle();
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('動作軽減・360幅・文字2倍では即決着し、0対0も引き分けとして操作できる', (tester) async {
    narrowScreen(tester);
    var opened = false;
    await tester.pumpWidget(
      scene(
        snapshot(0, 0),
        reduceMotion: true,
        scale: 2,
        onShowResults: () => opened = true,
      ),
    );
    expect(find.text('引き分け！'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    await tester.pumpAndSettle();
    final button = find.byKey(const Key('show-results'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('接戦は中央で競り、大差は実際の優勢チーム側へ寄ってから勝利ラインを越える', (tester) async {
    narrowScreen(tester);
    double flagX() =>
        tester.getCenter(find.byKey(const Key('tug-rope-flag'))).dx;
    double centreX() => tester.getCenter(find.byKey(const Key('tug-arena'))).dx;
    double goalX(Team team) =>
        tester.getCenter(find.byKey(Key('tug-${team.name}-goal'))).dx;

    await tester.pumpWidget(scene(snapshot(11, 10)));
    await tester.pump(const Duration(milliseconds: 2800));
    final closeDisplacement = (flagX() - centreX()).abs();
    expect(flagX(), greaterThan(goalX(Team.red)));
    expect(flagX(), lessThan(goalX(Team.blue)));

    await tester.pumpWidget(scene(snapshot(18, 2)));
    await tester.pump(const Duration(milliseconds: 2800));
    expect(flagX(), lessThan(centreX()));
    expect((flagX() - centreX()).abs(), greaterThan(closeDisplacement * 2));
    expect(flagX(), greaterThan(goalX(Team.red)));
    await tester.pumpAndSettle();
    expect(flagX(), lessThan(goalX(Team.red)));
    expect(find.text('赤チームの勝利！'), findsOneWidget);

    await tester.pumpWidget(scene(snapshot(2, 18)));
    await tester.pump(const Duration(milliseconds: 2800));
    expect(flagX(), greaterThan(centreX()));
    expect((flagX() - centreX()).abs(), greaterThan(closeDisplacement * 2));
    expect(flagX(), lessThan(goalX(Team.blue)));
    await tester.pumpAndSettle();
    expect(flagX(), greaterThan(goalX(Team.blue)));
    expect(find.text('青チームの勝利！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同点の旗は中央で決着し、0対0は通常設定でも演出を待たせない', (tester) async {
    narrowScreen(tester);
    void expectCentredFlag() {
      expect(
        tester.getCenter(find.byKey(const Key('tug-rope-flag'))).dx,
        closeTo(tester.getCenter(find.byKey(const Key('tug-arena'))).dx, .01),
      );
    }

    await tester.pumpWidget(scene(snapshot(4, 4)));
    await tester.pump(const Duration(milliseconds: 4800));
    expect(find.text('どちらも、ゆずらない！'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('引き分け！'), findsOneWidget);
    expectCentredFlag();

    await tester.pumpWidget(scene(snapshot(0, 0)));
    expect(find.text('引き分け！'), findsOneWidget);
    expect(find.text('次は仲間をつなげて、いざ勝負！'), findsOneWidget);
    expect(find.byKey(const Key('show-results')), findsOneWidget);
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    expectCentredFlag();
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('進行中に動作軽減へ切替・画面破棄してもタイマーや演出を残さない', (tester) async {
    narrowScreen(tester);
    final result = snapshot(3, 1);
    await tester.pumpWidget(scene(result));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(scene(result, reduceMotion: true));
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(snapshot(1, 3)));
    expect(find.text('よーい…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
