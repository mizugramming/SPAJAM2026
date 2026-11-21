import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';

void main() {
  const coarse = VoiceSample(100, .6);
  const medium = VoiceSample(120, .6);
  const fine = VoiceSample(150, .6);

  test('last-round gold polishing follows the selected stroke count', () {
    final medal = materials.first;
    final floor = medal.finishAtLeast!;
    for (final (target, coarseOrMedium, fine) in [
      (5, 5, 4),
      (22, 22, 16),
      (60, 59, 42),
    ]) {
      for (final grit in Grit.values) {
        var value = medal.initialValue - medal.maxRemoval * .60;
        final strokes = grit == Grit.fine ? fine : coarseOrMedium;
        for (var i = 0; i < strokes; i++) {
          expect(medal.progressAt(value), lessThan(floor));
          value = medal.valueAfterStroke(
            value,
            grit,
            strokesToGold: target,
            finalRound: true,
          );
        }
        expect(medal.stageAt(medal.progressAt(value)).name, '金ピカのメダル');
      }
    }
  });

  testWidgets(
    'a motionless medal gains its finish only at the final deadline',
    (tester) async {
      final game = GameController();
      addTearDown(game.dispose);
      for (final material in materials) {
        game.select(material);
        for (var round = 1; round <= GameController.roundCount; round++) {
          game.acceptVoice(coarse, VoiceMode.pitch);
          game.startPolishing();
          await tester.pump(const Duration(milliseconds: 9999));
          expect(game.phase, GamePhase.polishing);
          expect(game.progress, 0);
          await tester.pump(const Duration(milliseconds: 1));
          if (round < GameController.roundCount) expect(game.progress, 0);
        }
        expect(game.phase, GamePhase.result);
        expect(game.totalStrokes, 0);
        expect(game.progress, material.id == 'medal' ? .95 : 0);
      }
    },
  );

  test(
    'both voice ranges include their lower boundaries and preserve demo grits',
    () {
      for (final (profile, mediumFrom, fineFrom) in [
        (VoiceProfile.male, 110.0, 135.0),
        (VoiceProfile.female, 220.0, 270.0),
      ]) {
        for (final (hz, expected) in [
          (mediumFrom - .1, Grit.coarse),
          (mediumFrom, Grit.medium),
          (fineFrom - .1, Grit.medium),
          (fineFrom, Grit.fine),
        ]) {
          expect(
            classify(VoiceSample(hz, .6), VoiceMode.pitch, profile: profile),
            expected,
          );
        }
        for (final grit in Grit.values) {
          final hz = profile.demoHz(grit);
          expect(
            classify(VoiceSample(hz, .6), VoiceMode.pitch, profile: profile),
            grit,
          );
        }
        for (final (level, expected) in [
          (.14, null),
          (.15, Grit.coarse),
          (.45, Grit.medium),
          (.70, Grit.fine),
        ]) {
          expect(
            classify(
              VoiceSample(null, level),
              VoiceMode.volume,
              profile: profile,
            ),
            expected,
          );
        }
        for (final invalid in [
          const VoiceSample(null, .6),
          const VoiceSample(double.nan, .6),
          const VoiceSample(200, 0),
        ]) {
          expect(classify(invalid, VoiceMode.pitch, profile: profile), isNull);
        }
      }
      expect(classify(medium, VoiceMode.pitch), Grit.medium);
      expect(
        classify(
          const VoiceSample(240, .6),
          VoiceMode.pitch,
          profile: VoiceProfile.female,
        ),
        Grit.medium,
      );
      expect(classify(fine, VoiceMode.pitch), Grit.fine);
      expect(
        classify(fine, VoiceMode.pitch, profile: VoiceProfile.female),
        Grit.coarse,
      );
    },
  );

  test('a play keeps its selected voice profile and shows the original Hz', () {
    final game = GameController();
    addTearDown(game.dispose);
    expect(game.voiceProfile, VoiceProfile.male);
    game.setVoiceProfile(VoiceProfile.female);
    game.select(materials.first);
    game.setVoiceProfile(VoiceProfile.male);
    expect(game.acceptVoice(medium, VoiceMode.pitch), isTrue);
    expect(game.grit, Grit.coarse);
    expect(game.sample, same(medium));
    game.reset();
    expect(game.voiceProfile, VoiceProfile.female);
    game.setVoiceProfile(VoiceProfile.male);
    game.select(materials.last);
    game.acceptVoice(medium, VoiceMode.pitch);
    expect(game.grit, Grit.medium);
  });

  test('material thresholds agree with appearance and finish', () {
    for (final material in materials) {
      expect(material.stages.first.threshold, 0.0);
      expect(material.progressAt(material.initialValue), 0.0);
      for (final stage in material.stages) {
        final progress = stage.threshold;
        expect(material.stageAt(progress), stage);
        if (progress > 0) {
          expect(material.stageAt(progress - 0.0001), isNot(stage));
        }
        expect(material.colorAt(progress), stage.color);
        expect(material.rustAt(progress), stage.rust);
        expect(material.shineAt(progress), stage.shine);
      }
      expect(material.rustAt(0.1), lessThan(material.rustAt(0.0)));
      expect(material.shineAt(0.1), greaterThan(material.shineAt(0.0)));
    }
  });

  test('roughness and finish both shape the vibration', () {
    for (final grit in Grit.values) {
      final early = pulseFor(grit, 0.1);
      final late = pulseFor(grit, 0.9);
      expect(late.amplitude, lessThan(early.amplitude));
      expect(late.durationMs, lessThan(early.durationMs));
    }
    for (final progress in [0.0, 0.5, 1.0]) {
      final pulses = Grit.values
          .map((grit) => pulseFor(grit, progress))
          .toList();
      expect(pulses[1].amplitude, lessThan(pulses[0].amplitude));
      expect(pulses[2].durationMs, lessThan(pulses[1].durationMs));
    }
  });

  testWidgets('medal reaches gold early and fine grit brings out its shine', (
    tester,
  ) async {
    final game = GameController()..select(materials.first);
    addTearDown(game.dispose);
    game.acceptVoice(coarse, VoiceMode.pitch);
    game.startPolishing();
    for (var i = 1; i <= 22; i++) {
      game.stroke();
      if (i < 6) expect(game.stage.name, 'サビた銅メダル');
      if (i >= 6 && i < 14) expect(game.stage.name, '銅メダル');
      if (i >= 14 && i < 22) expect(game.stage.name, '銀メダル');
    }
    expect(game.stage.name, '金メダル');
    expect(game.progress, .50);
    expect(game.finishingWithFine, isTrue);
    final earlyGold = materials.first.shineAt(game.progress);
    for (var i = 0; i < 124; i++) {
      game.stroke();
    }
    expect(game.progress, .70);
    await tester.pump(const Duration(seconds: 10));
    game.acceptVoice(medium, VoiceMode.pitch);
    game.startPolishing();
    for (var i = 0; i < 100; i++) {
      game.stroke();
    }
    expect(game.progress, .85);
    expect(
      materials.first.valueAfterStroke(game.value, Grit.coarse),
      game.value,
    );
    await tester.pump(const Duration(seconds: 10));
    game.acceptVoice(fine, VoiceMode.pitch);
    game.startPolishing();
    for (var i = 0; i < 4; i++) {
      game.stroke();
      expect(game.stage.name, '金メダル');
    }
    game.stroke();
    expect(game.stage.name, '金ピカのメダル');
    expect(game.finishingWithFine, isFalse);
    expect(
      materials.first.valueAfterStroke(game.value, Grit.coarse),
      game.value,
    );
    game.stroke();
    expect(game.progress, closeTo(.85 + 6 * .50 / 22, 1e-12));
    game.stroke();
    expect(game.progress, 1.0);
    expect(materials.first.shineAt(game.progress), greaterThan(earlyGold));
    await tester.pump(const Duration(seconds: 10));
    expect(game.phase, GamePhase.result);
    expect(game.stage.name, '金ピカのメダル');
  });

  test('steady polishing reveals gold and fine grit can finish it', () {
    final medal = materials.first;
    for (final (strokes, name, progress) in [
      (16, '金メダル', .93181818),
      (17, '金ピカのメダル', .97727273),
    ]) {
      var value = medal.initialValue;
      for (final grit in Grit.values) {
        for (var i = 0; i < strokes; i++) {
          value = medal.valueAfterStroke(value, grit);
        }
      }
      final actual = medal.progressAt(value);
      expect(actual, closeTo(progress, 1e-7));
      expect(medal.stageAt(actual).name, name);
    }
  });

  test(
    'every selectable target reaches gold on exactly the requested stroke',
    () {
      final medal = materials.first;
      for (
        var n = GameController.minStrokesToGold;
        n <= GameController.maxStrokesToGold;
        n++
      ) {
        var value = medal.initialValue;
        for (var i = 0; i < n; i++) {
          expect(
            medal.progressAt(value),
            lessThan(.5),
            reason: 'target $n, stroke $i',
          );
          value = medal.valueAfterStroke(value, Grit.coarse, strokesToGold: n);
        }
        expect(
          medal.stageAt(medal.progressAt(value)).name,
          '金メダル',
          reason: 'target $n',
        );
        expect(medal.progressAt(value), .5);
      }
    },
  );

  testWidgets(
    'stroke setting scales both surfaces and stays fixed through a play',
    (tester) async {
      final game = GameController();
      addTearDown(game.dispose);
      expect(game.strokesToGold, 22);
      game.setStrokesToGold(4);
      game.setStrokesToGold(61);
      expect(game.strokesToGold, 22);
      game.setStrokesToGold(10);
      for (final material in materials) {
        game.select(material);
        game.setStrokesToGold(60);
        game.acceptVoice(coarse, VoiceMode.pitch);
        game.startPolishing();
        for (var i = 0; i < 10; i++) {
          game.stroke();
        }
        expect(game.progress, .5);
        await tester.pump(GameController.polishDuration);
        game.acceptVoice(fine, VoiceMode.pitch);
        game.startPolishing();
        game.stroke();
        final expected = material.id == 'medal' ? .55 : .5 + .05 * 1.25 / 3.5;
        expect(game.progress, closeTo(expected, 1e-12));
        await tester.pump(GameController.polishDuration);
        game.acceptVoice(coarse, VoiceMode.pitch);
        game.startPolishing();
        game.stroke();
        final finalStep = material.id == 'medal' ? .05 * 2.5 / 3.5 : .05;
        expect(game.progress, closeTo(expected + finalStep, 1e-12));
        game.reset();
        expect(game.strokesToGold, 10);
        expect(game.totalStrokes, 0);
      }
    },
  );

  for (final material in materials) {
    testWidgets(
      '${material.id} keeps the polished finish (or its guaranteed floor) through three rounds and replay',
      (tester) async {
        final game = GameController();
        addTearDown(game.dispose);
        game.select(material);
        const voices = [coarse, medium, fine];
        var expectedValue = material.initialValue;
        for (var i = 0; i < voices.length; i++) {
          expect(game.round, i + 1);
          expect(game.phase, GamePhase.voice);
          expect(game.stroke(), isNull);
          await tester.pump(const Duration(seconds: 12));
          expect(
            game.acceptVoice(const VoiceSample(null, 0.5), VoiceMode.pitch),
            isFalse,
          );
          expect(game.acceptVoice(voices[i], VoiceMode.pitch), isTrue);
          expect(game.acceptVoice(coarse, VoiceMode.pitch), isFalse);
          expect(game.phase, GamePhase.ready);
          await tester.pump(const Duration(seconds: 12));
          game.startPolishing();
          await tester.pump(const Duration(seconds: 3));
          game.startPolishing();
          expect(game.remainingSeconds, 7);
          expect(game.value, expectedValue);
          final pulse = game.stroke()!;
          expectedValue = material.valueAfterStroke(
            expectedValue,
            Grit.values[i],
          );
          expect(game.value, expectedValue);
          expect(game.strokes, 1);
          expect(
            pulse.amplitude,
            pulseFor(game.grit!, game.progress).amplitude,
          );
          await tester.pump(const Duration(seconds: 7));
        }
        // A material with a guaranteed finish ends at least there.
        final floor = material.finishAtLeast;
        if (floor != null && material.progressAt(expectedValue) < floor) {
          expectedValue = material.initialValue - material.maxRemoval * floor;
        }
        expect(game.phase, GamePhase.result);
        expect(game.verdict, isNull);
        if (material.id == 'medal') {
          expect(game.stage.name, '金ピカのメダル');
        }
        expect(
          game.stage,
          material.stageAt(material.progressAt(expectedValue)),
        );
        expect(game.totalStrokes, 3);
        expect(game.value, expectedValue);
        expect(game.stroke(), isNull);
        game.reset();
        expect(game.material, isNull);
        expect(game.totalStrokes, 0);
        expect(game.phase, GamePhase.select);
        game.select(material);
        expect(game.round, 1);
        expect(game.value, material.initialValue);
        expect(game.grit, isNull);
      },
    );
  }

  testWidgets(
    'foreground time resumes with its fractional second; a delayed stroke expires',
    (tester) async {
      final game = GameController()..select(materials.first);
      addTearDown(game.dispose);
      game.acceptVoice(coarse, VoiceMode.pitch);
      game.startPolishing();
      await tester.pump(const Duration(milliseconds: 2500));
      game.setPaused(true);
      await tester.pump(const Duration(minutes: 1));
      expect(game.remainingSeconds, 8);
      expect(game.stroke(), isNull);
      game.setPaused(false);
      await tester.pump(const Duration(milliseconds: 7499));
      expect(game.remainingSeconds, 1);
      expect(game.stroke(), isNotNull);
      // Delay timer dispatch, as can happen while the main isolate is busy.
      (tester.binding as AutomatedTestWidgetsFlutterBinding).elapseBlocking(
        const Duration(milliseconds: 1),
      );
      expect(game.stroke(), isNull);
      expect(game.phase, GamePhase.voice);
      expect(game.round, 2);
      expect(game.totalStrokes, 1);
    },
  );

  testWidgets('a configured judge sees the clamped final value exactly once', (
    tester,
  ) async {
    final medal = materials.first;
    final target = WorkMaterial(
      id: 'test',
      name: '試験片',
      initialValue: 50,
      maxRemoval: 12,
      targetValue: 38,
      stages: medal.stages,
    );
    var calls = 0;
    final game = GameController(
      judge: (material, value) {
        calls++;
        return value == material.targetValue ? '目標に到達' : null;
      },
    )..select(target);
    addTearDown(game.dispose);
    for (var round = 0; round < 3; round++) {
      game.acceptVoice(round == 2 ? fine : coarse, VoiceMode.pitch);
      game.startPolishing();
      for (var motion = 0; motion < 5; motion++) {
        game.stroke();
      }
      await tester.pump(const Duration(seconds: 10));
    }
    expect(game.value, 38);
    expect(game.progress, 1.0);
    expect(game.stage, target.stages.last);
    expect(game.verdict, '目標に到達');
    expect(game.totalStrokes, 15);
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
  });
}
