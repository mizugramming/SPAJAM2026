import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/cooperative/cooperative_game.dart';
import 'package:spajam2026/features/cooperative/soul_course.dart';
import 'package:spajam2026/features/cooperative/soul_stage.dart';
import 'package:spajam2026/features/demo/game_scene.dart';
import 'package:spajam2026/features/duel/duel_game.dart';
import 'package:spajam2026/features/duel/race_field.dart';

const _self = Participant(
  id: 'self',
  profile: Profile(nickname: 'わたし', hobby: '', comment: ''),
  team: Team.red,
);
const _ally = Participant(
  id: 'ally',
  profile: Profile(nickname: 'なぎ', hobby: '', comment: ''),
  team: Team.red,
);
const _rival = Participant(
  id: 'rival',
  profile: Profile(nickname: 'あお', hobby: '', comment: ''),
  team: Team.blue,
);

Widget _app({
  Participant peer = _ally,
  String remaining = '残り 3:00',
  ValueChanged<Outcome>? onCompleted,
}) => MaterialApp(
  theme: tsunagunTheme(),
  home: Scaffold(body: _scene(peer, remaining, onCompleted ?? (_) {})),
);

GameScene _scene(
  Participant peer,
  String remaining,
  ValueChanged<Outcome> onCompleted,
) => GameScene(
  self: _self,
  peer: peer,
  remainingLabel: remaining,
  onDemoMenu: () {},
  onCompleted: onCompleted,
);

void _expectInside(Rect outer, Rect inner) {
  expect(outer.inflate(.01).contains(inner.topLeft), isTrue);
  expect(outer.inflate(.01).contains(inner.bottomRight), isTrue);
}

void main() {
  testWidgets('実テーマで通常・文字2倍・受付猶予でもヘッダーと協力HUDが盤面を覆わない', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (final size in const [Size(360, 640), Size(412, 900)]) {
      tester.view.physicalSize = size;
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final remaining in ['残り 3:00', '結果の受付 残り 0:30']) {
          for (final peer in [_ally, _rival]) {
            await tester.pumpWidget(_app(peer: peer, remaining: remaining));
            final viewport = Offset.zero & size;
            expect(
              tester.getRect(find.byKey(const Key('game-surface'))),
              viewport,
            );
            final header = tester.getRect(find.byKey(const Key('game-status')));
            final game = tester.getRect(
              find.byType(peer.team == _self.team ? CooperativeGame : DuelGame),
            );
            expect(game.top, closeTo(header.bottom, .01));
            expect(game.bottom, closeTo(viewport.bottom, .01));
            for (final key in ['remaining-time', 'game-demo-menu']) {
              _expectInside(header, tester.getRect(find.byKey(Key(key))));
            }
            if (peer.team == _self.team) {
              final hud = tester.getRect(find.byKey(const Key('coop-status')));
              final text = tester.getRect(find.byKey(const Key('coop-hud')));
              final board = tester.getRect(
                find.byKey(const Key('coop-playfield')),
              );
              _expectInside(viewport, text);
              _expectInside(hud, text);
              expect(hud.top, greaterThanOrEqualTo(header.bottom));
              expect(board.top, closeTo(hud.bottom, .01));
              expect(board.bottom, closeTo(viewport.bottom, .01));
              final firstCan = tester.getRect(
                find.byKey(const Key('soul-can-1')),
              );
              expect(firstCan.top, greaterThan(board.top));
            }
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
  });

  testWidgets('小画面・文字2倍の協力失敗バナーも収まり、完了通知は一度だけ', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final outcomes = <Outcome>[];
    await tester.pumpWidget(
      _app(remaining: '結果の受付 残り 0:30', onCompleted: outcomes.add),
    );
    await tester.tap(find.byType(CooperativeGame));
    await tester.pump();
    await tester.pump(SoulTiming.intro);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(SoulTiming.fall + SoulTiming.fallLinger);
    expect(find.byKey(const Key('coop-final')), findsOneWidget);
    final game = tester.getRect(find.byType(CooperativeGame));
    _expectInside(game, tester.getRect(find.text('ざんねん…')));
    _expectInside(game, tester.getRect(find.textContaining('魂ポイント +0 pt')));
    expect(tester.takeException(), isNull);
    await tester.pump(SoulTiming.finalPanel);
    await tester.pump(const Duration(seconds: 3));
    expect(outcomes, [Outcome.coopFailure]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('残り時間表示を更新しても協力の時計と運んだ魂を保持する', (tester) async {
    final remaining = ValueNotifier('残り 3:00');
    addTearDown(remaining.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tsunagunTheme(),
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: remaining,
            builder: (context, value, _) => _scene(_ally, value, (_) {}),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CooperativeGame));
    await tester.pump();
    await tester.pump(SoulTiming.intro);
    final state = tester.state(find.byType(CooperativeGame));
    final run = tester.widget<SoulStage>(find.byType(SoulStage)).run;
    final level = SoulLevel.all.first;
    var time = Duration.zero;
    for (final hop in [1, 3, 5]) {
      final arrival = level.firstArrival + level.flight * (hop - 1);
      await tester.pump(arrival - time);
      time = arrival;
      remaining.value = '残り 2:${60 - hop}';
      await tester.pump();
      expect(tester.state(find.byType(CooperativeGame)), same(state));
      expect(tester.widget<SoulStage>(find.byType(SoulStage)).run, same(run));
      await tester.tap(find.byType(CooperativeGame));
      await tester.pump();
      expect(run.carriedHops, hop);
    }
    await tester.pump(run.holeArrival - time);
    await tester.pump(SoulTiming.holeSink + SoulTiming.clearLinger);
    final hud = tester.widget<Text>(find.byKey(const Key('coop-hud'))).data!;
    expect(hud, contains('レベル 2/3'));
    expect(hud, contains('魂 1 pt'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('残り時間表示を更新しても対戦の落下位置と停止結果を保持する', (tester) async {
    final remaining = ValueNotifier('残り 3:00');
    addTearDown(remaining.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: tsunagunTheme(),
        home: Scaffold(
          body: ValueListenableBuilder<String>(
            valueListenable: remaining,
            builder: (context, value, _) => _scene(_rival, value, (_) {}),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final state = tester.state(find.byType(DuelGame));
    final before = tester.widget<RaceField>(find.byType(RaceField)).selfDepth;
    expect(before, greaterThan(0));
    remaining.value = '残り 2:59';
    await tester.pump();
    expect(tester.state(find.byType(DuelGame)), same(state));
    expect(tester.widget<RaceField>(find.byType(RaceField)).selfDepth, before);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(DuelGame));
    await tester.pump();
    final decision = tester
        .widget<RaceField>(find.byType(RaceField))
        .selfDecision;
    expect(decision, isNotNull);
    remaining.value = '結果の受付 残り 0:30';
    await tester.pump();
    expect(
      tester.widget<RaceField>(find.byType(RaceField)).selfDecision,
      same(decision),
    );
    expect(tester.takeException(), isNull);
  });
}
