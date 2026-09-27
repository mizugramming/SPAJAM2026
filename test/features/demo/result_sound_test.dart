import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/conveyor_editor.dart';
import 'package:spajam2026/features/demo/result_sound_player.dart';

class _RecordingSoundPlayer implements ResultSoundPlayer {
  _RecordingSoundPlayer({this.fail = false, this.failAsynchronously = true});

  final bool fail;
  final bool failAsynchronously;
  final calls = <String>[];

  int count(String operation) =>
      calls.where((call) => call == operation).length;

  Future<void> _call(String operation) {
    calls.add(operation);
    if (!fail) return Future<void>.value();
    final error = StateError('Audio $operation failed');
    if (!failAsynchronously) throw error;
    return Future<void>.error(error);
  }

  @override
  Future<void> prepare() => _call('prepare');

  @override
  Future<void> playShobone() => _call('play');

  @override
  Future<void> stop() => _call('stop');

  @override
  Future<void> dispose() => _call('dispose');
}

void _startEvent(DemoController demo) {
  demo.createRoom(const Duration(minutes: 3));
  demo.setProfile(nickname: 'つな太郎', hobby: '散歩');
  expect(demo.saveProfile(), isNull);
  demo.startEvent();
  expect(demo.phase, AppPhase.home);
}

void _selectGame(DemoController demo, Outcome outcome) {
  final cooperative =
      outcome == Outcome.coopSuccess || outcome == Outcome.coopFailure;
  final peer = demo.peers.firstWhere(
    (peer) =>
        !demo.completedPeerIds.contains(peer.id) &&
        (peer.team == demo.self.team) == cooperative,
  );
  demo.openPairing();
  expect(demo.selectPeer(peer.id), isTrue);
  expect(demo.confirmPeer(), isTrue);
}

Future<DemoController> _launch(
  WidgetTester tester,
  _RecordingSoundPlayer sound, {
  DemoController? controller,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 900);
  addTearDown(tester.view.reset);
  final demo = controller ?? DemoController(autoTick: false);
  if (controller == null) _startEvent(demo);
  addTearDown(demo.dispose);
  await tester.pumpWidget(
    TsunagunApp(
      animateCharacters: false,
      controller: demo,
      resultSoundPlayer: sound,
    ),
  );
  await tester.pumpAndSettle();
  return demo;
}

Future<void> _enterGame(
  WidgetTester tester,
  DemoController demo,
  Outcome outcome,
) async {
  _selectGame(demo, outcome);
  await tester.pumpAndSettle();
  expect(demo.phase, AppPhase.game);
}

Future<void> _finishGame(
  WidgetTester tester,
  DemoController demo,
  Outcome outcome,
) async {
  await _enterGame(tester, demo, outcome);
  expect(demo.injectOutcome(outcome), isTrue);
  await tester.pumpAndSettle();
  expect(demo.phase, AppPhase.result);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, String key) =>
    _tap(tester, find.byKey(Key(key)));

void main() {
  testWidgets('ゲーム入場で準備し、対戦敗北・協力失敗だけ結果表示時に一度鳴る', (tester) async {
    for (final outcome in Outcome.values) {
      final sound = _RecordingSoundPlayer();
      final demo = await _launch(tester, sound);
      expect(sound.count('play'), 0);
      await _enterGame(tester, demo, outcome);
      expect(sound.count('prepare'), 1, reason: '$outcome');
      expect(sound.count('play'), 0);

      expect(demo.injectOutcome(outcome), isTrue);
      expect(sound.count('play'), 0, reason: '結果の描画前には鳴らさない');
      await tester.pumpAndSettle();
      final expected = outcome == Outcome.loss || outcome == Outcome.coopFailure
          ? 1
          : 0;
      expect(sound.count('play'), expected, reason: '$outcome');
      expect(demo.injectOutcome(outcome), isFalse);
      demo.advance(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(sound.count('play'), expected, reason: '重複結果や時計更新で鳴らさない');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('初期の敗北結果は一度だけ鳴り、時計・フォント・コンベアの再描画では鳴らない', (tester) async {
    final demo = DemoController(autoTick: false);
    _startEvent(demo);
    _selectGame(demo, Outcome.loss);
    expect(demo.injectOutcome(Outcome.loss), isTrue);
    final result = demo.lastResult;
    final sound = _RecordingSoundPlayer();
    await _launch(tester, sound, controller: demo);
    expect(sound.count('play'), 1);

    demo.advance(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _key(tester, 'demo-info');
    await _key(tester, 'font-rounded');
    await _tap(tester, find.text('閉じる').last);
    await _key(tester, 'demo-info');
    await _key(tester, 'edit-conveyor');
    expect(find.byType(ConveyorEditor), findsOneWidget);
    await _key(tester, 'conveyor-scale-plus');
    await _key(tester, 'conveyor-x-plus');
    await _key(tester, 'save-conveyor-layout');

    expect(find.byType(ConveyorEditor), findsNothing);
    expect(demo.phase, AppPhase.result);
    expect(demo.lastResult, same(result));
    expect(demo.boneCount, 1);
    expect(sound.count('play'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('対戦の確定予約と、受付期限から直接進む綱引きでは鳴らない', (tester) async {
    final sound = _RecordingSoundPlayer();
    final demo = await _launch(tester, sound);
    await _enterGame(tester, demo, Outcome.loss);
    expect(demo.reserveOutcome(Outcome.loss), isTrue);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.game);
    expect(sound.count('play'), 0);

    demo.advance(demo.remaining + DemoController.settlementGrace);
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.finale);
    expect(demo.boneCount, 1, reason: '確定報酬は反映してもショBONE画面を経由しない');
    expect(sound.count('play'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('帰還・リセット・背景移行・破棄で停止し、復帰は無音で新しい敗北だけ再び鳴る', (tester) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final sound = _RecordingSoundPlayer();
    final demo = await _launch(tester, sound);
    await _finishGame(tester, demo, Outcome.loss);
    expect(sound.count('play'), 1);

    var stops = sound.count('stop');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(sound.count('stop'), greaterThan(stops));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sound.count('play'), 1);

    stops = sound.count('stop');
    await _key(tester, 'return-home');
    expect(demo.phase, AppPhase.home);
    expect(sound.count('stop'), greaterThan(stops));
    await _finishGame(tester, demo, Outcome.coopFailure);
    expect(sound.count('play'), 2);

    stops = sound.count('stop');
    demo.reset();
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.entry);
    expect(sound.count('stop'), greaterThan(stops));
    _startEvent(demo);
    await tester.pumpAndSettle();
    await _finishGame(tester, demo, Outcome.loss);
    expect(sound.count('play'), 3, reason: '同じ相手でもデモをやり直せば新しい結果');

    stops = sound.count('stop');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sound.count('stop'), greaterThan(stops));
    expect(sound.count('dispose'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('結果の描画前に帰還・リセットした場合は予約した再生を取り消す', (tester) async {
    final sound = _RecordingSoundPlayer();
    final demo = await _launch(tester, sound);
    await _enterGame(tester, demo, Outcome.loss);
    expect(demo.injectOutcome(Outcome.loss), isTrue);
    // 次のフレームより先に結果画面を離れる。
    demo.returnHome();
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.home);
    expect(sound.count('play'), 0);

    await _enterGame(tester, demo, Outcome.coopFailure);
    expect(demo.injectOutcome(Outcome.coopFailure), isTrue);
    demo.reset();
    await tester.pumpAndSettle();
    expect(demo.phase, AppPhase.entry);
    expect(sound.count('play'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('音声の準備・再生・停止・破棄が同期または非同期に失敗してもゲームの進行を止めない', (tester) async {
    for (final asyncFailure in [false, true]) {
      final sound = _RecordingSoundPlayer(
        fail: true,
        failAsynchronously: asyncFailure,
      );
      final demo = await _launch(tester, sound);
      await _finishGame(tester, demo, Outcome.loss);
      expect(sound.count('prepare'), 1);
      expect(sound.count('play'), 1);
      expect(demo.boneCount, 1);
      expect(tester.takeException(), isNull);

      await _key(tester, 'return-home');
      expect(demo.phase, AppPhase.home);
      expect(sound.count('stop'), greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(sound.count('dispose'), 1);
      expect(tester.takeException(), isNull);
    }
  });
}
