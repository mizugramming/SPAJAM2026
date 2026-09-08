import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/participant.dart';
import '../models/room.dart';
import '../services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider(this._roomService);

  final RoomService _roomService;

  Room? _room;
  Room? get room => _room;

  StreamSubscription<Room>? _subscription;

  Future<Room> createRoom({
    required int expectedCount,
    required Participant host,
  }) async {
    final room = await _roomService.createRoom(
      expectedCount: expectedCount,
      host: host,
    );
    _bindTo(room.code);
    return room;
  }

  Future<Room> joinRoom(String code, Participant participant) async {
    final room = await _roomService.joinRoom(
      code: code,
      participant: participant,
    );
    _bindTo(room.code);
    return room;
  }

  Future<void> updateRoom(Room room) => _roomService.updateRoom(room);

  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _room = null;
    notifyListeners();
  }

  void _bindTo(String code) {
    _subscription?.cancel();
    _subscription = _roomService.watchRoom(code).listen((room) {
      _room = room;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
