import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mayoi_quest/core/mock/in_memory_match_backend.dart';
import 'package:mayoi_quest/core/mock/mock_photo_judge.dart';
import 'package:mayoi_quest/core/mock/sample_course.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/providers.dart';
import 'package:mayoi_quest/core/repository/match_repository.dart';
import 'package:mayoi_quest/core/session/session_store.dart';
import 'package:mayoi_quest/features/player/player_capture_view.dart';
import 'package:mayoi_quest/features/player/player_flow_page.dart';
import 'package:mayoi_quest/features/player/player_join_view.dart';
import 'package:mayoi_quest/features/player/player_judgement_view.dart';
import 'package:mayoi_quest/features/player/player_map_view.dart';
import 'package:mayoi_quest/features/player/player_media.dart';
import 'package:mayoi_quest/features/player/player_qr_view.dart';
import 'package:mayoi_quest/features/player/player_result_view.dart';
import 'package:mayoi_quest/features/player/player_start_waiting_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('固定コースを参加からゴール・仮結果・運営終了後の確定まで共通状態で進める', (tester) async {
    final h = _FlowHarness();
    addTearDown(h.dispose);
    final room = await h.owner.createRoom(courseId: sampleCourse.id);
    await h.pump(tester);

    expect(find.byType(PlayerJoinView), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('playerJoinRoomCode')), room.code);
    await tester.enterText(find.byKey(const ValueKey('playerJoinDisplayName')), '松本');
    await _tapText(tester, '参加する');
    await _until(tester, () => find.byType(PlayerQrView).evaluate().isNotEmpty);
    final saved = await h.sessions.load();
    expect(saved?.roomId, room.id);
    expect(saved?.role, SessionRole.player);

    await _scan(tester, sampleCourse.startQr);
    await _until(tester, () => find.byType(PlayerStartWaitingView).evaluate().isNotEmpty);
    expect((await h.snapshot(room.id)).participant('player')!.isReady, isTrue);
    await h.owner.startRoom(room.id);
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    expect(tester.widget<PlayerMapView>(find.byType(PlayerMapView)).canScanGoal, isFalse);

    for (final checkpoint in sampleCourse.requiredCheckpoints) {
      await _completeCheckpoint(tester, checkpoint);
    }
    final afterClears = await h.snapshot(room.id);
    expect(afterClears.clearsOf('player').map((c) => c.checkpointId), containsAll(['cp-a', 'cp-b']));
    expect(tester.widget<PlayerMapView>(find.byType(PlayerMapView)).canScanGoal, isTrue);

    await _tapText(tester, 'ゴールQRを読み取る');
    await _scan(tester, sampleCourse.goalQr);
    await _until(tester, () => find.byType(PlayerResultView).evaluate().isNotEmpty);
    expect((await h.snapshot(room.id)).participant('player')!.hasFinished, isTrue);
    final provisional = tester.widget<PlayerResultView>(find.byType(PlayerResultView));
    expect(provisional.isFinal, isFalse);
    expect(provisional.scoreLabel, contains('${afterClears.scoreOf('player')}'));

    await h.owner.finishRoom(room.id);
    await _until(tester, () => tester.widget<PlayerResultView>(find.byType(PlayerResultView)).isFinal);
    expect(find.byType(Scaffold), findsOneWidget, reason: '外枠だけが Scaffold を持つ');
    await _tapText(tester, '閉じる');
    await _until(tester, () => find.byType(PlayerJoinView).evaluate().isNotEmpty);
    expect(await h.sessions.load(), isNull, reason: '結果を閉じると共通の復帰情報を消す');
    expect(tester.takeException(), isNull);
  });

  for (final phase in ['未読取', '開始待ち', '進行中', 'ゴール済み', '終了済み']) {
    testWidgets('resumeRoomId は共通状態「$phase」へ復帰する', (tester) async {
      final h = _FlowHarness();
      addTearDown(h.dispose);
      final room = await h.owner.createRoom(courseId: sampleCourse.id);
      await h.player.joinRoom(roomId: room.id, displayName: '松本');
      if (phase != '未読取') {
        await h.player.scanStart(roomId: room.id, qr: sampleCourse.startQr);
      }
      if (phase == '進行中' || phase == 'ゴール済み' || phase == '終了済み') {
        await h.owner.startRoom(room.id);
      }
      if (phase == 'ゴール済み') {
        for (final checkpoint in sampleCourse.requiredCheckpoints) {
          await h.player.submitPhoto(roomId: room.id, checkpointId: checkpoint.id, photo: _photo);
        }
        await h.player.scanGoal(roomId: room.id, qr: sampleCourse.goalQr);
      }
      if (phase == '終了済み') await h.owner.finishRoom(room.id);
      await h.sessions.save(ActiveSession(role: SessionRole.player, roomId: room.id));
      await h.pump(tester, resumeRoomId: room.id);

      final expected = switch (phase) {
        '未読取' => find.byType(PlayerQrView),
        '開始待ち' => find.byType(PlayerStartWaitingView),
        '進行中' => find.byType(PlayerMapView),
        _ => find.byType(PlayerResultView),
      };
      await _until(tester, () => expected.evaluate().isNotEmpty);
      expect(find.byType(PlayerJoinView), findsNothing);
      if (phase == 'ゴール済み' || phase == '終了済み') {
        expect(tester.widget<PlayerResultView>(expected).isFinal, phase == '終了済み');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('判定の通信失敗は写真を保持して同じ写真で再送できる', (tester) async {
    final judge = ScriptedPhotoJudge()
      ..enqueueNetworkFailure()
      ..enqueuePass('再送で確認できました');
    final h = _FlowHarness(judge: judge);
    addTearDown(h.dispose);
    final room = await h.runningRoom();
    await h.pump(tester, resumeRoomId: room.id);
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    await _openCapture(tester, sampleCourse.requiredCheckpoints.first);
    await _tapText(tester, '撮影する');
    await _until(tester, () => find.byType(PlayerPhotoReviewView).evaluate().isNotEmpty);
    await _tapText(tester, 'この写真で判定する');
    await _until(tester, () => _judgementState(tester) == PlayerJudgementDisplayState.error);
    expect(h.photos.calls, 1);
    expect((await h.snapshot(room.id)).submissions, isEmpty);

    await _tapText(tester, '同じ写真で再試行する');
    await _until(tester, () => _judgementState(tester) == PlayerJudgementDisplayState.success);
    expect(h.photos.calls, 1, reason: '再撮影せずに保持済みの写真を再送する');
    expect((await h.snapshot(room.id)).submissions, hasLength(1));
    expect((await h.snapshot(room.id)).clearsOf('player'), hasLength(1));
    expect(find.text('再送で確認できました'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('判定の不合格は加点せず再撮影へ戻る', (tester) async {
    final h = _FlowHarness(judge: ScriptedPhotoJudge()..enqueueReject('対象が写っていません'));
    addTearDown(h.dispose);
    final room = await h.runningRoom();
    await h.pump(tester, resumeRoomId: room.id);
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    await _openCapture(tester, sampleCourse.requiredCheckpoints.first);
    await _tapText(tester, '撮影する');
    await _until(tester, () => find.byType(PlayerPhotoReviewView).evaluate().isNotEmpty);
    await _tapText(tester, 'この写真で判定する');
    await _until(tester, () => _judgementState(tester) == PlayerJudgementDisplayState.retake);
    expect((await h.snapshot(room.id)).clearsOf('player'), isEmpty);
    expect(find.text('対象が写っていません'), findsOneWidget);
    await _tapText(tester, '撮り直す');
    await _until(tester, () => find.byType(PlayerCaptureView).evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('撮影をキャンセルしても同じお題から撮り直せる', (tester) async {
    final photos = _FakePhotoPicker()..nextPhoto = null;
    final h = _FlowHarness(photos: photos);
    addTearDown(h.dispose);
    final room = await h.runningRoom();
    await h.pump(tester, resumeRoomId: room.id);
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    final checkpoint = sampleCourse.requiredCheckpoints.first;
    await _openCapture(tester, checkpoint);
    await _tapText(tester, '撮影する');
    await tester.pump();
    expect(find.byType(PlayerPhotoReviewView), findsNothing);
    expect(tester.widget<PlayerCaptureView>(find.byType(PlayerCaptureView)).instruction, contains(checkpoint.mission));
    photos.nextPhoto = _photo;
    await _tapText(tester, '撮影する');
    await _until(tester, () => find.byType(PlayerPhotoReviewView).evaluate().isNotEmpty);
    expect(photos.calls, 2);
    expect(tester.takeException(), isNull);
  });

  for (final timeUp in [false, true]) {
    testWidgets('${timeUp ? '時間切れ' : '運営終了'}後に遅い撮影応答が戻っても写真確認へ進まない', (tester) async {
      final capture = Completer<Uint8List?>();
      final photos = _FakePhotoPicker()..pending = capture.future;
      final h = _FlowHarness(photos: photos);
      addTearDown(h.dispose);
      final room = await h.runningRoom();
      await h.pump(tester, resumeRoomId: room.id);
      await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
      await _openCapture(tester, sampleCourse.requiredCheckpoints.first);
      await _tapText(tester, '撮影する');
      expect(photos.calls, 1);
      if (timeUp) {
        h.now = h.now.add(sampleCourse.timeLimit);
        h.ticks.add(h.now);
      } else {
        await h.owner.finishRoom(room.id);
      }
      await _until(tester, () => find.byType(PlayerResultView).evaluate().isNotEmpty);
      capture.complete(_photo);
      await tester.pump();
      await tester.pump();
      expect(find.byType(PlayerPhotoReviewView), findsNothing);
      expect(find.byType(PlayerCaptureView), findsNothing);
      expect(tester.widget<PlayerResultView>(find.byType(PlayerResultView)).isFinal, isTrue);
      expect((await h.snapshot(room.id)).submissions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('運営終了後に遅い判定応答が戻ってもミッションクリアへ戻らない', (tester) async {
    final judge = _DeferredJudge();
    final h = _FlowHarness(judge: judge);
    addTearDown(h.dispose);
    final room = await h.runningRoom();
    await h.pump(tester, resumeRoomId: room.id);
    await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
    await _openCapture(tester, sampleCourse.requiredCheckpoints.first);
    await _tapText(tester, '撮影する');
    await _until(tester, () => find.byType(PlayerPhotoReviewView).evaluate().isNotEmpty);
    await _tapText(tester, 'この写真で判定する');
    await _until(tester, () => _judgementState(tester) == PlayerJudgementDisplayState.processing);
    expect(judge.calls, 1);
    await h.owner.finishRoom(room.id);
    await _until(tester, () => find.byType(PlayerResultView).evaluate().isNotEmpty);

    judge.result.complete(const PhotoVerdict(passed: true, reason: '遅れて届いた合格'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlayerJudgementView), findsNothing);
    expect(tester.widget<PlayerResultView>(find.byType(PlayerResultView)).isFinal, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _completeCheckpoint(WidgetTester tester, Checkpoint checkpoint) async {
  await _openCapture(tester, checkpoint);
  await _tapText(tester, '撮影する');
  await _until(tester, () => find.byType(PlayerPhotoReviewView).evaluate().isNotEmpty);
  await _tapText(tester, 'この写真で判定する');
  await _until(tester, () => _judgementState(tester) == PlayerJudgementDisplayState.success);
  await _tapText(tester, 'マップへ戻る');
  await _until(tester, () => find.byType(PlayerMapView).evaluate().isNotEmpty);
}

Future<void> _openCapture(WidgetTester tester, Checkpoint checkpoint) async {
  await _tapText(tester, 'チェックポイントQRを読み取る');
  await _until(tester, () => find.byType(PlayerQrView).evaluate().isNotEmpty);
  await _scan(tester, checkpoint.qr);
  await _until(tester, () => find.byType(PlayerCaptureView).evaluate().isNotEmpty);
}

Future<void> _scan(WidgetTester tester, String qr) async {
  await _tapText(tester, 'テスト読取:$qr');
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await _until(tester, () {
    final buttons = find.ancestor(
      of: target,
      matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
    );
    return buttons.evaluate().any((element) => (element.widget as ButtonStyleButton).onPressed != null);
  });
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  // 状態を待つ。無限に回る判定スピナーに pumpAndSettle は使わない。
  for (var frame = 0; frame < 100 && !ready(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: '購読した状態が画面へ反映される');
}

PlayerJudgementDisplayState? _judgementState(WidgetTester tester) {
  final view = find.byType(PlayerJudgementView);
  return view.evaluate().isEmpty ? null : tester.widget<PlayerJudgementView>(view).state;
}

class _FlowHarness {
  _FlowHarness({PhotoJudge? judge, _FakePhotoPicker? photos}) : photos = photos ?? _FakePhotoPicker() {
    SharedPreferences.setMockInitialValues({});
    backend = InMemoryMatchBackend(courses: const [sampleCourse], judge: judge, clock: () => now);
    owner = backend.repositoryFor('owner');
    player = backend.repositoryFor('player');
  }

  DateTime now = DateTime.now();
  final ticks = StreamController<DateTime>.broadcast();
  final sessions = SessionStore();
  final _FakePhotoPicker photos;
  late final InMemoryMatchBackend backend;
  late final MatchRepository owner;
  late final MatchRepository player;
  late final ProviderContainer container;

  Future<Room> runningRoom() async {
    final room = await owner.createRoom(courseId: sampleCourse.id);
    await player.joinRoom(roomId: room.id, displayName: '松本');
    await player.scanStart(roomId: room.id, qr: sampleCourse.startQr);
    await owner.startRoom(room.id);
    return room;
  }

  Future<RoomSnapshot> snapshot(String roomId) =>
      Future.value(container.read(roomSnapshotProvider(roomId)).requireValue);

  Future<void> pump(WidgetTester tester, {String? resumeRoomId}) async {
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
          tickerProvider.overrideWith((ref) async* {
            yield now;
            yield* ticks.stream;
          }),
          playerPhotoPickerProvider.overrideWithValue(photos),
          playerQrScannerBuilderProvider.overrideWithValue(
            (context, onCode, enabled) => SingleChildScrollView(
              child: Column(
                children: [
                  for (final qr in [
                    sampleCourse.startQr,
                    ...sampleCourse.checkpoints.map((c) => c.qr),
                    sampleCourse.goalQr,
                  ])
                    TextButton(onPressed: enabled ? () => onCode(qr) : null, child: Text('テスト読取:$qr')),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: PlayerFlowPage(resumeRoomId: resumeRoomId)),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(PlayerFlowPage)), listen: false);
  }

  void dispose() => unawaited(ticks.close());
}

class _FakePhotoPicker implements PlayerPhotoPicker {
  var calls = 0;
  Uint8List? nextPhoto = _photo;
  Future<Uint8List?>? pending;

  @override
  Future<Uint8List?> capturePhoto() {
    calls++;
    return pending ?? Future.value(nextPhoto);
  }
}

class _DeferredJudge implements PhotoJudge {
  final result = Completer<PhotoVerdict>();
  var calls = 0;

  @override
  Future<PhotoVerdict> judge({required Checkpoint checkpoint, required Uint8List photo}) {
    calls++;
    return result.future;
  }
}

// テスト用の PNG。実カメラ・ファイルやプラットフォーム権限へ依存しない。
final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
