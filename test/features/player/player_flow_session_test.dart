import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/core/mock/in_memory_match_backend.dart';
import 'package:mayoi_quest/core/mock/sample_course.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/providers.dart';
import 'package:mayoi_quest/core/repository/match_repository.dart';
import 'package:mayoi_quest/core/session/session_store.dart';
import 'package:mayoi_quest/features/player/player_flow_page.dart';
import 'package:mayoi_quest/features/player/player_join_view.dart';
import 'package:mayoi_quest/features/player/player_map_view.dart';
import 'package:mayoi_quest/features/player/player_media.dart';
import 'package:mayoi_quest/features/player/player_qr_view.dart';
import 'package:mayoi_quest/features/player/player_result_view.dart';

void main() {
  testWidgets('参加完了待ちに復帰先を差し替えても古いルームの復帰記録を保存しない', (tester) async {
    const latency = Duration(milliseconds: 100);
    final h = _SessionHarness(latency: latency);
    addTearDown(h.dispose);
    final rooms = (await tester.runAsync(() async {
      final oldRoom = await h.owner.createRoom(courseId: sampleCourse.id);
      final resumedRoom = await h.owner.createRoom(courseId: sampleCourse.id);
      await h.player.joinRoom(roomId: resumedRoom.id, displayName: '復帰する参加者');
      return [oldRoom, resumedRoom];
    }))!;
    final oldRoom = rooms[0];
    final resumedRoom = rooms[1];
    h.sessions.value = ActiveSession(role: SessionRole.player, roomId: resumedRoom.id);
    await h.pump(tester);
    await _join(tester, oldRoom.code);

    // findRoomByCode が完了し、joinRoom の遅延応答を待っている。
    await tester.pump(latency);
    expect(h.sessions.saveCalls, 0);
    h.resumeRoomId.value = resumedRoom.id;
    await tester.pump();
    await tester.pump(latency);
    await _until(tester, () => find.byType(PlayerQrView).evaluate().isNotEmpty);

    expect(h.sessions.saveCalls, 0, reason: '古い参加処理から共有の保存先を更新しない');
    expect(h.sessions.value?.roomId, resumedRoom.id);
    final oldState = await tester.runAsync(() => h.player.watchRoom(oldRoom.id).first);
    expect(oldState?.participant('player'), isNotNull, reason: '参加自体は完了済みでも復帰先を巻き戻さない');
    expect(find.byType(PlayerJoinView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('復帰記録の再保存中は移動を抑止し完了後に通常操作へ戻る', (tester) async {
    final h = _SessionHarness();
    addTearDown(h.dispose);
    final room = (await tester.runAsync(h.runningRoom))!;
    h.sessions.failNextSave = true;
    await h.pump(tester, useParentRoute: true);
    await _tap(tester, 'プレイヤーを開く');
    await tester.pump(const Duration(milliseconds: 400));
    await _join(tester, room.code);
    await _until(tester, () => find.text('続きから開く記録を保存し直す').evaluate().isNotEmpty);
    expect(h.sessions.saveCalls, 1);

    final saved = Completer<void>();
    h.sessions.pendingSave = saved.future;
    await _tap(tester, '続きから開く記録を保存し直す');
    expect(h.sessions.saveCalls, 2);
    final continueButton = find.ancestor(
      of: find.text('記録せずに参加を続ける'),
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(continueButton).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PlayerFlowPage), findsOneWidget, reason: '保存中に親画面へ戻らない');

    saved.complete();
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    expect(h.sessions.value?.roomId, room.id);
    expect(find.text('記録を保存中…'), findsNothing);
    await tester.binding.handlePopRoute();
    await _untilHome(tester);
    expect(find.byType(PlayerFlowPage), findsNothing, reason: '保存完了後はbusy状態を解除して戻れる');
    expect(tester.takeException(), isNull);
  });

  testWidgets('遅い復帰記録削除の完了後も閉じる操作で親Routeへ戻る', (tester) async {
    final h = _SessionHarness();
    addTearDown(h.dispose);
    final room = (await tester.runAsync(h.finishedRoom))!;
    h.sessions.value = ActiveSession(role: SessionRole.player, roomId: room.id);
    h.resumeRoomId.value = room.id;
    await h.pump(tester, useParentRoute: true);
    await _tap(tester, 'プレイヤーを開く');
    await tester.pump(const Duration(milliseconds: 400));
    await _until(tester, () => find.byType(PlayerResultView).evaluate().isNotEmpty);

    final cleared = Completer<void>();
    h.sessions.pendingClear = cleared.future;
    await _tap(tester, '閉じる');
    await _until(tester, () => h.sessions.clearCalls == 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PlayerFlowPage), findsOneWidget, reason: '削除完了前は閉じない');
    cleared.complete();
    await _untilHome(tester);
    expect(h.sessions.value, isNull);
    expect(find.byType(PlayerFlowPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('削除失敗は保存操作を出さず削除の再試行で閉じられる', (tester) async {
    final h = _SessionHarness();
    addTearDown(h.dispose);
    final room = (await tester.runAsync(h.finishedRoom))!;
    h.sessions.value = ActiveSession(role: SessionRole.player, roomId: room.id);
    h.sessions.failNextClear = true;
    h.resumeRoomId.value = room.id;
    await h.pump(tester, useParentRoute: true);
    await _tap(tester, 'プレイヤーを開く');
    await tester.pump(const Duration(milliseconds: 400));
    await _until(tester, () => find.byType(PlayerResultView).evaluate().isNotEmpty);

    await _tap(tester, '閉じる');
    await _until(tester, () => find.text('記録の削除を再試行').evaluate().isNotEmpty);
    expect(find.text('続きから開く記録を保存し直す'), findsNothing);
    expect(h.sessions.value?.roomId, room.id, reason: '失敗後も保存済みの復帰先は保持する');
    expect(h.sessions.saveCalls, 0);
    await _tap(tester, '記録の削除を再試行');
    await _untilHome(tester);
    expect(h.sessions.clearCalls, 2);
    expect(h.sessions.value, isNull);
    expect(tester.takeException(), isNull);
  });
}

const _homeLabel = 'セッションテストのホーム';

Future<void> _untilHome(WidgetTester tester) =>
    _until(tester, () => find.text(_homeLabel).evaluate().isNotEmpty && find.byType(PlayerFlowPage).evaluate().isEmpty);

Future<void> _join(WidgetTester tester, String roomCode) async {
  await tester.enterText(find.byKey(const ValueKey('playerJoinRoomCode')), roomCode);
  await tester.enterText(find.byKey(const ValueKey('playerJoinDisplayName')), '松本');
  await _tap(tester, '参加する');
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: '保留中の処理が画面へ反映される');
}

class _SessionHarness {
  _SessionHarness({Duration latency = Duration.zero}) {
    backend = InMemoryMatchBackend(courses: const [sampleCourse], clock: () => now, latency: latency);
    owner = backend.repositoryFor('owner');
    player = backend.repositoryFor('player');
  }

  final now = DateTime.now();
  final sessions = _RecordingSessionStore();
  final resumeRoomId = ValueNotifier<String?>(null);
  late final InMemoryMatchBackend backend;
  late final MatchRepository owner;
  late final MatchRepository player;

  Future<Room> runningRoom() async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    await player.joinRoom(roomId: room.id, displayName: '松本');
    await player.scanStart(roomId: room.id, qr: sampleCourse.startQr);
    await owner.startRoom(room.id);
    return room;
  }

  Future<Room> finishedRoom() async {
    final room = await runningRoom();
    await owner.finishRoom(room.id);
    return room;
  }

  Widget _flow() => ValueListenableBuilder<String?>(
    valueListenable: resumeRoomId,
    builder: (context, roomId, child) => Scaffold(body: PlayerFlowPage(resumeRoomId: roomId)),
  );

  Future<void> pump(WidgetTester tester, {bool useParentRoute = false}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockBackendProvider.overrideWithValue(backend),
          currentUserIdProvider.overrideWithValue('player'),
          sessionStoreProvider.overrideWithValue(sessions),
          tickerProvider.overrideWith((ref) => Stream.value(now)),
          playerQrScannerBuilderProvider.overrideWithValue(
            (context, onCode, enabled) => const Center(child: Text('テスト用QR読取領域')),
          ),
        ],
        child: MaterialApp(
          home: useParentRoute
              ? Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        const Text(_homeLabel),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => _flow())),
                          child: const Text('プレイヤーを開く'),
                        ),
                      ],
                    ),
                  ),
                )
              : _flow(),
        ),
      ),
    );
  }

  void dispose() => resumeRoomId.dispose();
}

/// 保存先の契約だけを置き換え、ルーム・参加・開始終了は共通モックを使う。
class _RecordingSessionStore extends SessionStore {
  ActiveSession? value;
  var saveCalls = 0;
  var clearCalls = 0;
  var failNextSave = false;
  var failNextClear = false;
  Future<void>? pendingSave;
  Future<void>? pendingClear;

  @override
  Future<ActiveSession?> load() async => value;

  @override
  Future<void> save(ActiveSession session) async {
    saveCalls++;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('復帰記録の保存に失敗');
    }
    final pending = pendingSave;
    if (pending != null) await pending;
    value = session;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    if (failNextClear) {
      failNextClear = false;
      throw StateError('復帰記録の削除に失敗');
    }
    final pending = pendingClear;
    if (pending != null) await pending;
    value = null;
  }
}
