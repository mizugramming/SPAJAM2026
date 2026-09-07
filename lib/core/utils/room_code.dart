import 'dart:math';

// 0/O, 1/I/L など見間違えやすい文字を除いたアルファベット。
const _roomCodeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

String generateRoomCode({int length = 6, Random? random}) {
  final rng = random ?? Random();
  return List.generate(length, (_) => _roomCodeAlphabet[rng.nextInt(_roomCodeAlphabet.length)]).join();
}
