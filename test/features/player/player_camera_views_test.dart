import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mayoi_quest/features/player/player_capture_view.dart';
import 'package:mayoi_quest/features/player/player_judgement_view.dart';
import 'package:mayoi_quest/features/player/player_qr_view.dart';

Widget _host(Widget child, {double textScale = 1}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
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
  testWidgets('photo zoom is view-only and submission disables photo operations', (tester) async {
    final pending = Completer<void>();
    var submits = 0;
    var retakes = 0;
    const photo = Center(child: Text('元の写真'));
    await tester.pumpWidget(
      _host(
        PlayerPhotoReviewView(
          photo: photo,
          onSubmit: () {
            submits++;
            return pending.future;
          },
          onRetake: () => retakes++,
        ),
      ),
    );
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    await _tap(tester, '拡大する');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
    expect(viewer.transformationController!.value.entry(0, 3), lessThan(0));
    await _tap(tester, '拡大する');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 4);
    await _tap(tester, '拡大する');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 4);
    await _tap(tester, '縮小する');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
    await _tap(tester, '全体表示');
    expect(viewer.transformationController!.value.isIdentity(), isTrue);
    await _tap(tester, 'この写真で判定する');
    await _tap(tester, '送信中…');
    await _tap(tester, '撮り直す');
    await _tap(tester, '拡大する');
    final sendingViewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(sendingViewer.panEnabled, isFalse);
    expect(sendingViewer.scaleEnabled, isFalse);
    expect(viewer.transformationController!.value.isIdentity(), isTrue);
    expect(submits, 1);
    expect(retakes, 0);
    pending.completeError(StateError('test failure'));
    await tester.pump();
    expect(find.byWidget(photo), findsOneWidget);
    expect(find.text('写真を送信できませんでした。もう一度お試しください。'), findsOneWidget);
    await _tap(tester, '拡大する');
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 2);
    await _tap(tester, '撮り直す');
    expect(retakes, 1);
    expect(viewer.transformationController!.value.isIdentity(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a keyed replacement photo ignores the previous submission result', (tester) async {
    final first = Completer<void>();
    final second = Completer<void>();
    Widget review(String id, Future<void> Function() submit) => _host(
      PlayerPhotoReviewView(
        photo: Text('写真$id', key: ValueKey(id)),
        onSubmit: submit,
        onRetake: () {},
      ),
    );
    await tester.pumpWidget(review('1', () => first.future));
    await _tap(tester, '拡大する');
    await _tap(tester, 'この写真で判定する');
    await tester.pumpWidget(review('2', () => second.future));
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.isIdentity(), isTrue);
    expect(find.text('送信中…'), findsOneWidget);
    first.completeError(StateError('old request'));
    await tester.pump();
    expect(find.text('写真を送信できませんでした。もう一度お試しください。'), findsNothing);
    expect(find.text('この写真で判定する'), findsOneWidget);
    expect(find.text('写真2'), findsOneWidget);
    await _tap(tester, 'この写真で判定する');
    second.complete();
    await tester.pump();
    expect(find.text('この写真で判定する'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture distinguishes unavailable camera and permits recovery', (tester) async {
    var attempts = 0;
    Widget camera(bool ready) => _host(
      PlayerCaptureView(
        preview: const ColoredBox(color: Colors.black),
        instruction: '館内の赤い看板を撮影',
        cameraReady: ready,
        errorMessage: ready ? null : 'カメラの権限を確認してください。',
        onCapture: () async {
          attempts++;
          if (attempts == 1) throw StateError('capture failure');
        },
      ),
    );
    await tester.pumpWidget(camera(false));
    expect(find.text('カメラを利用できません。表示された案内を確認してください。'), findsOneWidget);
    await _tap(tester, '撮影する');
    expect(attempts, 0);
    await tester.pumpWidget(camera(true));
    await _tap(tester, '撮影する');
    expect(find.text('撮影できませんでした。もう一度お試しください。'), findsOneWidget);
    expect(find.text('館内の赤い看板を撮影'), findsOneWidget);
    await _tap(tester, '撮影する');
    expect(attempts, 2);
    expect(find.text('撮影できませんでした。もう一度お試しください。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new capture instruction and disposal ignore late errors', (tester) async {
    final first = Completer<void>();
    final second = Completer<void>();
    Widget camera(String instruction, Future<void> Function() capture) => _host(
      PlayerCaptureView(preview: const SizedBox(), instruction: instruction, cameraReady: true, onCapture: capture),
    );
    await tester.pumpWidget(camera('最初のお題', () => first.future));
    await _tap(tester, '撮影する');
    await tester.pumpWidget(camera('次のお題', () => second.future));
    expect(find.text('撮影中…'), findsOneWidget);
    first.completeError(StateError('old capture'));
    await tester.pump();
    expect(find.text('撮影する'), findsOneWidget);
    expect(find.text('撮影できませんでした。もう一度お試しください。'), findsNothing);
    await _tap(tester, '撮影する');
    await tester.pumpWidget(_host(const SizedBox()));
    second.completeError(StateError('disposed capture'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR processing removes scanner actions from accessibility', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      Widget qr(bool processing) => _host(
        PlayerQrView(
          title: 'チェックポイントQR',
          instruction: 'チェックポイントにあるQRを読み取ってください。',
          scanner: TextButton(onPressed: () {}, child: const Text('QRを読む')),
          feedback: '別のルームのQRです。',
          isProcessing: processing,
          onRetry: () {},
        ),
      );
      await tester.pumpWidget(qr(false));
      expect(find.semantics.byLabel('QRを読む'), findsOneWidget);
      await tester.pumpWidget(qr(true));
      expect(find.semantics.byLabel('QRを読む'), findsNothing);
      expect(find.text('確認が終わるまで次の読み取りをお待ちください。'), findsOneWidget);
      await tester.ensureVisible(find.text('別のルームのQRです。'));
      await tester.pump();
      expect(
        find.semantics.byLabel('別のルームのQRです。').evaluate().single,
        matchesSemantics(label: '別のルームのQRです。', isLiveRegion: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('judgement preserves shared labels and explains disabled action', (tester) async {
    var continues = 0;
    Widget result({VoidCallback? onContinue}) => _host(
      PlayerJudgementView(
        state: PlayerJudgementDisplayState.success,
        message: '指定ポイントを達成しました。',
        awardedScoreLabel: '共通集計による獲得点：50',
        continueLabel: '次の地点を探す',
        onContinue: onContinue,
      ),
    );
    await tester.pumpWidget(result());
    expect(find.text('次の操作の準備ができるまでお待ちください。'), findsOneWidget);
    await _tap(tester, '次の地点を探す');
    expect(continues, 0);
    await tester.pumpWidget(result(onContinue: () => continues++));
    expect(find.text('指定ポイントを達成しました。'), findsOneWidget);
    expect(find.text('共通集計による獲得点：50'), findsOneWidget);
    await _tap(tester, '次の地点を探す');
    expect(continues, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text on a short screen keeps camera actions reachable', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var captures = 0;
    var retakes = 0;
    await tester.pumpWidget(
      _host(
        PlayerCaptureView(
          preview: const SizedBox(),
          instruction: '館内にある対象物の全体が写るように撮影してください。',
          cameraReady: true,
          onCapture: () async {
            captures++;
          },
        ),
        textScale: 2,
      ),
    );
    await _tap(tester, '撮影する');
    expect(captures, 1);
    await tester.pumpWidget(
      _host(
        PlayerPhotoReviewView(photo: const SizedBox(), onSubmit: () async {}, onRetake: () => retakes++),
        textScale: 2,
      ),
    );
    await _tap(tester, '拡大する');
    await _tap(tester, '全体表示');
    await _tap(tester, '撮り直す');
    expect(retakes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('judgement states remain usable with large text and long shared labels', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var retakes = 0;
    var retries = 0;
    const reason = '対象の文字が写真の外に出ています。案内板全体がはっきり写るように、少し離れて撮り直してください。';
    for (final state in PlayerJudgementDisplayState.values) {
      await tester.pumpWidget(
        _host(
          PlayerJudgementView(
            state: state,
            message: reason,
            awardedScoreLabel: '共通集計による獲得点：指定ポイント達成 50ポイント',
            onContinue: () {},
            onRetake: () => retakes++,
            onRetry: () => retries++,
          ),
          textScale: 2,
        ),
      );
      expect(find.text(reason), findsOneWidget);
      if (state == PlayerJudgementDisplayState.retake) {
        await _tap(tester, '撮り直す');
      } else if (state == PlayerJudgementDisplayState.error) {
        await _tap(tester, '同じ写真で再試行する');
      } else if (state == PlayerJudgementDisplayState.success) {
        await _tap(tester, 'マップへ戻る');
      }
      expect(tester.takeException(), isNull);
    }
    expect(retakes, 1);
    expect(retries, 1);
  });

  testWidgets('a long mission scrolls with photo review on a short screen', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final instruction = List.filled(8, '案内板の全体とフロア名が読めるように撮影してください。').join();
    var submits = 0;
    await tester.pumpWidget(
      _host(
        PlayerPhotoReviewView(
          photo: const SizedBox(),
          instruction: instruction,
          onSubmit: () async {
            submits++;
          },
          onRetake: () {},
        ),
        textScale: 2,
      ),
    );
    expect(find.text('撮影するもの：$instruction'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'この写真で判定する');
    expect(submits, 1);
    expect(tester.takeException(), isNull);
  });
}
