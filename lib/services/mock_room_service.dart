import 'dart:async';

import '../core/utils/room_code.dart';
import '../models/participant.dart';
import '../models/room.dart';
import 'room_service.dart';

class MockRoomService implements RoomService {
  final Map<String, Room> _rooms = {};
  final Map<String, StreamController<Room>> _controllers = {};

  @override
  Future<Room> createRoom({required int expectedCount, required Participant host}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var code = generateRoomCode();
    while (_rooms.containsKey(code)) {
      code = generateRoomCode();
    }
    final room = Room(code: code, expectedCount: expectedCount, participants: [host]);
    _rooms[code] = room;
    _emit(code);
    return room;
  }

  @override
  Future<Room> joinRoom({required String code, required Participant participant}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final room = _rooms[code];
    if (room == null) throw RoomNotFoundException(code);
    if (room.status != RoomStatus.waiting) throw RoomAlreadyStartedException(code);
    if (room.isFull) throw RoomFullException(code);
    final updated = room.copyWith(participants: [...room.participants, participant]);
    _rooms[code] = updated;
    _emit(code);
    return updated;
  }

  @override
  Future<void> updateRoom(Room room) async {
    _rooms[room.code] = room;
    _emit(room.code);
  }

  @override
  Stream<Room> watchRoom(String code) {
    final controller = _controllers.putIfAbsent(code, () => StreamController<Room>.broadcast());
    final existing = _rooms[code];
    if (existing != null) {
      scheduleMicrotask(() => controller.add(existing));
    }
    return controller.stream;
  }

  void _emit(String code) {
    final room = _rooms[code];
    if (room != null) {
      _controllers[code]?.add(room);
    }
  }
}
