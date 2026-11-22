import 'package:flutter_test/flutter_test.dart';
import 'package:polish_workshop/game/game.dart';
import 'package:polish_workshop/ui/workshop.dart';

void main() {
  test('grit points add up to 3..9 and pick the result character', () {
    expect(Grit.values.map(gritPoints), [3, 2, 1]);
    const expected = {
      3: ('character-success-5.webp', 'overpolished-05.png'),
      4: ('character-success-4.webp', 'overpolished-04.png'),
      5: ('character-success-4.webp', 'overpolished-04.png'),
      6: ('character-success-3.webp', 'overpolished-03.png'),
      7: ('character-success-2.webp', 'overpolished-02.png'),
      8: ('character-success-2.webp', 'overpolished-02.png'),
      9: ('character-success-1.webp', 'overpolished-01.png'),
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
      final n = int.parse(rank[0]);
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
    for (final MapEntry(key: points, value: (ok, ng)) in expected.entries) {
      expect(
        kanjiResultImage(points, KanjiOutcome.success),
        'assets/images/$ok',
        reason: '$points success',
      );
      expect(
        kanjiResultImage(points, KanjiOutcome.overPolished),
        'assets/images/$ng',
        reason: '$points failure',
      );
    }
  });

  test('an under-polished kanji shows the same character at every rank', () {
    for (var points = 3; points <= 9; points++) {
      expect(
        kanjiResultImage(points, KanjiOutcome.underPolished),
        'assets/images/character-under.webp',
      );
    }
  });

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
        expect(
          game.acceptVoice(const VoiceSample(null, .5), VoiceMode.pitch),
          isFalse,
        );
        final voice = VoiceSample(hz, .5);
        expect(game.acceptVoice(voice, VoiceMode.pitch), isTrue);
        expect(game.acceptVoice(voice, VoiceMode.pitch), isFalse);
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
