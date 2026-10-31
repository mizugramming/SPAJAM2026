import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/rules/match_rules.dart';
import '../../../core/ui/messages.dart';
import '../pages/owner_participant_page.dart';

/// 運営：残り時間と順位、各参加者の進行。終了後は結果として表示する。
class OwnerProgressView extends ConsumerStatefulWidget {
  const OwnerProgressView({super.key, required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  ConsumerState<OwnerProgressView> createState() => _OwnerProgressViewState();
}

class _OwnerProgressViewState extends ConsumerState<OwnerProgressView> {
  bool _finishing = false;

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('対戦を終了しますか？'),
        content: const Text('終了すると参加者は操作できなくなります。元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('続ける')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('終了する')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _finishing = true);
    try {
      await ref.read(matchRepositoryProvider).finishRoom(widget.snapshot.room.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final theme = Theme.of(context);
    final now = ref.watch(tickerProvider).value ?? DateTime.now();
    final finished = s.room.statusAt(now) == RoomStatus.finished;
    final remaining = s.room.endsAt?.difference(now) ?? Duration.zero;
    final standings = standingsOf(s);
    final requiredCount = s.course.requiredCheckpoints.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(finished ? '対戦終了' : '残り時間'),
                Text(finished ? '結果' : formatRemaining(remaining), style: theme.textTheme.displaySmall),
                Text('ゴール ${s.participants.where((p) => p.hasFinished).length} / ${s.participants.length}人'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(finished ? '最終順位（暫定ルール）' : '現在の順位（暫定ルール）', style: theme.textTheme.titleSmall),
        for (final st in standings)
          ListTile(
            leading: CircleAvatar(child: Text('${st.rank}')),
            title: Text(st.participant.displayName),
            subtitle: Text(
              '${st.score}点・指定 ${_requiredCleared(s, st.participant.userId)}/$requiredCount・'
              '${st.participant.goalAt != null ? 'ゴール ${formatTime(st.participant.goalAt!)}' : '進行中'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.ownerParticipant,
              arguments: OwnerParticipantArgs(roomId: s.room.id, userId: st.participant.userId),
            ),
          ),
        if (!finished) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _finishing ? null : _finish,
            icon: const Icon(Icons.stop),
            label: const Text('対戦を終了する'),
          ),
        ],
      ],
    );
  }

  int _requiredCleared(RoomSnapshot s, String userId) {
    final required = s.course.requiredCheckpoints.map((c) => c.id).toSet();
    return s.clearsOf(userId).where((c) => required.contains(c.checkpointId)).length;
  }
}
