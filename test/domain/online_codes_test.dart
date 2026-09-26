import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/online_room.dart';

void main() {
  test('room QR and grouped manual input identify the same room', () {
    expect(OnlineCodes.room('tsunagun:room:ABCDEF012345'), 'ABCDEF012345');
    expect(OnlineCodes.room('abcd ef01-2345'), 'ABCDEF012345');
  });
  test(
    'pair QR is scoped to its own room, session secrets are not QR inputs',
    () {
      expect(
        OnlineCodes.pair('tsunagun:pair:ABCDEF012345:AABBCCDD', 'ABCDEF012345'),
        'AABBCCDD',
      );
      expect(OnlineCodes.pair('aabb-ccdd', 'ABCDEF012345'), 'AABBCCDD');
      for (final value in [
        'tsunagun:room:ABCDEF012345',
        'tsunagun:pair:FFFFFFFFFFFF:AABBCCDD',
        'a' * 64,
        'https://example.com/',
      ]) {
        expect(
          () => OnlineCodes.pair(value, 'ABCDEF012345'),
          throwsFormatException,
        );
      }
    },
  );
}
