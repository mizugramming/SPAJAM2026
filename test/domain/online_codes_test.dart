import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/online_room.dart';

void main() {
  test('new room codes preserve all five numeric digits including zero', () {
    expect(OnlineCodes.room('01234'), '01234');
    expect(OnlineCodes.room(' 00-123 '), '00123');
    expect(OnlineCodes.room('99999'), '99999');
    expect(OnlineCodes.room('tsunagun:room:01234'), '01234');
    for (final input in ['ABCDE', '12A45', '1234', '123456', '０１２３４']) {
      expect(() => OnlineCodes.room(input), throwsFormatException);
    }
  });
  test('pair invitations accept five-digit rooms but remain room-scoped', () {
    expect(
      OnlineCodes.pair('tsunagun:pair:01234:AABBCCDD', '01234'),
      'AABBCCDD',
    );
    expect(OnlineCodes.pair('aabb-ccdd', '01234'), 'AABBCCDD');
    for (final input in [
      'tsunagun:pair:1234:AABBCCDD',
      'tsunagun:pair:11234:AABBCCDD',
      'tsunagun:pair:01234:12345',
      'tsunagun:room:01234',
    ]) {
      expect(() => OnlineCodes.pair(input, '01234'), throwsFormatException);
    }
  });
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
