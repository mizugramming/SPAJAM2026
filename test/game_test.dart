import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';

void main() {
  test('in the last round every grit can polish the medal to 金ピカ', () {
    final medal = materials.first;
    final floor = medal.finishAtLeast!;
    for (final grit in Grit.values) {
      // Early gold: before the last round, coarse and medium still stop short.
      var value = medal.initialValue - medal.maxRemoval * .60;
      var earlier = value;
      for (var i = 0; i < 100; i++) {
        earlier = medal.valueAfterStroke(earlier, grit);
      }
      if (grit != Grit.fine) expect(medal.progressAt(earlier), lessThan(floor));

      var strokes = 0;
      while (medal.progressAt(value) < floor && strokes < 40) {
        value = medal.valueAfterStroke(value, grit, finalRound: true);
        strokes++;
      }
      expect(medal.stageAt(medal.progressAt(value)).name, '金ピカのメダル');
      expect(strokes, lessThanOrEqualTo(16), reason: grit.label);
    }
  });

  const coarse = VoiceSample(120, 0.6);
  const medium = VoiceSample(190, 0.6);
  const fine = VoiceSample(270, 0.6);

  test('pitch thresholds and explicitly selected volume fallback', () {
    for (final (hz, expected) in [
      (149.9, Grit.coarse),
      (150.0, Grit.medium),
      (229.9, Grit.medium),
      (230.0, Grit.fine),
    ]) {
      expect(classify(VoiceSample(hz, 0.6), VoiceMode.pitch), expected);
    }
    expect(classify(const VoiceSample(null, 0.8), VoiceMode.pitch), isNull);
    for (final (level, expected) in [
      (0.14, null),
      (0.15, Grit.coarse),
      (0.45, Grit.medium),
      (0.70, Grit.fine),
    ]) {
      expect(classify(VoiceSample(null, level), VoiceMode.volume), expected);
    }
    expect(
      classify(const VoiceSample(double.nan, 0.5), VoiceMode.pitch),
      isNull,
    );
    expect(classify(const VoiceSample(200, 0.0), VoiceMode.pitch), isNull);
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
    for (var i = 0; i < 10; i++) {
      game.stroke();
      if (i == 2) expect(game.stage.name, '銅メダル');
      if (i == 5) expect(game.stage.name, '銀メダル');
    }
    expect(game.stage.name, '金メダル');
    expect(game.progress, .50);
    expect(game.finishingWithFine, isTrue);
    final earlyGold = materials.first.shineAt(game.progress);
    for (var i = 0; i < 100; i++) {
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
    game.stroke();
    expect(game.stage.name, '金メダル');
    game.stroke();
    expect(game.stage.name, '金ピカのメダル');
    expect(game.finishingWithFine, isFalse);
    expect(
      materials.first.valueAfterStroke(game.value, Grit.coarse),
      game.value,
    );
    game.stroke();
    expect(game.progress, 1.0);
    expect(materials.first.shineAt(game.progress), greaterThan(earlyGold));
    await tester.pump(const Duration(seconds: 10));
    expect(game.phase, GamePhase.result);
    expect(game.stage.name, '金ピカのメダル');
  });

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
          expectedValue -= Grit.values[i].removal;
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
