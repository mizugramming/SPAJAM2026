import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';
import 'package:polish_workshop/main.dart';
import 'package:polish_workshop/ui/medal_flight.dart';
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

const _headings = {'medal': 'メダルを磨く', 'kanji': '漢字を磨く'};
const _order = ['medal', 'kanji'];
const _pager = ValueKey('material-pager');

/// 回転式の素材選択を1つ分回す（左へドラッグで次の素材）。
Future<void> turnCarousel(WidgetTester tester, {bool left = true}) async {
  await tester.timedDrag(
    find.byKey(_pager),
    Offset(left ? -150 : 150, 0),
    const Duration(milliseconds: 500),
  );
  await tester.pumpAndSettle();
}

/// 素材選択で目的の素材まで回し、「これを磨く」で確定する。
Future<void> chooseMaterial(
  WidgetTester tester,
  String id, {
  bool waitForVoice = true,
}) async {
  for (var i = 0; i < _order.length; i++) {
    if (find.text(_headings[id]!).evaluate().isNotEmpty) break;
    await turnCarousel(tester);
  }
  expect(find.text(_headings[id]!), findsOneWidget);
  await tapControl(tester, 'confirm-material');
  if (waitForVoice) await tester.pumpAndSettle();
}

/// 研磨画面の素材の研磨率。
class SurfaceArtProbe {
  static double progress(WidgetTester tester) =>
      tester.widget<SurfaceArt>(find.byType(SurfaceArt)).progress;
}

void main() {
  final paper = find.byType(SandpaperFace);
  final roundIntro = find.byKey(const ValueKey('round-intro'));
  final mic = find.byKey(const ValueKey('capture'));
  final surfaceArt = find.byType(SurfaceArt);
  final departure = find.byKey(const ValueKey('voice-departure'));
  final startButton = find.byKey(const ValueKey('start'));
  final startAction = find.semantics.byPredicate(
    (node) =>
        node.label.contains('磨く！') &&
        node.getSemanticsData().hasAction(SemanticsAction.tap),
  );

  Rect viewportOf(WidgetTester tester) =>
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

  // Flutter's image decoder runs on the real clock, outside the test timer.
  Future<void> decodeVisibleSurface(WidgetTester tester) async {
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

  void expectKanjiArt(WidgetTester tester, double progress) {
    final surface = find.byType(SurfaceArt);
    const dull = 'assets/images/kanji-silver.png';
    const polished = 'assets/images/kanji-silver-polished-aligned.png';
    expect(
      find.descendant(of: surface, matching: find.byKey(const ValueKey(dull))),
      findsOneWidget,
    );
    final shine = find.ancestor(
      of: find.byKey(const ValueKey(polished)),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(shine).opacity, closeTo(progress, 1e-9));
  }

  Rect upperMaterial(WidgetTester tester) {
    final face = find
        .descendant(of: surfaceArt, matching: find.byType(Image))
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

  BoxDecoration microphoneFace(WidgetTester tester, Finder button) {
    final circles = find.descendant(
      of: button,
      matching: find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    return tester.widget<AnimatedContainer>(circles).decoration!
        as BoxDecoration;
  }

  Future<void> finishHandoff(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1801));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.text('残り 10 秒'), findsOneWidget);
  }

  Future<void> checkToolHandoff(
    WidgetTester tester,
    Rect captureRect,
    BoxDecoration captureFace,
    int pitch,
    Grit grit,
  ) async {
    final material = upperMaterial(tester);
    final viewport = viewportOf(tester);
    expect(tester.getRect(departure), rectMoreOrLessEquals(captureRect));
    expect(microphoneFace(tester, departure), captureFace);
    expectOutsideScreen(tester, paper);
    expect(startAction, findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    expect(
      tester.getRect(departure).center,
      offsetMoreOrLessEquals(viewport.center),
    );
    final reading = find.byKey(const ValueKey('voice-reading'));
    expect(tester.widget<Text>(reading).data, '$pitch Hz');
    expect(find.text('${grit.label}のやすり'), findsOneWidget);
    expectOutsideScreen(tester, paper);
    expect(upperMaterial(tester), material);

    await tester.pump(const Duration(milliseconds: 700));
    expect(
      tester.getRect(departure).center,
      offsetMoreOrLessEquals(viewport.center),
    );
    expect(reading, findsOneWidget);
    expect(startButton, findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getRect(departure).center.dy, lessThan(viewport.center.dy));
    expectOutsideScreen(tester, paper);
    await tester.pump(const Duration(milliseconds: 200));
    expect(departure, findsNothing);
    final earlyTop = tester.getTopLeft(paper).dy;
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getTopLeft(paper).dy, greaterThan(earlyTop));
    expect(startButton, findsNothing);
    expect(startAction, findsNothing);
    await tester.tapAt(Offset(viewport.center.dx, viewport.height * .41));
    await tester.pump(const Duration(milliseconds: 119));
    expect(find.text('残り 10 秒'), findsNothing);
    expect(startButton, findsNothing);
    expect(upperMaterial(tester), material);

    await tester.pump(const Duration(milliseconds: 1));
    // The animation posts its completion on the first frame past its endpoint.
    await tester.pump(const Duration(milliseconds: 1));
    final landed = visiblePaper(tester);
    expect(earlyTop, lessThan(landed.top));
    expect(upperMaterial(tester), material);
    expect(startAction, findsNothing);
    expect(find.text('残り 10 秒'), findsNothing);
  }

  testWidgets('game labels fit a narrow screen with large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    void expectOneLine(String label) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: label.length),
      );
      expect(boxes.map((box) => box.top).toSet(), hasLength(1), reason: label);
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      for (final box in boxes) {
        final bounds = MatrixUtils.transformRect(
          paragraph.getTransformTo(null),
          box.toRect(),
        );
        expect(
          viewportOf(tester).inflate(.01).intersect(bounds),
          bounds,
          reason: label,
        );
      }
    }

    await tester.pumpWidget(const WorkshopApp(simulated: true));
    expectOneLine('はじめる');
    expectOneLine('磨くで');
    expectOneLine('ヤンス！');
    expect(find.text('顔色'), findsNothing);
    final mascot = find.image(
      const AssetImage('assets/images/yansu_title.png'),
    );
    expect(mascot, findsOneWidget);
    final portrait = tester.getRect(mascot);
    expect(tester.getRect(find.text('ヤンス！')).bottom, lessThan(portrait.top));
    expect(portrait.bottom, lessThan(tester.getRect(find.text('はじめる')).top));
    expect(find.textContaining('POLISH'), findsNothing);
    expect(find.textContaining('色を磨き出せ'), findsNothing);
    await tapControl(tester, 'title-start');
    expectOneLine('磨く素材を選ぶ');
    expectOneLine('メダルを磨く');
    expectOneLine('これを磨く');
    await chooseMaterial(tester, 'medal');
    expectOneLine('やすりを作る');

    for (var round = 1; round <= 3; round++) {
      final counter = '$round 回目 / 全3回';
      expectOneLine(counter);
      final material = tester.getRect(find.text('メダル磨き'));
      final counterBox = tester.getRect(find.text(counter));
      expect(counterBox.left, lessThan(viewportOf(tester).width * .06));
      expect(counterBox.top, lessThan(viewportOf(tester).height * .06));
      expect(material.right, greaterThan(viewportOf(tester).width * .94));
      expect(counterBox.right, lessThan(material.left));
      expect(
        material.center.dy,
        inInclusiveRange(counterBox.top, counterBox.bottom),
      );
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 1801));
      expectOneLine('中目のやすり');
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expectOneLine('残り 10 秒');
      await tester.pump(const Duration(seconds: 10));
      if (round < 3) await tester.pumpAndSettle();
    }
    expectOneLine('今回の仕上がり');
    expectOneLine('金ピカのメダル');
    expectOneLine('もう一度遊ぶ');
    expectOneLine('タイトルへ');
  });

  test('the paper tint and stamp preserve pitch within a single grit', () {
    const first = VoiceSample(115, .55);
    const second = VoiceSample(130, .55);
    expect(classify(first, VoiceMode.pitch), Grit.medium);
    expect(classify(second, VoiceMode.pitch), Grit.medium);
    expect(sandpaperColorFor(first.hz), isNot(sandpaperColorFor(second.hz)));
    expect(sandpaperStampFor(first), '115 Hz');
    expect(sandpaperStampFor(second), '130 Hz');
    expect(sandpaperStampFor(const VoiceSample(null, .80)), contains('80%'));
  });

  testWidgets(
    'selected medal spins out of the carousel and lands on the voice screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const WorkshopApp(simulated: true));
      await tapControl(tester, 'title-start');
      await tester.pumpAndSettle();

      final departure = find.byKey(const ValueKey('medal-departure'));
      final landing = find.byKey(const ValueKey('medal-landing'));
      final confirm = find.byKey(const ValueKey('confirm-material'));
      await tapControl(tester, 'confirm-material');
      Offset paintedCenter(Finder flight) => tester.getCenter(
        find.descendant(of: flight, matching: find.byType(Opacity)).first,
      );
      final source = paintedCenter(departure);
      final initialFrame = tester
          .widget<Image>(
            find.descendant(of: departure, matching: find.byType(Image)).first,
          )
          .alignment;
      await tester.tapAt(tester.getCenter(confirm));
      await tester.pump(const Duration(milliseconds: 260));
      expect(paintedCenter(departure).dy, lessThan(source.dy));
      expect(
        tester
            .widget<Image>(
              find
                  .descendant(of: departure, matching: find.byType(Image))
                  .first,
            )
            .alignment,
        isNot(initialFrame),
      );
      expect(find.byKey(const ValueKey('capture')), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(departure, findsNothing);
      expect(mic, findsNothing);
      expect(roundIntro, findsNothing);
      final fromAbove = paintedCenter(landing);
      await tester.pump(const Duration(milliseconds: 300));
      final inFlight = paintedCenter(landing);
      expect(inFlight.dy, greaterThan(fromAbove.dy));
      await tester.pump(const Duration(milliseconds: 550));
      expect(landing, findsNothing);
      expect(roundIntro, findsOneWidget);
      expect(mic, findsNothing);
      await tester.pumpAndSettle();
      expect(landing, findsNothing);
      expect(tester.getCenter(surfaceArt).dy, greaterThan(inFlight.dy));
      expect(SurfaceArtProbe.progress(tester), 0);
      expect(find.text('1 回目 / 全3回'), findsOneWidget);

      // Leaving during departure must not navigate after the user goes back.
      await tapControl(tester, 'back');
      await tapControl(tester, 'confirm-material');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('title-start')), findsOneWidget);
      expect(find.byType(MedalFlight), findsNothing);

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tapControl(tester, 'title-start');
      await tapControl(tester, 'confirm-material');
      expect(find.byType(MedalFlight), findsNothing);
      final staticBounds = tester.getRect(roundIntro);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(roundIntro), staticBounds);
      expect(mic, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(roundIntro, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(mic, findsNothing);
      await tester.tap(find.text('続ける'));
      await tester.pump();
      expect(roundIntro, findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('やすりを作る'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Medal reaches copper -> silver -> gold. The glyph retains its first-round
  // outline through a whole round without motion, then gains a polished finish.
  for (final (material, strokes, stages, percentages) in [
    ('medal', [6, 18, 15], ['銅メダル', '銀メダル', '金メダル'], [14, 40, 55]),
    ('kanji', [22, 0, 37], ['輪郭の現れた漢', '輪郭の現れた漢', '光沢を帯びた漢'], [50, 50, 80]),
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
        expect(find.text('いろみがき'), findsNothing);
        expect(find.text('ヤンス！'), findsNothing);
        expect(find.text('疑似入力'), findsNothing);
        expect(find.byTooltip('設定'), findsOneWidget);
        final female = material == 'kanji';
        if (female) await tapControl(tester, 'voice-profile-female');
        await chooseMaterial(tester, material, waitForVoice: false);
        if (material == 'medal') {
          await tester.pump(
            medalDepartureDuration + const Duration(milliseconds: 1),
          );
          await tester.pump();
          await tester.pump(medalLandingDuration);
        }

        if (material == 'kanji') expectKanjiArt(tester, 0);
        var total = 0;
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 300));
          final numeral = ['一', '二', '三'][i];
          expect(roundIntro, findsOneWidget, reason: '$material $numeral回目');
          expect(tester.getSemantics(roundIntro).label, '$numeral回目、全三回');
          expect(mic, findsNothing);
          expect(find.text('残り 10 秒'), findsNothing);
          await tester.pumpAndSettle();
          expect(roundIntro, findsNothing);
          expect(find.text('${i + 1} 回目 / 全3回'), findsOneWidget);
          expect(find.text('いろみがき'), findsNothing);
          expect(find.text('疑似入力'), findsOneWidget);
          expect(paper, findsNothing);
          final pitch = (female ? [200, 240, 300] : [100, 120, 150])[i];
          await tapControl(tester, 'demo-$pitch');
          final captureButton = find.byKey(const ValueKey('capture'));
          expect(find.text('声を取る'), findsNothing);
          expect(find.text('音量で選ぶ'), findsNothing);
          final captureRect = tester.getRect(captureButton);
          final captureFace = microphoneFace(tester, captureButton);
          await tapControl(tester, 'capture');
          expect(find.text('声を聞いています'), findsOneWidget);
          expect(departure, findsNothing);
          expect(paper, findsNothing);
          await tester.pump(const Duration(milliseconds: 500));
          await decodeVisibleSurface(tester);
          await checkToolHandoff(
            tester,
            captureRect,
            captureFace,
            pitch,
            Grit.values[i],
          );
          final readyPaper = tester.widget<SandpaperFace>(paper);
          expect(find.text('いろみがき'), findsNothing);
          expect(readyPaper.grit, Grit.values[i]);
          expect(readyPaper.sample.hz, pitch);
          expect(
            find.descendant(of: paper, matching: find.text('$pitch Hz')),
            findsNWidgets(3),
          );
          expect(readyPaper.strokes, total);
          final grit = readyPaper.grit.label;
          expect(find.text('$gritのやすり'), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 649));
          expect(find.text('残り 10 秒'), findsNothing);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump();
          expect(find.text('いろみがき'), findsNothing);
          expect(find.text('残り 10 秒'), findsOneWidget);
          expect(find.text('磨け！'), findsOneWidget);
          visiblePaper(tester);

          for (var n = 0; n < strokes[i]; n++) {
            await tapControl(tester, 'simulate-stroke');
          }
          total += strokes[i];
          await tester.pump(const Duration(seconds: 9));
          expect(find.text('残り 1 秒'), findsOneWidget);
          expect(find.text('磨け！'), findsNothing);
          expect(find.textContaining('往復'), findsNothing);
          expect(find.text(grit), findsNothing);
          expect(
            find.semantics.byPredicate(
              (node) =>
                  node.label.contains(stages[i]) &&
                  '${node.label} ${node.value}'.contains('${percentages[i]}%'),
            ),
            findsOne,
          );
          final surface = tester.widget<SurfaceArt>(find.byType(SurfaceArt));
          expect(surface.strokeCount, total);
          expect(surface.progress * 100, closeTo(percentages[i], 0.5));
          await decodeVisibleSurface(tester);
          final activePaper = tester.widget<SandpaperFace>(paper);
          visiblePaper(tester);
          expect(activePaper.sample, same(readyPaper.sample));
          expect(activePaper.grit, readyPaper.grit);
          expect(activePaper.strokes, total);
          expect(activePaper.progress, surface.progress);
          if (material == 'medal') {
            final image = [
              'assets/fonts/daou.jpg',
              'assets/fonts/gin.jpg',
              'assets/images/medal-gold.png',
            ][i];
            expect(
              find.descendant(
                of: find.byType(SurfaceArt),
                matching: find.byKey(ValueKey(image)),
              ),
              findsOneWidget,
            );
          } else {
            expectKanjiArt(tester, surface.progress);
          }
          await tester.pump(const Duration(seconds: 1));
        }

        expect(find.text('今回の仕上がり'), findsOneWidget);
        expect(find.text('いろみがき'), findsNothing);
        expect(find.text('疑似入力'), findsOneWidget);
        expect(paper, findsNothing);
        // The medal always ends at the polishing gold, however far it got.
        if (material == 'medal') {
          expect(find.text('金ピカのメダル'), findsOneWidget);
        } else {
          // 6 points: 3漢, shown as the rank-colored 漢 without a digit.
          expect(find.bySemanticsLabel('3漢'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('assets/images/kanji-rank-3.png')),
            findsOneWidget,
          );
          // The 3漢 nameplate (ムキムキ) sits over the character.
          expect(
            find.byKey(const ValueKey('assets/images/workshop-title-03.png')),
            findsOneWidget,
          );
          // 粗目3 + 中目2 + 細目1 = 6 points, polished to the end: success.
          expect(
            find.byKey(
              const ValueKey('assets/images/character-success-3.webp'),
            ),
            findsOneWidget,
          );
        }
        expect(find.textContaining('往復'), findsNothing);
        await tapControl(tester, 'retry');
        expect(find.text('磨く素材を選ぶ'), findsOneWidget);
        await chooseMaterial(tester, material);
        expect(find.text('1 回目 / 全3回'), findsOneWidget);
        final highPitch = female ? 300 : 150;
        expect(find.byKey(ValueKey('demo-$highPitch')), findsOneWidget);
        expect(SurfaceArtProbe.progress(tester), 0);
        if (material == 'kanji') expectKanjiArt(tester, 0);
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
    await chooseMaterial(tester, 'kanji');
    await tapControl(tester, 'capture');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1550));
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
    await chooseMaterial(tester, 'kanji');
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    expect(SurfaceArtProbe.progress(tester), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'automatic start waits for the foreground and can retry a failed sensor',
    (tester) async {
      const commands = MethodChannel('polish/device');
      const events = MethodChannel('polish/strokes');
      final messenger = tester.binding.defaultBinaryMessenger;
      var starts = 0;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(commands, (call) async {
        if (call.method == 'capture') return {'hz': 190.0, 'level': .8};
        if (call.method == 'startMotion' && ++starts == 1) {
          throw PlatformException(code: 'sensor');
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(events, null);
        messenger.setMockMethodCallHandler(commands, null);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpWidget(const WorkshopApp(simulated: false));
      await tapControl(tester, 'title-start');
      await chooseMaterial(tester, 'kanji');
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(starts, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(starts, 0);
      await tester.tap(find.text('続ける'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 649));
      expect(starts, 0);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(starts, 1);
      expect(find.text('計測を再試行'), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
      expect(starts, 1);
      expect(find.text('残り 10 秒'), findsNothing);
      await tapControl(tester, 'retry-motion');
      expect(starts, 2);
      expect(find.text('残り 10 秒'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.text('磨け！'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('磨け！'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the saved stroke count applies to the next game', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final writes = <int>[];
    await tester.pumpWidget(
      WorkshopApp(
        simulated: true,
        initialStrokesToGold: 31,
        persistStrokesToGold: (value) async {
          writes.add(value);
          if (writes.length == 1) throw StateError('write failed');
        },
      ),
    );
    await tapControl(tester, 'title-start');
    await tapControl(tester, 'diagnostics');
    await tester.pumpAndSettle();
    final count = find.byKey(const ValueKey('strokes-to-gold'));
    String currentText() => tester.widget<TextField>(count).controller!.text;
    expect(currentText(), '31');
    for (final invalid in ['4', '61', '2.5', '']) {
      await tester.enterText(count, invalid);
      await tapControl(tester, 'save-settings');
      expect(find.textContaining('整数を入力'), findsOneWidget);
    }
    expect(writes, isEmpty);
    await tester.enterText(count, '３７');
    await tapControl(tester, 'save-settings');
    expect(writes, [37]);
    expect(currentText(), '３７');
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    await tapControl(tester, 'save-settings');
    await tester.pumpAndSettle();
    expect(writes, [37, 37]);
    expect(find.text('磨く素材を選ぶ'), findsOneWidget);

    await tapControl(tester, 'diagnostics');
    await tester.pumpAndSettle();
    expect(currentText(), '37');
    await tester.enterText(count, '18');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await chooseMaterial(tester, 'medal');
    await tapControl(tester, 'demo-100');
    await tapControl(tester, 'capture');
    await tester.pump(const Duration(milliseconds: 500));
    await finishHandoff(tester);
    await tapControl(tester, 'simulate-stroke');
    expect(SurfaceArtProbe.progress(tester), closeTo(.5 / 37, .000001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('material swipe, back buttons and the title button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WorkshopApp(simulated: true));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');

    await tapControl(tester, 'diagnostics');
    await tester.pumpAndSettle();
    await tapControl(tester, 'open-device-lab');
    await tester.pumpAndSettle();
    expect(find.text('声とやすり'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('strokes-to-gold')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // The carousel loops in both directions; the heading follows the center.
    expect(find.text('メダルを磨く'), findsOneWidget);
    expect(find.text('漢字を磨く'), findsNothing);
    await turnCarousel(tester);
    expect(find.text('漢字を磨く'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assets/images/kanji-silver.png')),
      findsWidgets,
    );
    await turnCarousel(tester);
    expect(find.text('メダルを磨く'), findsOneWidget);
    await turnCarousel(tester, left: false);
    expect(find.text('漢字を磨く'), findsOneWidget);
    expect(find.text('1 回目 / 全3回'), findsNothing);
    await turnCarousel(tester, left: false);
    expect(find.text('メダルを磨く'), findsOneWidget);

    // 「戻る」 on the material screen returns to the title.
    await tapControl(tester, 'back');
    expect(find.text('はじめる'), findsOneWidget);
    await tapControl(tester, 'title-start');

    // 「戻る」 on the first voice screen returns to the chosen material.
    await chooseMaterial(tester, 'kanji');
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    expect(find.text('漢磨き'), findsOneWidget);
    await tapControl(tester, 'back');
    expect(find.text('磨く素材を選ぶ'), findsOneWidget);
    expect(find.text('漢字を磨く'), findsOneWidget);

    // Play the medal through three rounds to the result.
    await chooseMaterial(tester, 'medal');
    for (var round = 1; round <= 3; round++) {
      expect(find.text('$round 回目 / 全3回'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('back')),
        round == 1 ? findsOneWidget : findsNothing,
      );
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      await finishHandoff(tester);
      await tapControl(tester, 'simulate-stroke');
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
    }
    expect(find.text('今回の仕上がり'), findsOneWidget);

    // 「タイトルへ」 resets the play; the system back cannot reopen it.
    await tapControl(tester, 'to-title');
    expect(find.text('はじめる'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('今回の仕上がり'), findsNothing);
    expect(find.text('はじめる'), findsOneWidget);

    // The system back on the material screen also returns to the title.
    await tapControl(tester, 'title-start');
    expect(find.text('磨く素材を選ぶ'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('はじめる'), findsOneWidget);
    await tapControl(tester, 'title-start');
    await chooseMaterial(tester, 'medal');
    expect(find.text('1 回目 / 全3回'), findsOneWidget);
    expect(tester.widget<SurfaceArt>(find.byType(SurfaceArt)).progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'contact raises dust and scored strokes throw chips on both materials',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      const commands = MethodChannel('polish/device');
      const events = MethodChannel('polish/strokes');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(events, (_) async => null);
      messenger.setMockMethodCallHandler(
        commands,
        (call) async => call.method == 'capture'
            ? <String, num>{'hz': 120, 'level': .6}
            : null,
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(commands, null);
        messenger.setMockMethodCallHandler(events, null);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      Future<void> motion(int event) async {
        await messenger.handlePlatformMessage(
          events.name,
          events.codec.encodeSuccessEnvelope(event),
          null,
        );
        await tester.pump();
      }

      final dust = find.byKey(const ValueKey('abrasive-dust'));
      final shavings = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image == const AssetImage('assets/images/shavings.png'),
      );
      final flakes = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.startsWith(
              'assets/images/shards/',
            ),
      );
      final tinted = find.ancestor(
        of: shavings,
        matching: find.byType(ColorFiltered),
      );
      for (final material in ['medal', 'kanji']) {
        await tester.pumpWidget(const WorkshopApp(simulated: false));
        await tester.pumpAndSettle();
        await tapControl(tester, 'title-start');
        await chooseMaterial(tester, material);
        await tapControl(tester, 'capture');
        await finishHandoff(tester);
        expect(dust, findsNothing);
        await motion(2);
        expect(dust, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 190));
        expect(dust, findsAtLeastNWidgets(2));
        expect(SurfaceArtProbe.progress(tester), 0);
        expect(flakes, findsNothing);
        await motion(-1);
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        expect(dust, findsNothing);

        await motion(1);
        expect(shavings, findsOneWidget);
        expect(flakes, findsNWidgets(5));
        expect(SurfaceArtProbe.progress(tester), greaterThan(0));
        if (material == 'medal') {
          expect(tinted, findsNothing);
          for (var i = 0; i < 30 && tinted.evaluate().isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 450));
            await motion(1);
          }
        }
        expect(tinted, findsWidgets);
        for (var i = 0; i < 7; i++) {
          await motion(1);
        }
        expect(dust.evaluate().length, inInclusiveRange(1, 4));
        await tester.pump(const Duration(milliseconds: 450));
        await tester.pump();
        expect(shavings, findsNothing);
        expect(flakes, findsNothing);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        await tester.pump();
        await motion(2);
        await motion(1);
        await tester.pump(const Duration(milliseconds: 200));
        expect(dust, findsNothing);
        expect(shavings, findsNothing);
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  for (final (play, strokes) in [
    ('without moving', [0, 0, 0]),
    ('with a fine finish', [11, 11, 20]),
  ]) {
    testWidgets('three rounds $play reveal the medal inscription by touch', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const WorkshopApp(simulated: true));
      await tester.pumpAndSettle();
      await tapControl(tester, 'title-start');
      await chooseMaterial(tester, 'medal');
      for (var round = 1; round <= 3; round++) {
        expect(
          find.text('仕上げは高い声で'),
          round == 3 && strokes[0] > 0 ? findsOneWidget : findsNothing,
        );
        await tapControl(tester, round == 3 ? 'demo-150' : 'demo-100');
        await tapControl(tester, 'capture');
        await tester.pump(const Duration(milliseconds: 500));
        await finishHandoff(tester);
        for (var n = 0; n < strokes[round - 1]; n++) {
          await tapControl(tester, 'simulate-stroke');
        }
        if (strokes[0] == 0) expect(SurfaceArtProbe.progress(tester), 0);
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
      }
      expect(find.text('今回の仕上がり'), findsOneWidget);
      expect(SurfaceArtProbe.progress(tester), greaterThanOrEqualTo(.95));
      expect(find.text('金ピカのメダル'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assets/images/medal-gold-polishing.png')),
        findsOneWidget,
      );
      expect(find.text('金メダル'), findsNothing);

      // Rubbing the finished gold medal reveals the engraved title where the
      // finger passed.
      expect(find.textContaining('指でこすると'), findsOneWidget);
      final revealed = find.byKey(const ValueKey('medal-revealed'));
      expect(revealed, findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('medal-rub')),
        const Offset(80, 0),
      );
      await tester.pump();
      expect(revealed, findsOneWidget);
      expect(
        find.descendant(
          of: revealed,
          matching: find.byKey(const ValueKey('assets/fonts/kinpika.jpg')),
        ),
        findsOneWidget,
      );
      await tapControl(tester, 'retry');
      expect(revealed, findsNothing);
    });
  }

  testWidgets('a failed kanji result cracks the rank 漢 behind the character', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WorkshopApp(simulated: true));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');
    await chooseMaterial(tester, 'kanji');
    for (var round = 1; round <= 3; round++) {
      await tapControl(tester, 'demo-150');
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      await finishHandoff(tester);
      await tester.pump(const Duration(seconds: 10));
      if (round < 3) await tester.pumpAndSettle();
    }
    await tester.pump();
    expect(find.text('今回の仕上がり'), findsOneWidget);
    String? keyOf(Widget w) => w is Image && w.key is ValueKey<String>
        ? (w.key! as ValueKey<String>).value
        : null;
    Finder crack(String suffix) => find.byWidgetPredicate((w) {
      final key = keyOf(w);
      return key != null &&
          key.startsWith('assets/images/kanji-crack-') &&
          key.endsWith(suffix);
    });
    final intact = find.byWidgetPredicate(
      (w) => keyOf(w)?.startsWith('assets/images/kanji-rank-') ?? false,
    );
    // Unpolished: overpolished character, and the rank 漢 starts intact.
    expect(intact, findsOneWidget);
    final rankOpacity = tester.widget<Opacity>(
      find.ancestor(of: intact, matching: find.byType(Opacity)).first,
    );
    expect(rankOpacity.opacity, lessThan(1));
    // The rank spins in first; the character fades in after it.
    final character = find.byWidgetPredicate(
      (w) => keyOf(w)?.startsWith('assets/images/overpolished-') ?? false,
    );
    double characterOpacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(of: character, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;
    expect(characterOpacity(), 0);
    await tester.pump(const Duration(milliseconds: 800));
    expect(crack('-before.png'), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(characterOpacity(), 1);
    // Then the overpolished rank cracks.
    await tester.pump(const Duration(milliseconds: 700));
    expect(crack('-before.png'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      crack('-after.png').evaluate().length +
          crack('-before.png').evaluate().length,
      1,
    );
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
    await chooseMaterial(tester, 'medal');
    await decodeVisibleSurface(tester);
    await tapControl(tester, 'capture');
    expect(find.textContaining('マイクを許可'), findsOneWidget);
    expect(departure, findsNothing);
    expect(paper, findsNothing);
    await tapControl(tester, 'capture');
    expect(attempts, 2);
    expect(find.byKey(const ValueKey('voice-mode')), findsNothing);
    expect(find.text('細目のやすり'), findsOneWidget);
    visiblePaper(tester); //「視差効果を減らす」設定では最初のフレームで見える。
    expectOutsideScreen(tester, departure);
    expect(startAction, findsNothing);
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
    expect(starts, isEmpty);
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.text('磨け！'), findsOneWidget);
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
    expect(find.textContaining('往復'), findsNothing);
    expect(surface().progress * 100, closeTo(50 / 22 * 1.25 / 3.5, 1e-10));
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
    await tester.pumpAndSettle();
    expect(find.text('2 回目 / 全3回'), findsOneWidget);
    expect(paper, findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
