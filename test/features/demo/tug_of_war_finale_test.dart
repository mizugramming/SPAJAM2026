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
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> start(WidgetTester tester) async {
  final button = find.byKey(const Key('start-tug-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> skip(WidgetTester tester) async {
  final button = find.byKey(const Key('skip-tug-animation'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void expectHiddenScore() {
  expect(find.byKey(const Key('tug-red-power')), findsNothing);
  expect(find.byKey(const Key('tug-blue-power')), findsNothing);
  expect(find.byKey(const Key('tug-red-normal-breakdown')), findsNothing);
  expect(find.byKey(const Key('tug-blue-bone-breakdown')), findsNothing);
  expect(find.byKey(const Key('show-results')), findsNothing);
}

void main() {
  testWidgets('開始ボタンまでは静止し、カウント・途中の点数・勝敗を先に出さない', (tester) async {
    narrowScreen(tester);
    final result = snapshot(7, 3);
    await tester.pumpWidget(scene(result));
    await tester.pumpAndSettle();
    final flag = tester.getCenter(find.byKey(const Key('tug-rope-flag')));
    expect(find.text('最後の大綱引き'), findsOneWidget);
    expect(tester.widget<Text>(find.text('最後の大綱引き')).style!.fontSize, 30);
    expect(find.text('綱引きスタート！'), findsOneWidget);
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    expectHiddenScore();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpWidget(scene(result));
    expect(tester.getCenter(find.byKey(const Key('tug-rope-flag'))), flag);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expectHiddenScore();
    expect(tester.takeException(), isNull);
  });

  testWidgets('3秒カウント後に競り合い、11秒で確定得点を公開し、再描画でやり直さない', (tester) async {
    narrowScreen(tester);
    final result = snapshot(7, 3);
    var resultsOpened = 0;
    Widget currentScene() =>
        scene(result, onShowResults: () => resultsOpened++);
    await tester.pumpWidget(currentScene());
    await start(tester);
    expect(find.text('よーい…'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const Key('start-tug-button')), findsNothing);
    expectHiddenScore();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('オーエス！ オーエス！'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('オーエス！ オーエス！'), findsOneWidget);
    await tester.pumpWidget(currentScene());
    expect(find.text('よーい…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 6500));
    expect(find.text('あと、ひと引き！'), findsOneWidget);
    expectHiddenScore();
    await tester.pump(const Duration(milliseconds: 1300));
    expectHiddenScore();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(find.text('子分のエールがチームのちから！'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('tug-red-power'))).data,
      '7',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('tug-blue-power'))).data,
      '3',
    );
    expect(find.text('子分 2匹 × 3pt = 6pt'), findsOneWidget);
    expect(find.text('骨 1匹 × 1pt = 1pt'), findsOneWidget);
    expect(find.text('子分は 3、骨は 1 のちから'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(currentScene());
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(resultsOpened, 0);
    final button = find.byKey(const Key('show-results'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    expect(resultsOpened, 1);
    expect(result.redPower, 7);
    expect(result.bluePower, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('短冊紙吹雪は決着後だけ降り、2秒後に消えて演出も停止する', (tester) async {
    narrowScreen(tester);
    await tester.pumpWidget(scene(snapshot(3, 1)));
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    await start(tester);
    await tester.pump(const Duration(milliseconds: 11100));
    expect(find.byKey(const Key('tug-confetti')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const Key('tug-confetti')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('スキップは青の確定勝利を表示し、新しい集計はまた開始待ちになる', (tester) async {
    narrowScreen(tester);
    final blueWins = snapshot(1, 3);
    await tester.pumpWidget(scene(blueWins));
    await start(tester);
    await skip(tester);
    expect(find.text('青チームの勝利！'), findsOneWidget);
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(scene(blueWins));
    expect(find.text('青チームの勝利！'), findsOneWidget);
    await tester.pumpWidget(scene(snapshot(4, 4)));
    expect(find.text('綱引きスタート！'), findsOneWidget);
    expect(find.text('青チームの勝利！'), findsNothing);
    expectHiddenScore();
    await start(tester);
    await tester.pumpAndSettle();
    expect(find.text('引き分け！'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360幅・文字2倍でもカウントと観客・親分が重ならず、内訳とボタンへ到達できる', (tester) async {
    narrowScreen(tester);
    await tester.pumpWidget(scene(snapshot(7, 3), scale: 2));
    await start(tester);

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
    await tester.pump(const Duration(milliseconds: 1600));
    expectClearStage(countdown);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expectClearStage(find.text('ぐぐぐ…！'));
    await tester.pumpAndSettle();
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    for (final kind in ['normal', 'bone']) {
      for (final team in Team.values) {
        final detail = find.byKey(Key('tug-${team.name}-$kind-breakdown'));
        await tester.ensureVisible(detail);
        final rect = tester.getRect(detail);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        expect(rect.bottom, lessThanOrEqualTo(640));
      }
    }
    final button = find.byKey(const Key('show-results'));
    await tester.ensureVisible(button);
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('動作軽減でも開始待ちし、押すと即決着する。0対0も開始操作を待つ', (tester) async {
    narrowScreen(tester);
    var opened = false;
    await tester.pumpWidget(
      scene(snapshot(3, 1), reduceMotion: true, scale: 2),
    );
    expect(find.text('綱引きスタート！'), findsOneWidget);
    expectHiddenScore();
    await start(tester);
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    await tester.pumpWidget(
      scene(
        snapshot(0, 0),
        reduceMotion: true,
        scale: 2,
        onShowResults: () => opened = true,
      ),
    );
    expect(find.text('引き分け！'), findsNothing);
    expectHiddenScore();
    await start(tester);
    expect(find.text('引き分け！'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    final button = find.byKey(const Key('show-results'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('大差でも前半は中央付近に留まり、後半から優勢側へ動いて勝利ラインを越える', (tester) async {
    narrowScreen(tester);
    double flagX() =>
        tester.getCenter(find.byKey(const Key('tug-rope-flag'))).dx;
    double centreX() => tester.getCenter(find.byKey(const Key('tug-arena'))).dx;
    double goalX(Team team) =>
        tester.getCenter(find.byKey(Key('tug-${team.name}-goal'))).dx;

    for (final winner in Team.values) {
      await tester.pumpWidget(
        scene(winner == Team.red ? snapshot(18, 2) : snapshot(2, 18)),
      );
      await start(tester);
      await tester.pump(const Duration(milliseconds: 5500));
      expect((flagX() - centreX()).abs(), lessThan(15));
      expect(flagX(), greaterThan(goalX(Team.red)));
      expect(flagX(), lessThan(goalX(Team.blue)));
      expectHiddenScore();
      await tester.pump(const Duration(milliseconds: 4000));
      if (winner == Team.red) {
        expect(flagX(), lessThan(centreX() - 20));
        expect(flagX(), greaterThan(goalX(Team.red)));
      } else {
        expect(flagX(), greaterThan(centreX() + 20));
        expect(flagX(), lessThan(goalX(Team.blue)));
      }
      expectHiddenScore();
      await tester.pumpAndSettle();
      expect(
        flagX(),
        winner == Team.red
            ? lessThan(goalX(winner))
            : greaterThan(goalX(winner)),
      );
      expect(find.text('${winner.label}の勝利！'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('同点は中央で決着し、通常設定の0対0も開始後にだけ結果を出す', (tester) async {
    narrowScreen(tester);
    void expectCentredFlag() {
      expect(
        tester.getCenter(find.byKey(const Key('tug-rope-flag'))).dx,
        closeTo(tester.getCenter(find.byKey(const Key('tug-arena'))).dx, .01),
      );
    }

    await tester.pumpWidget(scene(snapshot(4, 4)));
    await start(tester);
    await tester.pump(const Duration(milliseconds: 9700));
    expect(find.text('どちらも、ゆずらない！'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('引き分け！'), findsOneWidget);
    expectCentredFlag();
    await tester.pumpWidget(scene(snapshot(0, 0)));
    expect(find.text('引き分け！'), findsNothing);
    expect(find.text('綱引きスタート！'), findsOneWidget);
    await start(tester);
    expect(find.text('引き分け！'), findsOneWidget);
    expect(find.text('次は仲間をつなげて、いざ勝負！'), findsOneWidget);
    expect(find.byKey(const Key('show-results')), findsOneWidget);
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    expectCentredFlag();
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('観客は所持数にかかわらず固定で、複数参加者の内訳は確定集計に一致する', (tester) async {
    narrowScreen(tester);
    final base = snapshot(7, 3);
    final result = FinalSnapshot(
      redPower: 11,
      bluePower: 3,
      rankings: [
        ...base.rankings,
        RankEntry(
          participant: const Participant(
            id: 'extra',
            profile: Profile(
              nickname: '長いニックネームの参加者さん',
              hobby: '',
              comment: '',
            ),
            team: Team.red,
          ),
          normalCount: 1,
          boneCount: 1,
          power: 4,
          rank: 2,
        ),
      ],
      mvpIds: const [],
    );
    final audience = find.descendant(
      of: find.byKey(const Key('tug-decorative-audience')),
      matching: find.byType(Image),
    );
    await tester.pumpWidget(scene(snapshot(0, 0)));
    expect(audience, findsNWidgets(12));
    await tester.pumpWidget(scene(result));
    expect(audience, findsNWidgets(12));
    await start(tester);
    await skip(tester);
    expect(audience, findsNWidgets(12));
    expect(find.text('子分 3匹 × 3pt = 9pt'), findsOneWidget);
    expect(find.text('骨 2匹 × 1pt = 2pt'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('tug-red-power'))).data,
      '11',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('進行中の動作軽減切替や画面破棄で演出を残さない', (tester) async {
    narrowScreen(tester);
    final result = snapshot(3, 1);
    await tester.pumpWidget(scene(result));
    await start(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(scene(result, reduceMotion: true));
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    await tester.pumpAndSettle();
    await tester.pumpWidget(scene(snapshot(1, 3)));
    expect(find.text('綱引きスタート！'), findsOneWidget);
    await start(tester);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 20));
    expect(tester.takeException(), isNull);
  });
}
