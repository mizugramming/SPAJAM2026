import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';
import 'package:polish_workshop/main.dart';
import 'package:polish_workshop/ui/sandpaper.dart';
import 'package:polish_workshop/ui/surface_art.dart';

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
  final paper = find.byType(SandpaperFace);

  Rect visiblePaper(WidgetTester tester) {
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    final rect = tester.getRect(paper).intersect(viewport);
    expect(rect.width, greaterThan(viewport.width * 0.8));
    expect(rect.height, greaterThan(viewport.height * 0.75));
    return rect;
  }

  test('the paper tint and stamp preserve pitch within a single grit', () {
    const first = VoiceSample(180, .55);
    const second = VoiceSample(195, .55);
    expect(classify(first, VoiceMode.pitch), Grit.medium);
    expect(classify(second, VoiceMode.pitch), Grit.medium);
    expect(sandpaperColorFor(first.hz), isNot(sandpaperColorFor(second.hz)));
    expect(sandpaperStampFor(first), '180 Hz');
    expect(sandpaperStampFor(second), '195 Hz');
    expect(sandpaperStampFor(const VoiceSample(null, .80)), contains('80%'));
  });

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
          expect(paper, findsNothing);
          final pitch = [110, 190, 300][i];
          await tapControl(tester, 'demo-$pitch');
          await tapControl(tester, 'capture');
          expect(find.text('声を聞いています'), findsOneWidget);
          expect(paper, findsNothing);
          await tester.pump(const Duration(milliseconds: 500));
          final startTop = tester.getTopLeft(paper).dy;
          await tester.pump(const Duration(milliseconds: 500));
          final readyRect = visiblePaper(tester);
          expect(readyRect.top, lessThan(startTop));
          final readyPaper = tester.widget<SandpaperFace>(paper);
          expect(readyPaper.grit, Grit.values[i]);
          expect(readyPaper.sample.hz, pitch);
          expect(
            find.descendant(of: paper, matching: find.text('$pitch Hz')),
            findsWidgets,
          );
          expect(readyPaper.strokes, total);
          final grit = readyPaper.grit.label;
          expect(find.text('$gritのやすり'), findsOneWidget);
          await tester.pump(const Duration(seconds: 12));
          await tapControl(tester, 'start');
          expect(find.text('残り 10 秒'), findsOneWidget);
          visiblePaper(tester);

          for (var n = 0; n < strokes[i]; n++) {
            await tapControl(tester, 'simulate-stroke');
          }
          total += strokes[i];
          await tester.pump(const Duration(seconds: 9));
          final timer = tester.getRect(find.text('残り 1 秒'));
          final count = tester.getRect(
            find.text('$grit   ·   ${strokes[i]} 往復'),
          );
          expect(count.left, greaterThanOrEqualTo(timer.right));
          expect(count.center.dy, inInclusiveRange(timer.top, timer.bottom));
          expect(find.text('研磨 ${percentages[i]}%'), findsOneWidget);
          expect(find.text(stages[i]), findsOneWidget);
          final surface = tester.widget<SurfaceArt>(find.byType(SurfaceArt));
          expect(surface.strokeCount, total);
          expect(surface.progress * 100, closeTo(percentages[i], 0.5));
          final activePaper = tester.widget<SandpaperFace>(paper);
          expect(activePaper.sample, same(readyPaper.sample));
          expect(activePaper.grit, readyPaper.grit);
          expect(activePaper.strokes, total);
          expect(activePaper.progress, surface.progress);
          if (material == 'medal') {
            final image = ['daou', 'gin', 'kin'][i];
            expect(
              find.descendant(
                of: find.byType(SurfaceArt),
                matching: find.byKey(ValueKey('assets/fonts/$image.jpg')),
              ),
              findsOneWidget,
            );
          }
          await tester.pump(const Duration(seconds: 1));
        }

        expect(find.text('今回の仕上がり'), findsOneWidget);
        expect(paper, findsNothing);
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
    final starts = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(events, (_) async => null);
    messenger.setMockMethodCallHandler(commands, (call) async {
      if (call.method == 'startMotion') {
        starts.add(call.arguments as Map<Object?, Object?>);
      }
      if (call.method == 'pulse') pulses.add(call.arguments);
      if (call.method != 'capture') return null;
      expect(call.arguments, {'desk': true});
      if (++attempts == 1) throw PlatformException(code: 'permission');
      return <String, num?>{'hz': null, 'level': 0.8};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(commands, null);
      messenger.setMockMethodCallHandler(events, null);
    });

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const WorkshopApp(simulated: false));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');
    await tapControl(tester, 'material-medal');
    await tapControl(tester, 'capture');
    expect(find.textContaining('マイクを許可'), findsOneWidget);
    expect(paper, findsNothing);
    await tapControl(tester, 'capture');
    expect(find.textContaining('高さを読み取れません'), findsOneWidget);
    expect(paper, findsNothing);
    await tapControl(tester, 'voice-mode');
    await tapControl(tester, 'capture');
    expect(attempts, 3);
    expect(find.text('細目のやすり'), findsOneWidget);
    visiblePaper(tester); //「視差効果を減らす」設定では最初のフレームで見える。
    SandpaperFace face() => tester.widget<SandpaperFace>(paper);
    expect(face().sample.hz, isNull);
    expect(face().sample.level, .8);
    expect(face().grit, Grit.fine);
    expect(
      find.descendant(of: paper, matching: find.text('音量 80%')),
      findsWidgets,
    );
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    Future<void> reportMotion(int code) async {
      await messenger.handlePlatformMessage(
        events.name,
        events.codec.encodeSuccessEnvelope(code),
        null,
      );
      await tester.pump();
    }

    SurfaceArt surface() => tester.widget<SurfaceArt>(find.byType(SurfaceArt));
    await reportMotion(2);
    await reportMotion(1);
    expect(surface().inContact, isFalse);
    expect(face().inContact, isFalse);
    expect(pulses, isEmpty);
    await tapControl(tester, 'start');
    expect(starts.single, {
      'grit': 'fine',
      'progress': 0.0,
      'durationMs': 29,
      'amplitude': 124,
      'vibrationEnabled': true,
      'remainingMs': 10000,
      'sessionId': isA<int>(),
    });
    await reportMotion(2);
    expect(surface().inContact, isTrue);
    expect(face().inContact, isTrue);
    expect(surface().strokeCount, 0);
    await reportMotion(-1);
    expect(surface().inContact, isFalse);
    expect(face().inContact, isFalse);
    expect(surface().progress, 0);
    expect(pulses, isEmpty);
    await reportMotion(2);
    await reportMotion(1);
    expect(find.text('細目   ·   1 往復'), findsOneWidget);
    expect(find.text('研磨 2%'), findsOneWidget);
    expect(pulses.single, containsPair('amplitude', isPositive));
    expect(pulses.single, containsPair('durationMs', isPositive));
    expect(pulses.single, containsPair('followStroke', true));
    expect(pulses.single, containsPair('progress', surface().progress));
    expect(face().progress, surface().progress);
    expect(
      pulses.single,
      containsPair('sessionId', starts.single['sessionId']),
    );
    await tester.pump(const Duration(milliseconds: 750));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await reportMotion(2);
    await reportMotion(1);
    expect(pulses, hasLength(1));
    await tester.pump(const Duration(seconds: 3));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(surface().inContact, isFalse);
    expect(surface().strokeCount, 1);
    expect(face().inContact, isFalse);
    expect(face().strokes, 1);
    expect(starts, hasLength(2));
    expect(starts.last, containsPair('progress', surface().progress));
    expect(starts.last, containsPair('remainingMs', 9250));
    expect(starts.last['sessionId'], isNot(starts.first['sessionId']));
    await tester.pump(const Duration(seconds: 10));
    await reportMotion(2);
    await reportMotion(1);
    expect(surface().inContact, isFalse);
    expect(pulses, hasLength(1));
    expect(find.text('2 回目 / 全3回'), findsOneWidget);
    expect(paper, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
