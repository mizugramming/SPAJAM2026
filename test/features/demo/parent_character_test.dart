import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    expect(assetOf(tester), kIsWeb ? parentIdleAsset : parentIdlePosterAsset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    // Hidden/paused disable normal frames. Force only the inspection frame so
    // the assertion observes this update, not the last visible frame.
    tester.binding.scheduleForcedFrame();
    await tester.pump();
    expect(assetOf(tester), parentIdlePosterAsset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.scheduleForcedFrame();
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
