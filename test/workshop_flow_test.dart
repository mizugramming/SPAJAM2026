import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/main.dart';

Future<void> tapControl(WidgetTester tester, String id) async {
  final control = find.byKey(ValueKey(id));
  if (control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(control, 160);
  }
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pump();
}

void main() {
  // Medal reaches copper -> silver -> gold. The glyph retains its first-round
  // outline through a whole round without motion, then gains a polished finish.
  for (final (material, strokes, stages, percentages) in [
    ('medal', [5, 10, 20], ['銅メダル', '銀メダル', '金メダル'], [25, 55, 85]),
    ('kanji', [8, 0, 27], ['輪郭の現れた漢', '輪郭の現れた漢', '光沢を帯びた漢'], [40, 40, 81]),
  ]) {
    testWidgets(
      '$material plays three rounds with simulated inputs and retries',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = material == 'kanji'
            ? const Size(320, 580)
            : const Size(393, 852);
        if (material == 'kanji') {
          tester.platformDispatcher.textScaleFactorTestValue = 1.4;
        }
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const WorkshopApp(simulated: true));
        await tester.pumpAndSettle();
        expect(find.text('はじめる'), findsOneWidget);
        await tapControl(tester, 'title-start');
        await tapControl(tester, 'material-$material');

        var total = 0;
        for (var i = 0; i < 3; i++) {
          expect(find.text('${i + 1} 回目 / 全3回'), findsOneWidget);
          await tapControl(tester, 'demo-${[110, 190, 300][i]}');
          await tapControl(tester, 'capture');
          expect(find.text('声を聞いています'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 500));
          final grit = ['粗目', '中目', '細目'][i];
          expect(find.text('$gritのやすり'), findsOneWidget);
          await tester.pump(const Duration(seconds: 12));
          await tapControl(tester, 'start');
          expect(find.text('残り 10 秒'), findsOneWidget);

          for (var n = 0; n < strokes[i]; n++) {
            await tapControl(tester, 'simulate-stroke');
          }
          total += strokes[i];
          await tester.pump(const Duration(seconds: 9));
          expect(find.text('残り 1 秒'), findsOneWidget);
          expect(find.text('$grit   ·   ${strokes[i]} 往復'), findsOneWidget);
          expect(find.text('研磨 ${percentages[i]}%'), findsOneWidget);
          expect(find.text(stages[i]), findsOneWidget);
          await tester.pump(const Duration(seconds: 1));
        }

        expect(find.text('今回の仕上がり'), findsOneWidget);
        expect(find.text(stages.last), findsOneWidget);
        expect(find.text('3回の研磨で、合計$total往復しました。'), findsOneWidget);
        await tapControl(tester, 'retry');
        expect(find.text('磨く素材を選ぶ'), findsOneWidget);
        await tapControl(tester, 'material-$material');
        expect(find.text('1 回目 / 全3回'), findsOneWidget);
        expect(find.text('研磨 0%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('microphone retry and volume fallback keep the chosen material', (
    tester,
  ) async {
    const commands = MethodChannel('polish/device');
    const events = MethodChannel('polish/strokes');
    final messenger = tester.binding.defaultBinaryMessenger;
    var attempts = 0;
    final pulses = <Object?>[];
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(commands, (call) async {
      if (call.method == 'pulse') pulses.add(call.arguments);
      if (call.method != 'capture') return null;
      if (++attempts == 1) throw PlatformException(code: 'permission');
      return <String, num?>{'hz': null, 'level': 0.8};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(commands, null);
      messenger.setMockMethodCallHandler(events, null);
    });

    await tester.pumpWidget(const WorkshopApp(simulated: false));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');
    await tapControl(tester, 'material-medal');
    await tapControl(tester, 'capture');
    expect(find.textContaining('マイクを許可'), findsOneWidget);
    await tapControl(tester, 'capture');
    expect(find.textContaining('高さを読み取れません'), findsOneWidget);
    await tapControl(tester, 'voice-mode');
    await tapControl(tester, 'capture');
    expect(attempts, 3);
    expect(find.text('細目のやすり'), findsOneWidget);
    expect(find.textContaining('音量 80%'), findsOneWidget);
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    Future<void> reportStroke() async {
      await messenger.handlePlatformMessage(
        events.name,
        events.codec.encodeSuccessEnvelope(1),
        null,
      );
      await tester.pump();
    }

    await reportStroke();
    expect(pulses, isEmpty);
    await tapControl(tester, 'start');
    await reportStroke();
    expect(find.text('細目   ·   1 往復'), findsOneWidget);
    expect(find.text('研磨 2%'), findsOneWidget);
    expect(pulses.single, containsPair('amplitude', isPositive));
    expect(pulses.single, containsPair('durationMs', isPositive));
    await tester.pump(const Duration(seconds: 10));
    await reportStroke();
    expect(pulses, hasLength(1));
    expect(find.text('2 回目 / 全3回'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
