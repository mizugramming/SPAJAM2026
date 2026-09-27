import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

Map<String, Rect> spectatorRects(WidgetTester tester) {
  final origin = tester.getTopLeft(find.byKey(const Key('tug-arena')));
  return {
    for (final team in Team.values)
      for (var row = 0; row < 2; row++)
        for (var seat = 0; seat < 3; seat++)
          '${team.name}-$row-$seat': tester
              .getRect(find.byKey(Key('tug-spectator-${team.name}-$row-$seat')))
              .shift(-origin),
  };
}

void expectSpectatorsSeated(Map<String, Rect> actual, Map<String, Rect> seats) {
  for (final seat in seats.entries) {
    expect(actual[seat.key]!.left, closeTo(seat.value.left, .01));
    expect(actual[seat.key]!.top, closeTo(seat.value.top, .01));
    expect(actual[seat.key]!.size, seat.value.size);
  }
}

void main() {
  testWidgets('スマホの通常表示では綱引き開始から内訳と次の操作までスクロール不要', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tsunagunTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 90),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: TugOfWarFinale(
                    snapshot: snapshot(10, 7),
                    onShowResults: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(scroll.position.maxScrollExtent, 0);
    await tester.tap(find.byKey(const Key('start-tug-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(scroll.position.maxScrollExtent, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(scroll.position.maxScrollExtent, 0);
    await tester.pumpAndSettle();
    expect(scroll.position.maxScrollExtent, 0);
    expect(find.byKey(const Key('show-results')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('tug-red-normal-breakdown')), findsOneWidget);
    expect(find.byKey(const Key('tug-blue-bone-breakdown')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('表示中のWebだけ非選択でも綱引き時計を進め、背景の再buildでは再開しない', (tester) async {
    narrowScreen(tester);
    var now = 2000;
    var clockReads = 0;
    final result = snapshot(7, 3);
    Widget sharedScene() => MaterialApp(
      theme: tsunagunTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TugOfWarFinale(
            snapshot: result,
            serverStartAt: 1000,
            serverNow: () {
              clockReads++;
              return now;
            },
            onShowResults: () {},
          ),
        ),
      ),
    );
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(sharedScene());
    expect(find.byKey(const Key('tug-countdown')), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    now = 4500;
    // A parent clock may rebuild while the app is inactive.
    await tester.pumpWidget(sharedScene());
    final inactiveReads = clockReads;
    await tester.pump(const Duration(milliseconds: 100));
    expect(clockReads, kIsWeb ? greaterThan(inactiveReads) : inactiveReads);
    expect(find.text('ぐぐぐ…！'), kIsWeb ? findsOneWidget : findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    now = 15000;
    // Force one test frame to exercise didUpdateWidget even in the background.
    // A rebuild must not restart a cancelled shared timer or reveal results.
    tester.binding.scheduleForcedFrame();
    await tester.pumpWidget(sharedScene());
    final hiddenReads = clockReads;
    await tester.pump(const Duration(milliseconds: 100));
    expect(clockReads, hiddenReads);
    expect(find.byKey(const Key('show-results')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const Key('show-results')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('観客は開始とカウントを待ち、引き合い中に席ごとに跳ねて重ならず着地する', (tester) async {
    narrowScreen(tester);
    final result = snapshot(7, 3);
    await tester.pumpWidget(scene(result, scale: 2));
    await tester.pumpAndSettle();
    final seats = spectatorRects(tester);
    await tester.pump(const Duration(seconds: 5));
    expectSpectatorsSeated(spectatorRects(tester), seats);
    await start(tester);
    await tester.pump(const Duration(seconds: 2));
    expectSpectatorsSeated(spectatorRects(tester), seats);
    await tester.pump(const Duration(milliseconds: 1250));
    final firstHop = spectatorRects(tester);
    final firstLift = seats['red-0-0']!.top - firstHop['red-0-0']!.top;
    final nextLift = seats['blue-0-0']!.top - firstHop['blue-0-0']!.top;
    expect(firstLift, greaterThan(4));
    expect(nextLift, greaterThan(0));
    expect(firstLift, isNot(closeTo(nextLift, .1)));
    expect(firstHop['red-1-2']!.top, closeTo(seats['red-1-2']!.top, .01));

    final arenaSize = tester.getSize(find.byKey(const Key('tug-arena')));
    final jumped = <String>{};
    for (var elapsed = 3250; elapsed < 13000; elapsed += 150) {
      if (elapsed > 3250) await tester.pump(const Duration(milliseconds: 150));
      final positions = spectatorRects(tester);
      expect(positions, hasLength(12));
      for (final seat in positions.entries) {
        final lift = seats[seat.key]!.top - seat.value.top;
        if (lift > .5) jumped.add(seat.key);
        expect(lift, greaterThanOrEqualTo(-.01));
        expect(lift, lessThanOrEqualTo(arenaSize.width * .018 + .01));
        expect(seat.value.left, closeTo(seats[seat.key]!.left, .01));
        expect(seat.value.top, greaterThanOrEqualTo(0));
        expect(seat.value.right, lessThanOrEqualTo(arenaSize.width));
      }
      final rects = positions.values.toList();
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(
            rects[i].overlaps(rects[j]),
            isFalse,
            reason: '$elapsed ms: seats $i / $j',
          );
        }
      }
    }
    expect(jumped, seats.keys.toSet());
    await tester.pumpAndSettle();
    expectSpectatorsSeated(spectatorRects(tester), seats);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(scene(result, scale: 2));
    await tester.pump(const Duration(seconds: 2));
    expectSpectatorsSeated(spectatorRects(tester), seats);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('両チームの観客の応援は勝敗や所持数に依存せず、同点でも同じタイミングで動く', (tester) async {
    narrowScreen(tester);
    Map<String, Rect>? reference;
    for (final result in [snapshot(18, 1), snapshot(1, 18), snapshot(3, 3)]) {
      await tester.pumpWidget(scene(result));
      await start(tester);
      await tester.pump(const Duration(milliseconds: 6370));
      final positions = spectatorRects(tester);
      if (reference == null) {
        reference = positions;
      } else {
        expectSpectatorsSeated(positions, reference);
      }
      expectHiddenScore();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('スキップ・動作軽減・0対0では観客が席に戻り、追加のループを残さない', (tester) async {
    narrowScreen(tester);
    final result = snapshot(7, 3);
    await tester.pumpWidget(scene(result));
    final seats = spectatorRects(tester);
    await start(tester);
    await tester.pump(const Duration(milliseconds: 3250));
    expect(
      spectatorRects(tester)['red-0-0']!.top,
      lessThan(seats['red-0-0']!.top),
    );
    await skip(tester);
    expectSpectatorsSeated(spectatorRects(tester), seats);
    expect(tester.binding.hasScheduledFrame, isFalse);

    final next = snapshot(3, 7);
    await tester.pumpWidget(scene(next));
    await start(tester);
    await tester.pump(const Duration(milliseconds: 3250));
    await tester.pumpWidget(scene(next, reduceMotion: true));
    expectSpectatorsSeated(spectatorRects(tester), seats);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    for (final setting in [
      (reduce: true, result: snapshot(7, 3)),
      (reduce: false, result: snapshot(0, 0)),
    ]) {
      await tester.pumpWidget(
        scene(setting.result, reduceMotion: setting.reduce),
      );
      expectSpectatorsSeated(spectatorRects(tester), seats);
      await start(tester);
      await tester.pumpAndSettle();
      expectSpectatorsSeated(spectatorRects(tester), seats);
      await tester.pump(const Duration(seconds: 3));
      expectSpectatorsSeated(spectatorRects(tester), seats);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('共有開始は主催者の要求後もサーバー時刻を待ち、全員同じ位置から進む', (tester) async {
    narrowScreen(tester);
    var now = 1000;
    int? startAt;
    var requested = 0;
    Widget shared({bool host = true}) => MaterialApp(
      theme: tsunagunTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TugOfWarFinale(
            snapshot: snapshot(7, 3),
            onShowResults: () {},
            serverNow: () => now,
            serverStartAt: startAt,
            canStart: host,
            onStartRequested: () => requested++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(shared(host: false));
    expect(find.text('主催者のスタートを待っています'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('start-tug-button')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(shared());
    await start(tester);
    expect(requested, 1);
    expectHiddenScore();
    expect(find.byKey(const Key('tug-countdown')), findsNothing);
    startAt = 2000;
    await tester.pumpWidget(shared());
    expect(find.text('まもなくスタート！'), findsOneWidget);
    now = 2000;
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('3'), findsOneWidget);
    expect(find.byKey(const Key('skip-tug-animation')), findsNothing);
    now = 6500;
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('オーエス！ オーエス！'), findsOneWidget);
    // A refreshed immutable snapshot cannot restart the common countdown.
    await tester.pumpWidget(shared());
    expect(find.text('オーエス！ オーエス！'), findsOneWidget);
    expectHiddenScore();
    now = 13001;
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    now = 15000;
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('共有演出は途中参加と背景復帰で追いつき、動作軽減でも結果を先に公開しない', (tester) async {
    narrowScreen(tester);
    var now = 6500;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: SingleChildScrollView(
              child: TugOfWarFinale(
                snapshot: snapshot(3, 1),
                onShowResults: () {},
                serverNow: () => now,
                serverStartAt: 1000,
                canStart: false,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('オーエス！ オーエス！'), findsOneWidget);
    expectHiddenScore();
    final stillFlag = tester.getCenter(find.byKey(const Key('tug-rope-flag')));
    final stillAudience = spectatorRects(tester);
    now = 10500;
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getCenter(find.byKey(const Key('tug-rope-flag'))), stillFlag);
    expectSpectatorsSeated(spectatorRects(tester), stillAudience);
    expectHiddenScore();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = 15000;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('赤チームの勝利！'), findsOneWidget);
    expect(find.byKey(const Key('tug-confetti')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
