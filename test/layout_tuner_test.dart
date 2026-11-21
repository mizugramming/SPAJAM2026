import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/ui/layout_tuner.dart';

void main() {
  tearDown(layoutTuner.reset);

  test(
    'copied file text matches workshop_layout.dart when nothing changed',
    () {
      final file = File('lib/ui/workshop_layout.dart').readAsStringSync();
      expect(layoutTuner.fileText(), file.replaceAll('\r\n', '\n'));
    },
  );

  test('boxes may overflow the screen but keep an edge on it', () {
    final base = layoutTuner.boxOf(Screen.voice, 'action');
    layoutTuner.set(Screen.voice, 'action', base.copyWith(x: .9, y: .5));
    var moved = layoutTuner.boxOf(Screen.voice, 'action');
    expect(moved.x, .9);
    expect(moved.y, .5);

    // Larger than the screen and pushed off it: limited to 3x and a 5% edge.
    layoutTuner.set(
      Screen.voice,
      'action',
      base.copyWith(x: 2, y: -5, w: 4, h: 1.5),
    );
    moved = layoutTuner.boxOf(Screen.voice, 'action');
    expect(moved.w, Box.maxSize);
    expect(moved.h, 1.5);
    expect(moved.x, 1 - Box.keepVisible);
    expect(moved.y, closeTo(Box.keepVisible - 1.5, 1e-9));
    expect(moved.code(), 'Box(.95, -1.45, 3, 1.5)');
    expect(layoutTuner.fileText(), contains("    'action': ${moved.code()},"));
    expect(layoutTuner.changesText(), contains('採音 / action:'));

    layoutTuner.reset(screen: Screen.voice, id: 'action');
    expect(layoutTuner.boxOf(Screen.voice, 'action'), base);
    expect(layoutTuner.hasChanges, isFalse);
  });
}
