import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/device/diagnostics.dart';
import 'package:polish_workshop/device/workshop_device.dart';
import 'package:polish_workshop/game/game.dart';

void main() {
  testWidgets(
    'four diagnostic trials count sensor events independently from motor commands',
    (tester) async {
      const commands = MethodChannel('polish/device');
      const events = MethodChannel('polish/strokes');
      final messenger = tester.binding.defaultBinaryMessenger;
      final pulses = <Object?>[];
      var starts = 0;
      var stops = 0;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(commands, (call) async {
        switch (call.method) {
          case 'pulse':
            pulses.add(call.arguments);
          case 'startMotion':
            starts++;
          case 'stopMotion':
            stops++;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
      });

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 930);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosticsPage(device: WorkshopDevice(simulated: false)),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
      }

      Future<void> sensorEvent() async {
        await messenger.handlePlatformMessage(
          events.name,
          events.codec.encodeSuccessEnvelope(1),
          null,
        );
        await tester.pump();
      }

      final history = <String>[];
      for (final (label, motor, movements, progress) in [
        ('① 静止', false, 0, 0.1),
        ('② 振動のみ', true, 0, 0.1),
        ('③ 手で往復', false, 3, 0.1),
        ('④ 往復＋振動', true, 3, 0.9),
      ]) {
        await tap(label);
        await tap(progress == 0.1 ? '前半 10%' : '後半 90%');
        pulses.clear();
        await tap('計測を開始');
        expect(starts, history.length + 1);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('0 往復　／　残り 8 秒'), findsOneWidget);
        expect(pulses, motor ? isNotEmpty : isEmpty);

        for (var n = 0; n < movements; n++) {
          await sensorEvent();
        }
        expect(find.text('$movements 往復　／　残り 8 秒'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
        expect(stops, starts);
        if (motor) {
          final expected = pulseFor(Grit.medium, progress);
          expect(pulses.length, greaterThan(1));
          expect(
            pulses,
            everyElement({
              'amplitude': expected.amplitude,
              'durationMs': expected.durationMs,
            }),
          );
        } else {
          expect(pulses, isEmpty);
        }
        history.add(
          '$label　$movements往復・振動指令${pulses.length}回\n中目／進捗${(progress * 100).round()}%',
        );
        final pulseCount = pulses.length;
        await sensorEvent();
        await tester.pump(const Duration(seconds: 1));
        expect(pulses, hasLength(pulseCount));
        expect(find.text('$movements 往復　／　10秒計測'), findsOneWidget);
      }

      for (final result in history.reversed) {
        final row = find.text(result);
        await tester.scrollUntilVisible(row, 110);
        expect(row, findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
