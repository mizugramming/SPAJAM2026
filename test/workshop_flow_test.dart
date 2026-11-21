import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/main.dart';
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
Future<void> chooseMaterial(WidgetTester tester, String id) async {
  for (var i = 0; i < _order.length; i++) {
    if (find.text(_headings[id]!).evaluate().isNotEmpty) break;
    await turnCarousel(tester);
  }
  expect(find.text(_headings[id]!), findsOneWidget);
  await tapControl(tester, 'confirm-material');
}

/// 研磨画面の素材の研磨率。
class SurfaceArtProbe {
  static double progress(WidgetTester tester) =>
      tester.widget<SurfaceArt>(find.byType(SurfaceArt)).progress;
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
        await chooseMaterial(tester, material);

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
          final surface = tester.widget<SurfaceArt>(find.byType(SurfaceArt));
          expect(surface.strokeCount, total);
          expect(surface.progress * 100, closeTo(percentages[i], 0.5));
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
        expect(find.text(stages.last), findsOneWidget);
        expect(find.text('3回の研磨で、合計$total往復しました。'), findsOneWidget);
        await tapControl(tester, 'retry');
        expect(find.text('磨く素材を選ぶ'), findsOneWidget);
        await chooseMaterial(tester, material);
        expect(find.text('1 回目 / 全3回'), findsOneWidget);
        expect(tester.widget<SurfaceArt>(find.byType(SurfaceArt)).progress, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('material swipe, back buttons and the title button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WorkshopApp(simulated: true));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');

    // The carousel loops in both directions; the heading follows the center.
    expect(find.text('メダルを磨く'), findsOneWidget);
    expect(find.text('漢字を磨く'), findsNothing);
    await turnCarousel(tester);
    expect(find.text('漢字を磨く'), findsOneWidget);
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
      await tapControl(tester, 'start');
      await tapControl(tester, 'simulate-stroke');
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
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

  testWidgets('medal strokes throw shavings that fade quickly', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    final shavings = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image == const AssetImage('assets/images/shavings.png'),
    );
    Future<void> polish(String material) async {
      await tester.pumpWidget(const WorkshopApp(simulated: true));
      await tester.pumpAndSettle();
      await tapControl(tester, 'title-start');
      await chooseMaterial(tester, material);
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      await tapControl(tester, 'start');
    }

    final flakes = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.startsWith('assets/images/shards/'),
    );
    await polish('medal');
    expect(shavings, findsNothing);
    await tapControl(tester, 'simulate-stroke');
    expect(shavings, findsOneWidget);
    expect(flakes, findsNWidgets(5));
    expect(
      find.byKey(const ValueKey('simulate-stroke')).hitTestable(),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 450));
    expect(shavings, findsNothing);
    expect(flakes, findsNothing);
    await tapControl(tester, 'simulate-stroke');
    expect(shavings, findsOneWidget);
    expect(
      find.ancestor(of: shavings, matching: find.byType(ColorFiltered)),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 450));

    // Once the medal turns silver, the shavings take the medal's color.
    final tinted = find.ancestor(
      of: shavings,
      matching: find.byType(ColorFiltered),
    );
    for (var i = 0; i < 60 && tinted.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 450));
      await tapControl(tester, 'simulate-stroke');
    }
    expect(tinted, findsOneWidget);
    expect(SurfaceArtProbe.progress(tester), greaterThanOrEqualTo(.55));
    await tester.pump(const Duration(seconds: 11));

    await tester.pumpWidget(const SizedBox());
    await polish('kanji');
    await tapControl(tester, 'simulate-stroke');
    expect(shavings, findsNothing);
    expect(flakes, findsNothing);
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a medal polished to a shine is called 金ピカのメダル', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WorkshopApp(simulated: true));
    await tester.pumpAndSettle();
    await tapControl(tester, 'title-start');
    await chooseMaterial(tester, 'medal');
    for (var round = 1; round <= 3; round++) {
      await tapControl(tester, 'demo-110');
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 500));
      await tapControl(tester, 'start');
      for (var i = 0; round == 1 && i < 20; i++) {
        await tapControl(tester, 'simulate-stroke');
      }
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
    }
    expect(find.text('今回の仕上がり'), findsOneWidget);
    expect(SurfaceArtProbe.progress(tester), greaterThanOrEqualTo(.95));
    expect(find.text('金ピカのメダル'), findsOneWidget);
    expect(find.text('金メダル'), findsNothing);
  });

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
    await chooseMaterial(tester, 'medal');
    await tapControl(tester, 'capture');
    expect(find.textContaining('マイクを許可'), findsOneWidget);
    await tapControl(tester, 'capture');
    expect(find.textContaining('高さを読み取れません'), findsOneWidget);
    await tapControl(tester, 'voice-mode');
    await tapControl(tester, 'capture');
    expect(attempts, 3);
    expect(find.text('細目のやすり'), findsOneWidget);
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
    expect(
      tester.widget<SurfaceArt>(find.byType(SurfaceArt)).progress * 100,
      closeTo(2, 0.5),
    );
    expect(pulses.single, containsPair('amplitude', isPositive));
    expect(pulses.single, containsPair('durationMs', isPositive));
    expect(pulses.single, containsPair('followStroke', true));
    await tester.pump(const Duration(seconds: 10));
    await reportStroke();
    expect(pulses, hasLength(1));
    expect(find.text('2 回目 / 全3回'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
