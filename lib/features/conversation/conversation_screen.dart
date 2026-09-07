import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/participant.dart';
import '../../models/room.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../result/result_screen.dart';
import 'widgets/selector_banner.dart';
import 'widgets/sushi_belt.dart';
import 'widgets/topic_banner.dart';

class ConversationScreen extends StatefulWidget {
  static const routeName = '/conversation';

  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  bool _navigatedToResult = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final room = context.read<RoomProvider>().room;
      if (room == null) return;
      context.read<ConversationProvider>().initialize(room.participants);
    });
  }

  bool _amHost(Room room, Participant myProfile) {
    return room.participants.isNotEmpty && room.participants.first.id == myProfile.id;
  }

  Future<void> _advanceRound(Room room, ConversationProvider conversation) async {
    final selectorId = room.currentSelectorId;
    if (selectorId == null) return;
    final roomProvider = context.read<RoomProvider>();

    conversation.completeRound(room: room, selectorId: selectorId);

    final nextSelector = conversation.pickNextSelector(room.participants, excludeId: selectorId);
    final updatedParticipants = [
      for (final p in room.participants)
        p.id == nextSelector.id ? p.copyWith(selectionCount: p.selectionCount + 1) : p,
    ];
    await roomProvider.updateRoom(room.copyWith(
      currentRound: room.currentRound + 1,
      currentSelectorId: nextSelector.id,
      participants: updatedParticipants,
    ));
  }

  Future<void> _endConversation(Room room) async {
    final roomProvider = context.read<RoomProvider>();
    await roomProvider.updateRoom(room.copyWith(status: RoomStatus.ended));
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomProvider>().room;
    final conversation = context.watch<ConversationProvider>();
    final myProfile = context.watch<ProfileProvider>().profile;

    if (room == null || myProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (room.status == RoomStatus.ended && !_navigatedToResult) {
      _navigatedToResult = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed(ResultScreen.routeName);
      });
    }

    final isMyTurn = room.currentSelectorId == myProfile.id;
    final isHost = _amHost(room, myProfile);
    final canAdvance = isMyTurn || isHost;
    final selectorMatches = room.participants.where((p) => p.id == room.currentSelectorId);
    final selectorName = selectorMatches.isNotEmpty ? selectorMatches.first.name : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('会輪 — ラウンド ${room.currentRound}'),
        actions: [
          if (isHost)
            TextButton(
              onPressed: () => _endConversation(room),
              child: const Text('会輪を終了', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SelectorBanner(isMyTurn: isMyTurn, selectorName: selectorName),
            Expanded(
              child: conversation.openedTopic != null
                  ? TopicBanner(
                      topic: conversation.openedTopic!,
                      canAdvance: canAdvance,
                      onNext: () => _advanceRound(room, conversation),
                    )
                  : SushiBelt(
                      topics: conversation.topics,
                      canSelect: isMyTurn,
                      speakerName: selectorName,
                      onSelectTopic: (topic) => conversation.openTopic(topic),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
