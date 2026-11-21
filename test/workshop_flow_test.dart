import 'dart:ui' show SemanticsAction;

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
  final surfaceArt = find.byType(SurfaceArt);
  final departure = find.byKey(const ValueKey('voice-departure'));
  final startButton = find.byKey(const ValueKey('start'));
  final startAction = find.semantics.byPredicate(
    (node) =>
        node.label.contains('磨き始める') &&
        node.getSemanticsData().hasAction(SemanticsAction.tap),
  );

  Rect viewportOf(WidgetTester tester) =>
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  // Flutter's image decoder runs on the real clock, outside the test timer.
  Future<void> decodeVisibleMedal(WidgetTester tester) async {
    final images = find.descendant(
      of: surfaceArt,
      matching: find.byType(Image),
    );
    if (images.evaluate().isEmpty) return;
    final image = tester.widget<Image>(images.last);
    final context = tester.element(images.last);
    await tester.runAsync(() => precacheImage(image.image, context));
    await tester.pump();
  }

  Rect upperMaterial(WidgetTester tester) {
    final material = tester.widget<SurfaceArt>(surfaceArt).material;
    final face = find
        .descendant(
          of: surfaceArt,
          matching: material.glyph == null
              ? find.byType(Image)
              : find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.foregroundPainter != null,
                ),
        )
        .first;
    final rect = tester.getRect(face);
    final viewport = viewportOf(tester);
    expect(rect.intersect(viewport), rect);
    expect(rect.shortestSide, greaterThan(viewport.width * .60));
    expect(rect.bottom, lessThan(viewport.height * .69));
    return rect;
  }

  Rect visiblePaper(WidgetTester tester) {
    final viewport = viewportOf(tester);
    final rect = tester.getRect(paper).intersect(viewport);
    expect(rect.width, greaterThan(viewport.width * 0.8));
    expect(rect.top / viewport.height, inInclusiveRange(.65, .73));
    expect(rect.height / viewport.height, inInclusiveRange(.25, .33));
    expect(rect.top, greaterThanOrEqualTo(upperMaterial(tester).bottom));
    return rect;
  }

  void expectOutsideScreen(WidgetTester tester, Finder item) {
    if (item.evaluate().isNotEmpty) {
      expect(tester.getRect(item).overlaps(viewportOf(tester)), isFalse);
    }
  }

  Future<void> checkToolHandoff(WidgetTester tester, Rect captureRect) async {
    final material = upperMaterial(tester);
    final viewport = viewportOf(tester);
    expect(tester.getRect(departure), rectMoreOrLessEquals(captureRect));
    expect(
      find.descendant(of: departure, matching: find.text('採音完了')),
      findsOneWidget,
    );
    final departureFace = find.descendant(
      of: departure,
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(departureFace).color,
      Theme.of(tester.element(departure)).colorScheme.primary,
    );
    expectOutsideScreen(tester, paper);
    expect(startAction, findsNothing);

    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.getTopLeft(departure).dy, lessThan(captureRect.top));
    expectOutsideScreen(tester, paper);
    expect(upperMaterial(tester), material);

    await tester.pump(const Duration(milliseconds: 110)); // 200 ms: pause.
    expect(departure, findsNothing);
    expectOutsideScreen(tester, paper);
    expect(startAction, findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    if (paper.evaluate().isNotEmpty) {
      expect(tester.getBottomLeft(paper).dy, lessThanOrEqualTo(viewport.top));
    }

    await tester.pump(const Duration(milliseconds: 110)); // 330 ms: falling.
    final earlyTop = tester.getTopLeft(paper).dy;
    expect(upperMaterial(tester), material);
    await tester.pump(
      const Duration(milliseconds: 170),
    ); // 500 ms: approaching.
    final lateTop = tester.getTopLeft(paper).dy;
    expect(lateTop, greaterThan(earlyTop));
    expect(startAction, findsNothing);
    expect(startButton, findsNothing);
    await tester.tapAt(Offset(viewport.center.dx, viewport.height * .92));
    await tester.pump(const Duration(milliseconds: 99)); // 599 ms.
    expect(find.text('残り 10 秒'), findsNothing);
    expect(startButton, findsNothing);
    expect(startAction, findsNothing);
    expect(upperMaterial(tester), material);

    await tester.pump(const Duration(milliseconds: 1)); // Landed at 600 ms.
    final landed = visiblePaper(tester);
    expect(earlyTop, lessThan(landed.top));
    expect(upperMaterial(tester), material);
    expect(startAction, findsOne);
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
          final captureRect = tester.getRect(
            find.byKey(const ValueKey('capture')),
          );
          await tapControl(tester, 'capture');
          expect(find.text('声を聞いています'), findsOneWidget);
          expect(departure, findsNothing);
          expect(paper, findsNothing);
          await tester.pump(const Duration(milliseconds: 500));
          await decodeVisibleMedal(tester);
          await checkToolHandoff(tester, captureRect);
          final readyPaper = tester.widget<SandpaperFace>(paper);
          expect(readyPaper.grit, Grit.values[i]);
          expect(readyPaper.sample.hz, pitch);
          expect(
            find.descendant(of: paper, matching: find.text('$pitch Hz')),
            findsNWidgets(3),
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
          await decodeVisibleMedal(tester);
          final activePaper = tester.widget<SandpaperFace>(paper);
          visiblePaper(tester);
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

  testWidgets('leaving during the falling sheet clears the unfinished round', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkshopApp(simulated: true));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');
    await tapControl(tester, 'material-kanji');
    await tapControl(tester, 'capture');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 340));
    expect(startAction, findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('素材選びに戻る'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('磨く素材を選ぶ'), findsOneWidget);
    expect(departure, findsNothing);
    expect(paper, findsNothing);
    expect(startAction, findsNothing);
    await tapControl(tester, 'material-kanji');
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    expect(find.text('研磨 0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await decodeVisibleMedal(tester);
    await tapControl(tester, 'capture');
    expect(find.textContaining('マイクを許可'), findsOneWidget);
    expect(departure, findsNothing);
    expect(paper, findsNothing);
    await tapControl(tester, 'capture');
    expect(find.textContaining('高さを読み取れません'), findsOneWidget);
    expect(departure, findsNothing);
    expect(paper, findsNothing);
    await tapControl(tester, 'voice-mode');
    await tapControl(tester, 'capture');
    expect(attempts, 3);
    expect(find.text('細目のやすり'), findsOneWidget);
    visiblePaper(tester); //「視差効果を減らす」設定では最初のフレームで見える。
    expectOutsideScreen(tester, departure);
    expect(startAction, findsOne);
    SandpaperFace face() => tester.widget<SandpaperFace>(paper);
    expect(face().sample.hz, isNull);
    expect(face().sample.level, .8);
    expect(face().grit, Grit.fine);
    expect(
      find.descendant(of: paper, matching: find.text('音量 80%')),
      findsNWidgets(3),
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
