import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/demo/parent_character.dart';

// Run this real-asset codec check in the native Flutter test runner. Chrome's
// widget-test engine does not implement flutter/assets; browser behavior is
// covered separately in parent_character_test.dart.
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
}
