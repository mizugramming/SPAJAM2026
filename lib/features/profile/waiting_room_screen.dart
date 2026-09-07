import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../models/room.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../conversation/conversation_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  static const routeName = '/waiting-room';

  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  bool _navigated = false;

  void _maybeNavigate(Room? room) {
    if (_navigated || room == null || room.status != RoomStatus.inProgress) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed(ConversationScreen.routeName);
    });
  }

  Future<void> _startConversation(Room room) async {
    final roomProvider = context.read<RoomProvider>();
    final participants = List.of(room.participants)..shuffle();
    final firstSelector = participants.first;
    final updatedParticipants = [
      for (final p in room.participants)
        p.id == firstSelector.id ? p.copyWith(selectionCount: p.selectionCount + 1) : p,
    ];
    await roomProvider.updateRoom(room.copyWith(
      status: RoomStatus.inProgress,
      currentRound: 1,
      currentSelectorId: firstSelector.id,
      participants: updatedParticipants,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    final myProfile = context.watch<ProfileProvider>().profile;

    if (room == null || myProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _maybeNavigate(room);

    final isHost = room.participants.isNotEmpty && room.participants.first.id == myProfile.id;
    final canStart = isHost && room.participants.length >= room.expectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('部屋番号: ${room.code}'),
        actions: [
          // 臨時: 一人でのテスト用に、人数が揃っていなくても会話画面に入れるショートカット。
          // 本番前に削除するか、host限定などの制御を検討すること。
          IconButton(
            tooltip: '人数を待たずに入る(テスト用/臨時)',
            icon: const Icon(Icons.bolt),
            onPressed: () => _startConversation(room),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                '現在 ${room.participants.length} / ${room.expectedCount} 人',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (final participant in room.participants)
                      ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(participant.name),
                        subtitle: Text(participant.category.label),
                      ),
                  ],
                ),
              ),
              if (isHost)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canStart ? () => _startConversation(room) : null,
                    child: const Text('会輪をはじめる'),
                  ),
                )
              else
                const Text('ホストの開始を待っています…'),
            ],
          ),
        ),
      ),
    );
  }
}
