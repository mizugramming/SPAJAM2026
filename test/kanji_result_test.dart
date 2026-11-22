import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';
import 'package:polish_workshop/main.dart';
import 'package:polish_workshop/ui/workshop.dart';

import 'workshop_flow_test.dart' show chooseMaterial, tapControl;

void main() {
  test('grit points add up to 3..9 and pick the result character', () {
    expect(Grit.values.map(gritPoints), [3, 2, 1]);
    const ranks = {
      3: '5漢',
      4: '4漢',
      5: '4漢',
      6: '3漢',
      7: '2漢',
      8: '2漢',
      9: '1漢',
    };
    for (final MapEntry(key: points, value: rank) in ranks.entries) {
      expect(kanjiRank(points), rank, reason: '$points');
      final n = int.parse(rank[0]);
      expect(
        kanjiResultImage(points),
        'assets/images/character-success-$n.webp',
        reason: '$points',
      );
      expect(
        kanjiNameplateImage(points),
        'assets/images/workshop-title-0$n.png',
      );
      expect(
        kanjiNameplate(points),
        ['九州男児', '醤油顔', 'ムキムキ', '塩顔', '韓国系'][n - 1],
      );
      expect(kanjiNameplateComment(points), isNotEmpty);
      if (n == 1) {
        expect(kanjiNameplateComment(points), 'ガサツなのに実は優しいオトコ♡');
      }
    }
  });

  test('kanji success includes both ends and breaks past the target', () {
    final material = materials.singleWhere((m) => m.id == 'kanji');
    expect(material.finishAt(material.initialValue), TargetFinish.under);
    expect(material.finishAt(20.01), TargetFinish.under);
    expect(material.finishAt(20), TargetFinish.onTarget);
    expect(material.finishAt(10), TargetFinish.onTarget);
    expect(material.finishAt(9.99), TargetFinish.over);
    expect(materials.firstWhere((m) => m.id == 'medal').finishAt(0), isNull);
  });

  testWidgets(
    'first over-limit stroke ends any round and scores exactly once',
    (tester) async {
      final kanji = materials.singleWhere((m) => m.id == 'kanji');
      for (
        var finalRound = 1;
        finalRound <= GameController.roundCount;
        finalRound++
      ) {
        var judgements = 0;
        final game = GameController(
          judge: (material, value) {
            judgements++;
            return material.finishAt(value)!.name;
          },
        );
        game.select(kanji);
        for (var round = 1; round <= finalRound; round++) {
          game.acceptVoice(const VoiceSample(100));
          game.startPolishing();
          if (round < finalRound) {
            await tester.pump(GameController.polishDuration);
          }
        }
        for (var stroke = 1; stroke <= 90; stroke++) {
          expect(game.stroke(), isNotNull);
        }
        expect(game.phase, GamePhase.polishing);
        expect(game.targetFinish, TargetFinish.onTarget);
        expect(game.remainingPolishTime, greaterThan(Duration.zero));
        expect(
          game.stroke(),
          isNull,
        ); // The breaking stroke issues no new pulse.
        expect(game.phase, GamePhase.result);
        expect(game.round, finalRound);
        expect(game.remainingPolishTime, Duration.zero);
        expect(game.remainingSeconds, 0);
        expect(game.totalStrokes, 91);
        expect(game.verdict, TargetFinish.over.name);
        expect(game.stroke(), isNull);
        expect(game.acceptVoice(const VoiceSample(100)), isFalse);
        game.startPolishing();
        await tester.pump(const Duration(seconds: 15));
        expect(game.phase, GamePhase.result);
        expect(game.round, finalRound);
        expect(game.totalStrokes, 91);
        expect(judgements, 1);
        game.dispose();
      }
    },
  );

  for (final breakingRound in <int?>[null, 1, 3]) {
    testWidgets(
      breakingRound == null
          ? 'underpolished kanji stays gray after three rounds and retries'
          : 'kanji fractures immediately in round $breakingRound and retries',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(393, 852);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const WorkshopApp(simulated: true));
        await tapControl(tester, 'title-start');
        await chooseMaterial(tester, 'kanji');
        for (var round = 1; round <= GameController.roundCount; round++) {
          await tapControl(tester, 'demo-100');
          await tapControl(tester, 'capture');
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 1801));
          await tester.pump(const Duration(milliseconds: 650));
          await tester.pump();
          if (round == breakingRound) {
            expect(find.textContaining('そろそろ'), findsNothing);
            for (var n = 0; n < 90; n++) {
              await tapControl(tester, 'simulate-stroke');
            }
            expect(find.textContaining('そろそろ'), findsOneWidget);
            await tapControl(tester, 'simulate-stroke');
            final heading = find.text('漢割り');
            final firstRank = breakingRound == 3; // Three coarse grits earn 1漢.
            final firstFrame = find.byKey(
              ValueKey(
                firstRank
                    ? 'kanji-fracture-0'
                    : 'assets/images/kanji-rank-5.png',
              ),
            );
            expect(heading, findsOneWidget);
            expect(firstFrame, findsOneWidget);
            expect(
              tester.getBottomLeft(heading).dy,
              lessThanOrEqualTo(tester.getTopLeft(firstFrame).dy),
            );
            expect(find.byKey(const ValueKey('simulate-stroke')), findsNothing);
            expect(find.byKey(const ValueKey('retry')), findsOneWidget);
            expect(find.byKey(const ValueKey('capture')), findsNothing);
            if (firstRank) {
              await tester.pump(const Duration(milliseconds: 350));
              expect(
                find.byKey(const ValueKey('kanji-fracture-2')),
                findsOneWidget,
              );
              await tester.pump(const Duration(milliseconds: 400));
              expect(
                find.byKey(const ValueKey('kanji-fracture-4')),
                findsOneWidget,
              );
            } else {
              Finder frame(String part) => find.byKey(
                ValueKey('assets/images/kanji-crack-5-$part.webp'),
              );
              await tester.pump(const Duration(milliseconds: 700));
              expect(frame('before'), findsOneWidget);
              await tester.pump(const Duration(milliseconds: 400));
              expect(frame('left'), findsOneWidget);
              expect(frame('right'), findsOneWidget);
              await tester.pump(const Duration(milliseconds: 600));
              expect(frame('after'), findsOneWidget);
            }
            await tester.pump(GameController.polishDuration);
            expect(heading, findsOneWidget);
            break;
          }
          await tester.pump(GameController.polishDuration);
          await tester.pumpAndSettle();
        }
        if (breakingRound == null) {
          expect(find.text('磨き不足'), findsOneWidget);
          expect(find.text('漢割り'), findsNothing);
          final face = tester.widget<Image>(
            find.byKey(const ValueKey('kanji-underpolished')),
          );
          expect(
            (face.image as ResizeImage).imageProvider,
            const AssetImage('assets/images/character-under.webp'),
          );
          final surface = find.byKey(const ValueKey('kanji-under-surface'));
          expect(
            (tester.widget<Image>(surface).image as ResizeImage).imageProvider,
            const AssetImage('assets/images/kanji-silver.png'),
          );
          tester.view.physicalSize = const Size(320, 568);
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.pumpAndSettle();
          final character = find.byKey(const ValueKey('kanji-underpolished'));
          expect(
            (tester.widget<Image>(character).image as ResizeImage)
                .imageProvider,
            const AssetImage('assets/images/character-under-still.webp'),
          );
          expect(
            tester.getCenter(character).dx,
            greaterThan(tester.getCenter(surface).dx),
          );
          expect(
            tester.getBottomLeft(character).dy,
            lessThan(tester.getTopLeft(find.byKey(const ValueKey('retry'))).dy),
          );
        }
        for (final rank in [1, 5]) {
          expect(
            find.byKey(ValueKey('assets/images/character-success-$rank.webp')),
            findsNothing,
          );
          expect(
            find.byKey(ValueKey('assets/images/workshop-title-0$rank.png')),
            findsNothing,
          );
        }
        await tapControl(tester, 'retry');
        await chooseMaterial(tester, 'kanji');
        expect(find.byKey(const ValueKey('kanji-fracture-4')), findsNothing);
        expect(
          find.byKey(const ValueKey('assets/images/kanji-crack-5-after.webp')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('kanji-underpolished')), findsNothing);
      },
    );
  }

  testWidgets(
    'the breaking Android event cancels the sensor and active motor',
    (tester) async {
      const commands = MethodChannel('polish/device');
      const sensor = MethodChannel('polish/strokes');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(sensor, (_) async => null);
      messenger.setMockMethodCallHandler(commands, (call) async {
        calls.add(call.method);
        return call.method == 'capture' ? <String, num>{'hz': 100} : null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(sensor, null);
        messenger.setMockMethodCallHandler(commands, null);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const WorkshopApp(simulated: false));
      await tapControl(tester, 'title-start');
      await chooseMaterial(tester, 'kanji');
      await tapControl(tester, 'capture');
      await tester.pump(const Duration(milliseconds: 1801));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(calls, contains('startMotion'));
      Future<void> sendMotion(int event) => messenger.handlePlatformMessage(
        sensor.name,
        sensor.codec.encodeSuccessEnvelope(event),
        null,
      );
      for (var i = 0; i < 90; i++) {
        await sendMotion(1);
      }
      await tester.pump();
      expect(calls.where((name) => name == 'pulse').length, 90);
      expect(find.textContaining('そろそろ'), findsOneWidget);
      calls.clear();
      await sendMotion(1);
      await tester.pump();
      expect(calls, ['stopMotion', 'stopPulse']);
      expect(find.text('漢割り'), findsOneWidget);
      await sendMotion(2);
      await sendMotion(1);
      await tester.pump(const Duration(seconds: 15));
      expect(calls, ['stopMotion', 'stopPulse']);
      expect(find.text('漢割り'), findsOneWidget);
    },
  );

  testWidgets('each round remembers its grit until the play is reset', (
    tester,
  ) async {
    final game = GameController();
    addTearDown(game.dispose);
    final kanji = materials.firstWhere((m) => m.id == 'kanji');
    for (final profile in VoiceProfile.values) {
      game.setVoiceProfile(profile);
      game.select(kanji);
      for (final hz in [
        profile.mediumFromHz - .1,
        profile.fineFromHz,
        profile.mediumFromHz - .1,
      ]) {
        expect(game.acceptVoice(const VoiceSample(null)), isFalse);
        final voice = VoiceSample(hz);
        expect(game.acceptVoice(voice), isTrue);
        expect(game.acceptVoice(voice), isFalse);
        game.startPolishing();
        await tester.pump(GameController.polishDuration);
      }
      expect(game.phase, GamePhase.result);
      expect(game.grits, [Grit.coarse, Grit.fine, Grit.coarse]);
      expect(kanjiPoints(game), 7);
      game.reset();
      expect(game.grits, isEmpty);
    }
  });
}
