import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/ui/messages.dart';

/// 運営：参加コードと参加者の待機状況、一斉開始ボタン。
class OwnerWaitingView extends ConsumerStatefulWidget {
  const OwnerWaitingView({super.key, required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  ConsumerState<OwnerWaitingView> createState() => _OwnerWaitingViewState();
}

class _OwnerWaitingViewState extends ConsumerState<OwnerWaitingView> {
  bool _starting = false;

  Future<void> _start() async {
    final s = widget.snapshot;
    final notReady = s.participants.where((p) => !p.isReady).length;
    if (notReady > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('開始しますか？'),
          content: Text('スタートQRを読んでいない参加者が$notReady人います。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('待つ')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('開始する')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _starting = true);
    try {
      await ref.read(matchRepositoryProvider).startRoom(s.room.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final theme = Theme.of(context);
    final readyCount = s.participants.where((p) => p.isReady).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(s.course.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('参加コード'),
                SelectableText(s.room.code, style: theme.textTheme.displaySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('参加者 ${s.participants.length}人（スタートQR済み $readyCount人）', style: theme.textTheme.titleSmall),
        if (s.participants.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('参加者を待っています')),
        for (final p in s.participants)
          ListTile(
            leading: Icon(
              p.isReady ? Icons.check_circle : Icons.hourglass_empty,
              color: p.isReady ? Colors.green : null,
            ),
            title: Text(p.displayName),
            subtitle: Text(p.isReady ? 'スタートQR読取済み' : 'スタートQR未読取'),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: s.participants.isEmpty || _starting ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: Text(_starting ? '開始しています…' : '全員一斉に開始'),
        ),
      ],
    );
  }
}
