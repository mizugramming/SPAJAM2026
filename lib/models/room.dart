import 'participant.dart';

enum RoomStatus { waiting, inProgress, ended }

class Room {
  const Room({
    required this.code,
    required this.expectedCount,
    this.status = RoomStatus.waiting,
    this.currentRound = 0,
    this.currentSelectorId,
    this.participants = const [],
  });

  final String code;
  final int expectedCount;
  final RoomStatus status;
  final int currentRound;
  final String? currentSelectorId;
  final List<Participant> participants;

  bool get isFull => participants.length >= expectedCount;

  Room copyWith({
    RoomStatus? status,
    int? currentRound,
    String? currentSelectorId,
    List<Participant>? participants,
  }) {
    return Room(
      code: code,
      expectedCount: expectedCount,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      currentSelectorId: currentSelectorId ?? this.currentSelectorId,
      participants: participants ?? this.participants,
    );
  }
}
