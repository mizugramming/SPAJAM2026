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
  bool _isUpdatingRoom = false;

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
    return room.participants.isNotEmpty &&
        room.participants.first.id == myProfile.id;
  }

  Future<void> _advanceRound(
    Room room,
    ConversationProvider conversation,
  ) async {
    if (_isUpdatingRoom || room.participants.isEmpty) return;
    final selectorId = room.currentSelectorId;
    if (selectorId == null) return;
    setState(() => _isUpdatingRoom = true);

    final roomProvider = context.read<RoomProvider>();

    try {
      conversation.completeRound(room: room, selectorId: selectorId);

      final nextSelector = conversation.pickNextSelector(
        room.participants,
        excludeId: selectorId,
      );
      final updatedParticipants = [
        for (final participant in room.participants)
          participant.id == nextSelector.id
              ? participant.copyWith(
                  selectionCount: participant.selectionCount + 1,
                )
              : participant,
      ];
      await roomProvider.updateRoom(
        room.copyWith(
          currentRound: room.currentRound + 1,
          currentSelectorId: nextSelector.id,
          participants: updatedParticipants,
        ),
      );
    } catch (_) {
      _showError('次のラウンドへ進めませんでした。通信状態をご確認ください');
    } finally {
      if (mounted) setState(() => _isUpdatingRoom = false);
    }
  }

  Future<void> _confirmEndConversation(
    Room room,
    ConversationProvider conversation,
  ) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会輪を終了しますか？'),
        content: const Text('終了すると、参加者のプロフィールカードを表示します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );
    if (shouldEnd == true && mounted) {
      await _endConversation(room, conversation);
    }
  }

  Future<void> _endConversation(
    Room room,
    ConversationProvider conversation,
  ) async {
    if (_isUpdatingRoom) return;
    setState(() => _isUpdatingRoom = true);

    final roomProvider = context.read<RoomProvider>();
    try {
      final selectorId = room.currentSelectorId;
      if (conversation.openedTopic != null && selectorId != null) {
        conversation.completeRound(room: room, selectorId: selectorId);
      }
      await roomProvider.updateRoom(room.copyWith(status: RoomStatus.ended));
    } catch (_) {
      _showError('会輪を終了できませんでした。通信状態をご確認ください');
    } finally {
      if (mounted) setState(() => _isUpdatingRoom = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(ResultScreen.routeName);
        }
      });
    }

    final isMyTurn = room.currentSelectorId == myProfile.id;
    final isHost = _amHost(room, myProfile);
    final canAdvance = (isMyTurn || isHost) && !_isUpdatingRoom;
    final selectorMatches = room.participants.where(
      (p) => p.id == room.currentSelectorId,
    );
    final selectorName = selectorMatches.isNotEmpty
        ? selectorMatches.first.name
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('会輪 — ラウンド ${room.currentRound}'),
        actions: [
          if (isHost)
            TextButton(
              onPressed: _isUpdatingRoom
                  ? null
                  : () => _confirmEndConversation(room, conversation),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('会輪を終了'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SelectorBanner(isMyTurn: isMyTurn, selectorName: selectorName),
            Expanded(
              child: _ConversationContent(
                conversation: conversation,
                canSelect: isMyTurn,
                canAdvance: canAdvance,
                selectorName: selectorName,
                onRetry: () => conversation.initialize(room.participants),
                onNext: () => _advanceRound(room, conversation),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationContent extends StatelessWidget {
  const _ConversationContent({
    required this.conversation,
    required this.canSelect,
    required this.canAdvance,
    required this.selectorName,
    required this.onRetry,
    required this.onNext,
  });

  final ConversationProvider conversation;
  final bool canSelect;
  final bool canAdvance;
  final String selectorName;
  final VoidCallback onRetry;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (conversation.isLoading ||
        (!conversation.isInitialized &&
            conversation.initializationError == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversation.initializationError != null) {
      return _ConversationStatePanel(
        icon: Icons.cloud_off,
        message: '会話のネタを準備できませんでした',
        actionLabel: 'もう一度試す',
        onAction: onRetry,
      );
    }

    final openedTopic = conversation.openedTopic;
    if (openedTopic != null) {
      return TopicBanner(
        topic: openedTopic,
        canAdvance: canAdvance,
        onNext: onNext,
      );
    }

    if (conversation.availableTopics.isEmpty) {
      return const _ConversationStatePanel(
        icon: Icons.done_all,
        message: 'すべてのネタが回りました\nホストが会輪を終了してください',
      );
    }

    return SushiBelt(
      topics: conversation.availableTopics,
      canSelect: canSelect,
      speakerName: selectorName,
      onSelectTopic: conversation.openTopic,
    );
  }
}

class _ConversationStatePanel extends StatelessWidget {
  const _ConversationStatePanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
