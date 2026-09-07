import '../models/participant.dart';
import '../models/room.dart';

/// 部屋の作成・参加・状態同期の窓口。実サービス(Firestore等)に差し替える際はこれを実装する。
abstract class RoomService {
  Future<Room> createRoom({required int expectedCount, required Participant host});

  Future<Room> joinRoom({required String code, required Participant participant});

  /// 参加者の追加・準備完了・ラウンド進行・終了など、部屋の状態変更はすべてこれで反映する。
  Future<void> updateRoom(Room room);

  Stream<Room> watchRoom(String code);
}

class RoomNotFoundException implements Exception {
  const RoomNotFoundException(this.code);
  final String code;
  @override
  String toString() => '部屋番号 $code の部屋が見つかりませんでした';
}

class RoomFullException implements Exception {
  const RoomFullException(this.code);
  final String code;
  @override
  String toString() => '部屋番号 $code は満員です';
}

class RoomAlreadyStartedException implements Exception {
  const RoomAlreadyStartedException(this.code);
  final String code;
  @override
  String toString() => '部屋番号 $code はすでに会話が始まっています';
}
