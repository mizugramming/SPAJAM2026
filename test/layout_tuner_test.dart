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

  test('moved boxes stay on screen, are copied, and can be reset', () {
    final base = layoutTuner.boxOf(Screen.voice, 'action');
    layoutTuner.set(Screen.voice, 'action', base.copyWith(x: .9, y: .5));
    final moved = layoutTuner.boxOf(Screen.voice, 'action');
    expect(moved.x, closeTo(1 - base.w, 1e-9));
    expect(moved.y, .5);
    expect(
      layoutTuner.fileText(),
      contains("    'action': Box(.112, .5, .888, .065),"),
    );
    expect(layoutTuner.changesText(), contains('採音 / action:'));

    layoutTuner.reset(screen: Screen.voice, id: 'action');
    expect(layoutTuner.boxOf(Screen.voice, 'action'), base);
    expect(layoutTuner.hasChanges, isFalse);
  });
}
