import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/factory_backdrop.dart';

const _preview = Key('conveyor-preview');

Future<int> _paintFingerprint(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_preview),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return data.buffer.asUint8List().fold<int>(
        17,
        (hash, pixel) => ((hash * 37) ^ pixel) & 0x7fffffff,
      );
    } finally {
      image.dispose();
    }
  }))!;
}

Widget _platform(int scene, {bool reduceMotion = false, VoidCallback? onTap}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(
          body: FactoryBackdrop(
            transitionKey: scene,
            child: Center(
              child: RepaintBoundary(
                key: _preview,
                child: SizedBox(
                  width: 300,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (onTap != null)
                        GestureDetector(
                          key: const Key('behind-conveyor'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onTap,
                        ),
                      const ConveyorPlatform(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _loadBelt(WidgetTester tester) async {
  await tester.runAsync(
    () => precacheImage(
      const AssetImage(conveyorBeltAsset),
      tester.element(find.byType(ConveyorPlatform)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final setting in [
    (width: 320.0, height: 640.0, scale: 2.0),
    (width: 412.0, height: 900.0, scale: 1.0),
  ]) {
    testWidgets('コンベア原本の比率と缶の接地を保ち、画面幅を越えない（${setting.width}）', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(setting.width, setting.height);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(setting.scale)),
            child: const Scaffold(
              body: FactoryBackdrop(
                transitionKey: AppPhase.profile,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: CanStage(
                    phase: AppPhase.profile,
                    profile: Profile(
                      nickname: 'つな工場',
                      hobby: '写真',
                      comment: 'よろしく',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _loadBelt(tester);
      final imageFinder = find.byKey(const Key('conveyor-belt-image'));
      final belt = tester.getRect(imageFinder);
      final can = tester.getRect(find.byType(TunaCan));
      final stage = tester.getRect(find.byType(CanStage));
      final decoded = tester.renderObject<RenderImage>(imageFinder).image!;
      expect(decoded.width, 2172);
      expect(decoded.height, 724);
      expect(belt.width / belt.height, closeTo(3, .001));
      expect(belt.center.dx, closeTo(can.center.dx, .1));
      expect(can.bottom, closeTo(belt.top + belt.height * .44, .1));
      expect(stage.inflate(.1).contains(belt.topLeft), isTrue);
      expect(stage.inflate(.1).contains(belt.bottomRight), isTrue);
      expect(belt.left, greaterThanOrEqualTo(0));
      expect(belt.right, lessThanOrEqualTo(setting.width));
      final label = find.byKey(const Key('can-nickname'));
      expect(tester.getRect(label).bottom, lessThan(can.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('場面切替で車輪だけ一度動き、入力中の再描画では動き直さない', (tester) async {
    await tester.pumpWidget(_platform(0));
    await _loadBelt(tester);
    final still = await _paintFingerprint(tester);
    await tester.pumpWidget(_platform(1));
    await tester.pump(const Duration(milliseconds: 350));
    final moving = await _paintFingerprint(tester);
    expect(moving, isNot(still));
    await tester.pump(const Duration(milliseconds: 800));
    expect(await _paintFingerprint(tester), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_platform(1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(await _paintFingerprint(tester), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(_platform(2));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('動作軽減では静止し、背景画像が背後の操作を奪わない', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _platform(0, reduceMotion: true, onTap: () => taps++),
    );
    await _loadBelt(tester);
    final still = await _paintFingerprint(tester);
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('conveyor-belt-image'))),
    );
    expect(taps, 1);
    await tester.pumpWidget(
      _platform(1, reduceMotion: true, onTap: () => taps++),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(await _paintFingerprint(tester), still);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
