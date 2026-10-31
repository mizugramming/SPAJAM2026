import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/ui/messages.dart';

class OwnerParticipantArgs {
  const OwnerParticipantArgs({required this.roomId, required this.userId});

  final String roomId;
  final String userId;
}

/// 運営：1人の参加者のチェックポイント状況と、撮影写真・AI判定理由。
class OwnerParticipantPage extends ConsumerWidget {
  const OwnerParticipantPage({super.key, required this.args});

  final OwnerParticipantArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(roomSnapshotProvider(args.roomId));
    return Scaffold(
      appBar: AppBar(title: Text(snapshot.whenOrNull(data: (s) => s.participant(args.userId)?.displayName) ?? '参加者')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(describeError(e))),
          data: (s) => _Body(snapshot: s, userId: args.userId),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.snapshot, required this.userId});

  final RoomSnapshot snapshot;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final theme = Theme.of(context);
    final cleared = {for (final c in s.clearsOf(userId)) c.checkpointId: c};
    final submissions = s.submissionsOf(userId).reversed.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${s.scoreOf(userId)}点', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('チェックポイント', style: theme.textTheme.titleSmall),
        for (final cp in s.course.checkpoints)
          ListTile(
            dense: true,
            leading: Icon(
              cleared.containsKey(cp.id) ? Icons.check_circle : Icons.radio_button_unchecked,
              color: cleared.containsKey(cp.id) ? Colors.green : null,
            ),
            title: Text(cp.name),
            subtitle: Text('${cp.required ? '指定' : '自由'}・${cp.points}点・${cp.floor}'),
          ),
        const SizedBox(height: 16),
        Text('撮影写真とAI判定（新しい順）', style: theme.textTheme.titleSmall),
        if (submissions.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('まだ提出はありません')),
        for (final sub in submissions)
          _SubmissionCard(roomId: s.room.id, submission: sub, checkpoint: s.course.checkpointById(sub.checkpointId)),
      ],
    );
  }
}

class _SubmissionCard extends ConsumerStatefulWidget {
  const _SubmissionCard({required this.roomId, required this.submission, required this.checkpoint});

  final String roomId;
  final PhotoSubmission submission;
  final Checkpoint? checkpoint;

  @override
  ConsumerState<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends ConsumerState<_SubmissionCard> {
  late Future<Uint8List> _photo = _load();

  Future<Uint8List> _load() =>
      ref.read(matchRepositoryProvider).loadPhoto(roomId: widget.roomId, photoRef: widget.submission.photoRef);

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    final (label, color) = switch (sub.status) {
      JudgeStatus.passed => ('合格', Colors.green),
      JudgeStatus.rejected => ('不合格', Colors.red),
      JudgeStatus.pending => ('判定中', Colors.grey),
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: FutureBuilder<Uint8List>(
              future: _photo,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: () => setState(() => _photo = _load()),
                      child: Text('${describeError(snap.error!)}\nタップで再読み込み', textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                return Image.memory(
                  snap.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image)),
                );
              },
            ),
          ),
          ListTile(
            title: Text(widget.checkpoint?.name ?? sub.checkpointId),
            subtitle: Text('${formatTime(sub.submittedAt)}・${sub.reason ?? ''}'),
            trailing: Chip(
              label: Text(label),
              side: BorderSide(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
