import 'package:flutter/material.dart';

import '../../../models/participant.dart';

/// 画面下部の「メンバー一覧」ボタン。タップすると参加メンバーと
/// 現在選択中の人が分かるシートを開く。
class MemberListButton extends StatelessWidget {
  const MemberListButton({
    super.key,
    required this.participants,
    required this.currentSelectorId,
  });

  final List<Participant> participants;
  final String? currentSelectorId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: InkWell(
        onTap: () => _showMemberList(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.black.withAlpha(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group, size: 18),
              const SizedBox(width: 6),
              Text('メンバー一覧 (${participants.length}人)'),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_up, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'メンバー一覧',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ...participants.map((participant) {
                final isSelecting = participant.id == currentSelectorId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelecting
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      participant.name.isNotEmpty ? participant.name[0] : '?',
                      style: TextStyle(
                        color: isSelecting ? Colors.white : null,
                      ),
                    ),
                  ),
                  title: Text(participant.name),
                  subtitle: Text(participant.category.label),
                  trailing: isSelecting
                      ? Chip(
                          label: const Text('選択中'),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
