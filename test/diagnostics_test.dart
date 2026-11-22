import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/device/diagnostics.dart';
import 'package:polish_workshop/device/workshop_device.dart';
import 'package:polish_workshop/game/game.dart';

void main() {
  testWidgets('changing voice range reclassifies the same diagnostic sample', (
    tester,
  ) async {
    final changed = <VoiceProfile>[];
    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticsPage(
          device: WorkshopDevice(simulated: true),
          onProfileChanged: changed.add,
        ),
      ),
    );
    Future<void> press(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    await press('声を取る');
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('高さ 120.0 Hz'), findsOneWidget);
    expect(find.text('やすり 中目'), findsOneWidget);
    await press('声が高い人');
    expect(changed, [VoiceProfile.high]);
    expect(find.text('高さ 120.0 Hz'), findsOneWidget);
    expect(find.text('やすり 粗目'), findsOneWidget);
    await press('声を取る');
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('高さ 240.0 Hz'), findsOneWidget);
    expect(find.text('やすり 中目'), findsOneWidget);
    await press('声が低い人');
    expect(find.text('やすり 細目'), findsOneWidget);
    expect(find.textContaining('音量'), findsNothing);
  });

  testWidgets(
    'an unstable pitch can be retried and never selects a grit by loudness',
    (tester) async {
      const commands = MethodChannel('polish/device');
      const events = MethodChannel('polish/strokes');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      var captures = 0;
      messenger.setMockMethodCallHandler(commands, (call) async {
        if (call.method == 'capture') {
          return ++captures == 1 ? {'hz': null, 'level': .99} : {'hz': 120};
        }
        if (call.method == 'startMotion') {
          throw PlatformException(code: 'sensor');
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(500, 1300);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: DiagnosticsPage(device: WorkshopDevice(simulated: false)),
        ),
      );
      Future<void> press(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await press('声を取る');
      final pitchWarning = find.text('声の高さを判定できませんでした。');
      final motionError = find.text('動きを計測できませんでした。');
      expect(pitchWarning, findsOneWidget);
      expect(find.text('やすり —'), findsOneWidget);
      await press('計測を開始');
      expect(motionError, findsOneWidget);
      expect(find.textContaining('音量'), findsNothing);
      await press('声を取る');
      expect(find.text('やすり 中目'), findsOneWidget);
      expect(pitchWarning, findsNothing);
    },
  );

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
          case 'hasAmplitudeControl':
            return false;
          case 'pulse':
            pulses.add(call.arguments);
          case 'startMotion':
            expect(call.arguments, {'deskTrial': true});
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

      Future<void> sensorEvent([int code = 1]) async {
        await messenger.handlePlatformMessage(
          events.name,
          events.codec.encodeSuccessEnvelope(code),
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
        if (motor) {
          expect(find.textContaining('端末の既定の強さ'), findsOneWidget);
        }
        pulses.clear();
        await tap('計測を開始');
        expect(starts, history.length + 1);
        await tester.pump(const Duration(seconds: 2));
        await sensorEvent(2);
        await sensorEvent(-1);
        expect(find.text('0 往復'), findsOneWidget);
        expect(find.text('残り 8 秒'), findsOneWidget);
        expect(pulses, motor ? isNotEmpty : isEmpty);

        final times = <String>[];
        for (var n = 0; n < movements; n++) {
          await tester.pump(const Duration(milliseconds: 250));
          await sensorEvent();
          times.add((2 + (n + 1) * 0.25).toStringAsFixed(3));
        }
        expect(find.text('$movements 往復'), findsOneWidget);
        expect(find.text('残り 8 秒'), findsOneWidget);
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
          '$label\n$movements往復\n振動指令${pulses.length}回\n中目／進捗${(progress * 100).round()}%\n'
          '往復受付（秒）　${times.isEmpty ? '—' : times.join('、')}',
        );
        final pulseCount = pulses.length;
        await sensorEvent();
        await tester.pump(const Duration(seconds: 1));
        expect(pulses, hasLength(pulseCount));
        expect(find.text('$movements 往復'), findsOneWidget);
        expect(find.text('10秒計測'), findsOneWidget);
      }

      for (final result in history.reversed) {
        final row = find.bySemanticsLabel(result);
        await tester.scrollUntilVisible(row, 110);
        expect(row, findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
