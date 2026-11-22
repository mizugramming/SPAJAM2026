import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';
import 'package:polish_workshop/main.dart';
import 'package:polish_workshop/ui/workshop.dart';

import 'workshop_flow_test.dart' show chooseMaterial, tapControl;

void main() {
  test('grit points add up to 3..9 and pick the result character', () {
    expect(Grit.values.map(gritPoints), [3, 2, 1]);
    const expected = {
      3: 'character-05.png',
      4: 'character-04.png',
      5: 'character-04.png',
      6: 'gyansu.jpg',
      7: 'character-02.png',
      8: 'character-02.png',
      9: 'kyushu-danji.png',
    };
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
    }
    for (final MapEntry(key: points, value: file) in expected.entries) {
      expect(
        kanjiResultImage(points),
        'assets/images/$file',
        reason: '$points',
      );
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

  for (final tooFar in [false, true]) {
    testWidgets('kanji ends ${tooFar ? "broken" : "gray"} and retries', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const WorkshopApp(simulated: true));
      await tapControl(tester, 'title-start');
      await chooseMaterial(tester, 'kanji');
      for (var round = 1; round <= 3; round++) {
        await tapControl(tester, 'demo-100');
        await tapControl(tester, 'capture');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 1801));
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pump();
        if (tooFar && round == 1) {
          for (var n = 0; n < 39; n++) {
            await tapControl(tester, 'simulate-stroke');
          }
          expect(find.text('今、手を止めて！'), findsOneWidget);
          await tapControl(tester, 'simulate-stroke');
          expect(
            find.byKey(const ValueKey('kanji-fracture-0')),
            findsOneWidget,
          );
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
        }
        await tester.pump(GameController.polishDuration);
        await tester.pumpAndSettle();
        if (tooFar) {
          expect(
            find.byKey(const ValueKey('kanji-fracture-4')),
            findsOneWidget,
          );
        }
      }
      expect(find.text(tooFar ? '削りすぎ' : '磨き不足'), findsOneWidget);
      if (!tooFar) {
        final face = tester.widget<Image>(
          find.byKey(const ValueKey('kanji-underpolished')),
        );
        expect(
          (face.image as ResizeImage).imageProvider,
          const AssetImage('assets/images/kanji-silver.png'),
        );
      }
      expect(find.bySemanticsLabel('1漢'), findsNothing);
      await tapControl(tester, 'retry');
      await chooseMaterial(tester, 'kanji');
      expect(find.byKey(const ValueKey('kanji-fracture-4')), findsNothing);
      expect(find.byKey(const ValueKey('kanji-underpolished')), findsNothing);
    });
  }

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
