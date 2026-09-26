import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/data/demo_controller.dart';

void main() {
  testWidgets(
    'starts with an empty can and an explicit one-device demo label',
    (tester) async {
      final controller = DemoController(autoTick: false);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TsunagunApp(animateCharacters: false, controller: controller),
      );
      await tester.pumpAndSettle();
      expect(find.text('はだ缶'), findsOneWidget);
      expect(find.text('1台用 DEMO'), findsOneWidget);
      expect(find.byKey(const Key('create-room')), findsOneWidget);
      expect(controller.profileDraft.nickname, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
