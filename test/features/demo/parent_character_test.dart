import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/demo/parent_character.dart';

String assetOf(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

Widget scene({bool idle = true, bool enabled = true, bool reduced = false}) =>
    CharacterPlaybackScope(
      enabled: enabled,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Center(
            child: SizedBox(
              width: 177,
              height: 177 / ParentCharacter.aspectRatio,
              child: ParentCharacter(idle: idle),
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同梱素材は透過アニメーションで、静止画と寸法が一致する', () async {
    final movie = await rootBundle.load(parentIdleAsset);
    final poster = await rootBundle.load(parentIdlePosterAsset);
    final codec = await ui.instantiateImageCodec(movie.buffer.asUint8List());
    final still = await ui.instantiateImageCodec(poster.buffer.asUint8List());
    addTearDown(codec.dispose);
    addTearDown(still.dispose);
    expect(codec.frameCount, greaterThan(1));
    expect(codec.repetitionCount, -1);
    final first = await codec.getNextFrame();
    final next = await codec.getNextFrame();
    final rest = await still.getNextFrame();
    addTearDown(first.image.dispose);
    addTearDown(next.image.dispose);
    addTearDown(rest.image.dispose);
    expect(first.duration.inMilliseconds, greaterThan(0));
    expect(first.image.width / first.image.height, ParentCharacter.aspectRatio);
    expect(rest.image.width, first.image.width);
    expect(rest.image.height, first.image.height);
    final pixels = await first.image.toByteData();
    expect(pixels!.getUint8(3), 0, reason: '動画の四隅に白い背景を残さない');
  });

  testWidgets('待機時だけ再生し、静止画へ戻っても足元の表示枠を維持する', (tester) async {
    await tester.pumpWidget(scene());
    expect(assetOf(tester), parentIdleAsset);
    final rect = tester.getRect(find.byType(Image));
    await tester.pumpWidget(scene(idle: false));
    expect(assetOf(tester), parentIdlePosterAsset);
    expect(tester.getRect(find.byType(Image)), rect);
    await tester.pumpWidget(scene(reduced: true));
    expect(assetOf(tester), parentIdlePosterAsset);
    await tester.pumpWidget(scene(enabled: false));
    expect(assetOf(tester), parentIdlePosterAsset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('アプリを離れたら停止し、戻ると待機動画を再開する', (tester) async {
    await tester.pumpWidget(scene());
    expect(assetOf(tester), parentIdleAsset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(assetOf(tester), parentIdlePosterAsset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(assetOf(tester), parentIdlePosterAsset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(assetOf(tester), parentIdleAsset);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
