import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/features/player/player_capture_view.dart';
import 'package:mayoi_quest/features/player/player_join_view.dart';
import 'package:mayoi_quest/features/player/player_judgement_view.dart';
import 'package:mayoi_quest/features/player/player_map_view.dart';
import 'package:mayoi_quest/features/player/player_qr_view.dart';
import 'package:mayoi_quest/features/player/player_ranking_view.dart';
import 'package:mayoi_quest/features/player/player_result_view.dart';
import 'package:mayoi_quest/features/player/player_start_waiting_view.dart';

Widget _host(Widget body, {double textScale = 1}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: body,
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets('join validates, prevents duplicate requests and preserves input', (tester) async {
    final pending = Completer<void>();
    final calls = <List<String>>[];
    await tester.pumpWidget(
      _host(
        PlayerJoinView(
          onJoin: (code, name) {
            calls.add([code, name]);
            return pending.future;
          },
        ),
      ),
    );
    await _tap(tester, '参加する');
    expect(calls, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('playerJoinRoomCode')), ' ROOM ');
    await tester.enterText(find.byKey(const ValueKey('playerJoinDisplayName')), ' 松本 ');
    await _tap(tester, '参加する');
    await _tap(tester, '参加中…');
    expect(calls, [
      ['ROOM', '松本'],
    ]);
    pending.completeError(StateError('test failure'));
    await tester.pump();
    expect(find.text('参加できませんでした。もう一度お試しください。'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('playerJoinRoomCode'))).controller!.text, ' ROOM ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('waiting only displays shared updates and disables reconnect retry', (tester) async {
    var retries = 0;
    Widget waiting({bool reconnecting = false, String remaining = '00:10'}) => _host(
      PlayerStartWaitingView(
        roomName: '固定コース',
        playerName: '松本',
        remainingTimeLabel: remaining,
        isReconnecting: reconnecting,
        errorMessage: '接続を確認してください',
        onRetry: () => retries++,
      ),
    );
    await tester.pumpWidget(waiting());
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('00:10'), findsOneWidget);
    await _tap(tester, 'もう一度確認する');
    expect(retries, 1);
    await tester.pumpWidget(waiting(reconnecting: true, remaining: '00:05'));
    await _tap(tester, 'もう一度確認する');
    expect(retries, 1);
    expect(find.text('00:05'), findsOneWidget);
  });

  testWidgets('floor selection survives progress updates and goal follows caller', (tester) async {
    final selected = <String>[];
    var goals = 0;
    Widget map({bool goalAllowed = false, bool removeFloor = false}) => _host(
      PlayerMapView(
        courseName: '固定コース',
        remainingTimeLabel: '09:00',
        progressLabel: '進捗は共通状態の表示',
        floors: {
          '1F': const Center(child: Text('1F案内図')),
          if (!removeFloor) '2F': const Center(child: Text('2F案内図')),
        },
        canScanGoal: goalAllowed,
        onFloorChanged: selected.add,
        onScanGoal: () => goals++,
      ),
    );
    await tester.pumpWidget(map());
    await _tap(tester, '2F');
    expect(selected, ['2F']);
    expect(find.text('2F案内図'), findsOneWidget);
    await _tap(tester, 'ゴールQRを読み取る');
    expect(goals, 0);
    await tester.pumpWidget(map(goalAllowed: true));
    expect(find.text('2F案内図'), findsOneWidget);
    await _tap(tester, 'ゴールQRを読み取る');
    expect(goals, 1);
    await tester.pumpWidget(map(removeFloor: true));
    expect(find.text('1F案内図'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR processing blocks retry and injected scanner touch', (tester) async {
    var scans = 0;
    var retries = 0;
    await tester.pumpWidget(
      _host(
        PlayerQrView(
          title: 'スタートQR',
          instruction: '会場のスタートQRを読み取ってください',
          scanner: TextButton(onPressed: () => scans++, child: const Text('読取枠')),
          isProcessing: true,
          onRetry: () => retries++,
        ),
      ),
    );
    final scannerBarrier = find.descendant(of: find.byType(PlayerQrView), matching: find.byType(AbsorbPointer));
    expect(tester.widget<AbsorbPointer>(scannerBarrier).absorbing, isTrue);
    await tester.tap(find.text('読取枠'), warnIfMissed: false);
    await _tap(tester, 'もう一度読み取る');
    expect(scans, 0);
    expect(retries, 0);
  });

  testWidgets('capture disables unavailable camera and guards in-flight request', (tester) async {
    final pending = Completer<void>();
    var captures = 0;
    Widget camera(bool ready) => _host(
      PlayerCaptureView(
        preview: const ColoredBox(color: Colors.black),
        instruction: 'チェックポイントの対象を撮影',
        cameraReady: ready,
        onCapture: () {
          captures++;
          return pending.future;
        },
      ),
    );
    await tester.pumpWidget(camera(false));
    await _tap(tester, '撮影する');
    expect(captures, 0);
    await tester.pumpWidget(camera(true));
    await _tap(tester, '撮影する');
    await _tap(tester, '撮影中…');
    expect(captures, 1);
    await tester.pumpWidget(_host(const SizedBox()));
    pending.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed photo submission keeps image and permits retry or retake', (tester) async {
    var attempts = 0;
    var retakes = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      _host(
        PlayerPhotoReviewView(
          photo: const Center(child: Text('撮影済み写真')),
          onSubmit: () {
            attempts++;
            return attempts == 1 ? pending.future : Future<void>.value();
          },
          onRetake: () => retakes++,
        ),
      ),
    );
    await _tap(tester, 'この写真で判定する');
    await _tap(tester, '送信中…');
    await _tap(tester, '撮り直す');
    expect(attempts, 1);
    expect(retakes, 0);
    pending.completeError(StateError('test failure'));
    await tester.pump();
    expect(find.text('撮影済み写真'), findsOneWidget);
    expect(find.text('写真を送信できませんでした。もう一度お試しください。'), findsOneWidget);
    await _tap(tester, 'この写真で判定する');
    expect(attempts, 2);
    await _tap(tester, '撮り直す');
    expect(retakes, 1);
  });

  testWidgets('judgement exposes only actions corresponding to supplied state', (tester) async {
    var retakes = 0;
    var retries = 0;
    var continues = 0;
    Widget result(PlayerJudgementDisplayState state) => _host(
      PlayerJudgementView(
        state: state,
        message: '共通側からの判定理由',
        awardedScoreLabel: '+50点',
        onRetake: () => retakes++,
        onRetry: () => retries++,
        onContinue: () => continues++,
      ),
    );
    await tester.pumpWidget(result(PlayerJudgementDisplayState.processing));
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.pumpWidget(result(PlayerJudgementDisplayState.retake));
    expect(find.text('+50点'), findsNothing);
    await _tap(tester, '撮り直す');
    await tester.pumpWidget(result(PlayerJudgementDisplayState.error));
    await _tap(tester, '同じ写真で再試行する');
    await tester.pumpWidget(result(PlayerJudgementDisplayState.success));
    expect(find.text('+50点'), findsOneWidget);
    await _tap(tester, 'マップへ戻る');
    expect([retakes, retries, continues], [1, 1, 1]);
  });

  testWidgets('320px screen and enlarged text keep actions reachable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opens = 0;
    final pages = <Widget>[
      PlayerJoinView(onJoin: (_, _) async {}),
      const PlayerStartWaitingView(roomName: 'とても長い固定コース名', playerName: '松本'),
      const PlayerQrView(title: 'チェックポイントQR', instruction: 'QRを読み取ってください', scanner: SizedBox()),
      PlayerCaptureView(
        preview: const SizedBox(),
        instruction: '撮影する対象を確認してください',
        cameraReady: true,
        onCapture: () async {},
      ),
      PlayerPhotoReviewView(photo: const SizedBox(), onSubmit: () async {}, onRetake: () {}),
      const PlayerJudgementView(state: PlayerJudgementDisplayState.error, message: '接続を確認してください'),
      PlayerMapView(
        courseName: '固定コース',
        remainingTimeLabel: '10:00',
        progressLabel: 'チェックポイントを探そう',
        floors: const {'1F': SizedBox()},
        canScanGoal: false,
        onScanCheckpoint: () {},
      ),
      const PlayerRankingView(
        rows: [
          PlayerRankingRow(rankLabel: '同率1位', playerName: '長いプレイヤー名の松本', scoreLabel: '150点', isCurrentPlayer: true),
        ],
      ),
      PlayerResultView(
        title: 'ゴール！',
        statusLabel: '集計しています',
        scoreLabel: '150点',
        rankLabel: '同率1位',
        isFinal: false,
        onOpenRanking: () => opens++,
      ),
    ];
    for (final page in pages) {
      await tester.pumpWidget(_host(page, textScale: 2));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
    expect(find.text('仮集計'), findsOneWidget);
    await _tap(tester, 'ランキングを見る');
    expect(opens, 1);
    expect(tester.takeException(), isNull);
  });
}
