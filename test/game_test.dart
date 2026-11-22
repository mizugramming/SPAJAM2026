import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';

void main() {
  const coarse = VoiceSample(100);
  const medium = VoiceSample(120);
  const fine = VoiceSample(150);

  test('all grits can finish gold during the last round at the fixed pace', () {
    final medal = materials.first;
    final floor = medal.finishAtLeast!;
    for (final grit in Grit.values) {
      var value = medal.initialValue - medal.maxRemoval * .60;
      final strokes = grit == Grit.fine ? 35 : 49;
      for (var i = 0; i < strokes; i++) {
        expect(medal.progressAt(value), lessThan(floor));
        value = medal.valueAfterStroke(value, grit, finalRound: true);
      }
      expect(medal.stageAt(medal.progressAt(value)).name, '金ピカのメダル');
    }
  });

  testWidgets(
    'the medal is held at matte gold after round 1 and shines one second before the end',
    (tester) async {
      final game = GameController();
      addTearDown(game.dispose);
      for (final material in materials) {
        game.select(material);
        final held = material.afterEarlierRounds?.min ?? 0;
        expect(game.rounds, material.id == 'medal' ? 2 : 3);
        for (var round = 1; round <= game.rounds; round++) {
          final last = round == game.rounds;
          game.acceptVoice(coarse);
          game.startPolishing();
          await tester.pump(const Duration(milliseconds: 8999));
          expect(game.phase, GamePhase.polishing);
          expect(game.progress, round == 1 ? 0 : held);
          await tester.pump(const Duration(milliseconds: 1));
          // One second left in the last round: the guaranteed finish arrives.
          expect(
            game.progress,
            last && material.finishAtLeast != null
                ? material.finishAtLeast
                : (round == 1 ? 0 : held),
          );
          await tester.pump(const Duration(seconds: 1));
          if (!last) expect(game.progress, held);
        }
        expect(game.phase, GamePhase.result);
        expect(game.totalStrokes, 0);
        expect(game.progress, material.id == 'medal' ? .95 : 0);
        expect(game.surfaceProgress, game.progress);
        expect(game.needsHandPolish, isFalse);
        game.reset();
        expect(game.surfaceProgress, 0);
      }
    },
  );

  test(
    'both voice ranges include their lower boundaries and preserve demo grits',
    () {
      for (final (profile, mediumFrom, fineFrom) in [
        (VoiceProfile.low, 110.0, 135.0),
        (VoiceProfile.high, 220.0, 270.0),
      ]) {
        for (final (hz, expected) in [
          (mediumFrom - .1, Grit.coarse),
          (mediumFrom, Grit.medium),
          (fineFrom - .1, Grit.medium),
          (fineFrom, Grit.fine),
        ]) {
          expect(classify(VoiceSample(hz), profile: profile), expected);
        }
        for (final grit in Grit.values) {
          final hz = profile.demoHz(grit);
          expect(classify(VoiceSample(hz), profile: profile), grit);
        }
        for (final invalid in [
          const VoiceSample(null),
          const VoiceSample(double.nan),
          const VoiceSample(64.9),
          const VoiceSample(600.1),
        ]) {
          expect(classify(invalid, profile: profile), isNull);
        }
      }
      expect(classify(medium), Grit.medium);
      expect(
        classify(const VoiceSample(240), profile: VoiceProfile.high),
        Grit.medium,
      );
      expect(classify(fine), Grit.fine);
      expect(classify(fine, profile: VoiceProfile.high), Grit.coarse);
    },
  );

  test('a play keeps its selected voice profile and shows the original Hz', () {
    final game = GameController();
    addTearDown(game.dispose);
    expect(game.voiceProfile, VoiceProfile.low);
    game.setVoiceProfile(VoiceProfile.high);
    game.select(materials.first);
    game.setVoiceProfile(VoiceProfile.low);
    expect(game.acceptVoice(medium), isTrue);
    expect(game.grit, Grit.coarse);
    expect(game.sample, same(medium));
    game.reset();
    expect(game.voiceProfile, VoiceProfile.high);
    game.setVoiceProfile(VoiceProfile.low);
    game.select(materials.last);
    game.acceptVoice(medium);
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
    game.acceptVoice(coarse);
    game.startPolishing();
    for (var i = 1; i <= 50; i++) {
      game.stroke();
      if (i < 12) expect(game.stage.name, 'サビた銅メダル');
      if (i >= 12 && i < 30) expect(game.stage.name, '銅メダル');
      if (i >= 30 && i < 50) expect(game.stage.name, '銀メダル');
    }
    expect(game.stage.name, '金メダル');
    expect(game.progress, .50);
    expect(game.finishingWithFine, isTrue);
    final earlyGold = materials.first.shineAt(game.progress);
    for (var i = 0; i < 281; i++) {
      game.stroke();
    }
    expect(game.progress, .70);
    await tester.pump(const Duration(seconds: 10));
    // Round 2 is the last: it starts from the held matte gold.
    expect(game.round, 2);
    expect(game.progress, .70);
    expect(game.stage.name, '金メダル');
    game.acceptVoice(fine);
    game.startPolishing();
    for (var i = 0; i < 400 && game.stage.name == '金メダル'; i++) {
      game.stroke();
    }
    expect(game.stage.name, '金ピカのメダル');
    expect(game.finishingWithFine, isFalse);
    for (var i = 0; i < 400 && game.progress < 1; i++) {
      game.stroke();
    }
    expect(game.progress, 1.0);
    expect(materials.first.shineAt(game.progress), greaterThan(earlyGold));
    await tester.pump(const Duration(seconds: 10));
    expect(game.phase, GamePhase.result);
    expect(game.stage.name, '金ピカのメダル');
  });

  test('fine grit can finish gold after medium polishing', () {
    final medal = materials.first;
    var value = medal.initialValue;
    for (final (grit, count) in [
      (Grit.coarse, 50),
      (Grit.medium, 5),
      (Grit.fine, 42),
    ]) {
      for (var i = 0; i < count; i++) {
        value = medal.valueAfterStroke(value, grit);
      }
    }
    expect(medal.stageAt(medal.progressAt(value)).name, '金メダル');
    value = medal.valueAfterStroke(value, Grit.fine);
    expect(medal.stageAt(medal.progressAt(value)).name, '金ピカのメダル');
  });

  testWidgets('both materials use the fixed 50-stroke gold calibration', (
    tester,
  ) async {
    final game = GameController();
    addTearDown(game.dispose);
    for (final material in materials) {
      game.select(material);
      game.acceptVoice(coarse);
      game.startPolishing();
      for (var i = 1; i <= 50; i++) {
        game.stroke();
        expect(game.progress, closeTo(i / 100, 1e-12));
      }
      await tester.pump(GameController.polishDuration);
      game.acceptVoice(fine);
      game.startPolishing();
      game.stroke();
      if (material.id == 'medal') {
        // The medal's second round is its last: polishing moves past gold.
        expect(game.progress, greaterThan(.5));
      } else {
        final expected = .5 + .01 * 1.25 / 3.5;
        expect(game.progress, closeTo(expected, 1e-12));
        await tester.pump(GameController.polishDuration);
        game.acceptVoice(coarse);
        game.startPolishing();
        game.stroke();
        expect(game.progress, closeTo(expected + .01, 1e-12));
      }
      game.reset();
      expect(game.totalStrokes, 0);
    }
  });

  for (final material in materials) {
    testWidgets(
      '${material.id} keeps the polished finish (or its holds and floor) through its rounds and replay',
      (tester) async {
        final game = GameController();
        addTearDown(game.dispose);
        game.select(material);
        const voices = [coarse, medium, fine];
        var expectedValue = material.initialValue;
        for (var i = 0; i < material.rounds; i++) {
          expect(game.round, i + 1);
          expect(game.phase, GamePhase.voice);
          expect(game.stroke(), isNull);
          await tester.pump(const Duration(seconds: 12));
          expect(game.acceptVoice(const VoiceSample(null)), isFalse);
          expect(game.acceptVoice(voices[i]), isTrue);
          expect(game.acceptVoice(coarse), isFalse);
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
            finalRound: i == material.rounds - 1,
          );
          expect(game.value, expectedValue);
          expect(game.strokes, 1);
          expect(
            pulse.amplitude,
            pulseFor(game.grit!, game.progress).amplitude,
          );
          await tester.pump(const Duration(seconds: 7));
          // Earlier rounds may hold the finish within a range.
          if (i < material.rounds - 1) {
            if (material.afterEarlierRounds case final hold?) {
              final held = material
                  .progressAt(expectedValue)
                  .clamp(hold.min, hold.max);
              expectedValue =
                  material.initialValue - material.maxRemoval * held;
            }
          }
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
        expect(game.totalStrokes, material.rounds);
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
      game.acceptVoice(coarse);
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
      game.acceptVoice(round == 2 ? fine : coarse);
      game.startPolishing();
      for (var motion = 0; motion < 6; motion++) {
        game.stroke();
      }
      await tester.pump(const Duration(seconds: 10));
    }
    expect(game.value, 38);
    expect(game.progress, 1.0);
    expect(game.stage, target.stages.last);
    expect(game.verdict, '目標に到達');
    expect(game.totalStrokes, 18);
    await tester.pump(const Duration(seconds: 10));
    expect(calls, 1);
  });
}
