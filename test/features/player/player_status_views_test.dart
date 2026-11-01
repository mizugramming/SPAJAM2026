import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/features/player/player_join_view.dart';
import 'package:mayoi_quest/features/player/player_ranking_view.dart';
import 'package:mayoi_quest/features/player/player_result_view.dart';
import 'package:mayoi_quest/features/player/player_start_waiting_view.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  theme: ThemeData(useMaterial3: true),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets('join remains usable with keyboard, large text and long errors', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final attempts = <List<String>>[];
    final pending = Completer<void>();
    await tester.pumpWidget(
      _host(
        PlayerJoinView(
          initialRoomCode: ' 案内されたコード ',
          errorMessage: '主催者の案内を確認してから、入力したルームコードでもう一度参加してください。',
          onJoin: (code, name) {
            attempts.add([code, name]);
            return pending.future;
          },
        ),
        textScale: 2,
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('playerJoinDisplayName')));
    await tester.enterText(find.byKey(const ValueKey('playerJoinDisplayName')), ' 松本 ');
    await _tap(tester, '参加する');
    await _tap(tester, '参加中…');
    expect(attempts, [
      ['案内されたコード', '松本'],
    ]);
    pending.completeError(StateError('connection failed'));
    await tester.pump();
    expect(find.text('参加できませんでした。もう一度お試しください。'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('playerJoinDisplayName'))).controller!.text, ' 松本 ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('join safely finishes after leaving the form', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      _host(PlayerJoinView(initialRoomCode: 'ROOM', initialDisplayName: '松本', onJoin: (_, _) => pending.future)),
    );
    await _tap(tester, '参加する');
    await tester.pumpWidget(_host(const SizedBox()));
    pending.completeError(StateError('late response'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown changes only when shared labels change', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Widget waiting(String remaining) => _host(
        PlayerStartWaitingView(
          roomName: '館内を巡る固定コース',
          playerName: '松本',
          startsAtLabel: '主催者が指定した開始時刻',
          remainingTimeLabel: remaining,
        ),
      );
      await tester.pumpWidget(waiting('00:10'));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('00:10'), findsOneWidget);
      final timerText = find.text('00:10');
      final liveParents = find.ancestor(
        of: timerText,
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.liveRegion == true),
      );
      expect(liveParents, findsNothing);
      await tester.pumpWidget(waiting('00:05'));
      expect(find.text('00:10'), findsNothing);
      expect(find.text('00:05'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ranking empty text respects supplied status and refresh state', (tester) async {
    Widget ranking({String? status, bool refreshing = false}) =>
        _host(PlayerRankingView(rows: const [], statusLabel: status, isRefreshing: refreshing));
    await tester.pumpWidget(ranking(status: 'ランキングの取得に失敗しました。'));
    expect(find.text('ランキングの取得に失敗しました。'), findsOneWidget);
    expect(find.text('ランキングはまだありません。'), findsNothing);
    await tester.pumpWidget(ranking(refreshing: true));
    expect(find.text('ランキングを更新しています…'), findsOneWidget);
    expect(find.text('ランキングはまだありません。'), findsNothing);
    await tester.pumpWidget(ranking(status: '  '));
    expect(find.text('ランキングはまだありません。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking keeps supplied order and current player during refresh', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var refreshes = 0;
      Widget ranking(bool refreshing) => _host(
        PlayerRankingView(
          isRefreshing: refreshing,
          onRefresh: () => refreshes++,
          rows: const [
            PlayerRankingRow(rankLabel: '同率1位', playerName: '嶋本', scoreLabel: '150点'),
            PlayerRankingRow(rankLabel: '同率1位', playerName: '松本', scoreLabel: '150点', isCurrentPlayer: true),
          ],
        ),
      );
      await tester.pumpWidget(ranking(false));
      expect(tester.getTopLeft(find.text('嶋本')).dy, lessThan(tester.getTopLeft(find.text('松本')).dy));
      expect(find.semantics.byLabel('あなた、同率1位、松本、150点'), findsOne);
      await _tap(tester, 'ランキングを更新');
      expect(refreshes, 1);
      await tester.pumpWidget(ranking(true));
      expect(find.text('嶋本'), findsOneWidget);
      expect(find.text('松本'), findsOneWidget);
      await _tap(tester, '更新中…');
      expect(refreshes, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('result updates to final values and retains reachable actions', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var rankingOpens = 0;
    var closes = 0;
    Widget result(bool finalResult) => _host(
      PlayerResultView(
        title: '館内ミッションの結果',
        statusLabel: finalResult ? '集計が完了しました' : '参加者の結果を集計しています',
        scoreLabel: finalResult ? '200点' : '150点',
        rankLabel: finalResult ? '同率1位' : '集計中',
        isFinal: finalResult,
        scoreBreakdown: const [Text('共通状態から渡された指定ポイントの得点と自由ミッションの得点')],
        onOpenRanking: () => rankingOpens++,
        onClose: () => closes++,
      ),
      textScale: 2,
    );
    await tester.pumpWidget(result(false));
    expect(find.text('仮集計'), findsOneWidget);
    expect(find.text('最終結果'), findsNothing);
    await _tap(tester, 'ランキングを見る');
    expect(rankingOpens, 1);
    await tester.pumpWidget(result(true));
    expect(find.text('仮集計'), findsNothing);
    expect(find.text('最終結果'), findsOneWidget);
    expect(find.text('200点'), findsOneWidget);
    expect(find.text('150点'), findsNothing);
    await _tap(tester, '閉じる');
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waiting keeps long shared labels readable with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retries = 0;
    await tester.pumpWidget(
      _host(
        PlayerStartWaitingView(
          roomName: '本館と別館を巡るナイトミッションのルーム',
          playerName: 'とても長いプレイヤー名の松本',
          startsAtLabel: '主催者が案内する開始時刻を確認しています',
          remainingTimeLabel: '開始時刻を確認中',
          errorMessage: '通信状況を確認してから、もう一度開始状況を確認してください。',
          onRetry: () => retries++,
        ),
        textScale: 2,
      ),
    );
    expect(find.text('開始時刻を確認中'), findsOneWidget);
    expect(find.text('主催者が案内する開始時刻を確認しています'), findsOneWidget);
    await _tap(tester, 'もう一度確認する');
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking preserves long supplied values on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _host(
          const PlayerRankingView(
            rows: [
              PlayerRankingRow(
                rankLabel: '同率第123位・確定前',
                playerName: '長い名前でも省略せずに確認できるプレイヤー',
                scoreLabel: '獲得スコアは共通側で集計しています',
                isCurrentPlayer: true,
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(find.semantics.byLabel('あなた、同率第123位・確定前、長い名前でも省略せずに確認できるプレイヤー、獲得スコアは共通側で集計しています'), findsOne);
      await tester.ensureVisible(find.text('獲得スコアは共通側で集計しています'));
      expect(find.text('あなた'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('result preserves long score and rank labels with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var closes = 0;
    await tester.pumpWidget(
      _host(
        PlayerResultView(
          title: '本館と別館を巡るナイトミッションの最終結果',
          statusLabel: '集計が完了しました。参加したルームの結果をご確認ください。',
          scoreLabel: '指定ポイントと自由ミッションの合計は12,345点',
          rankLabel: '参加者のうち同率第123位',
          isFinal: true,
          onClose: () => closes++,
        ),
        textScale: 2,
      ),
    );
    expect(find.text('指定ポイントと自由ミッションの合計は12,345点'), findsOneWidget);
    expect(find.text('参加者のうち同率第123位'), findsOneWidget);
    await _tap(tester, '閉じる');
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });
}
