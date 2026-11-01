import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mock/mock_photo_judge.dart';
import '../../core/models/models.dart';
import '../../core/providers.dart';
import '../../core/repository/match_repository.dart';
import '../../core/ui/messages.dart';

/// 開発用：プレイヤー画面がなくても、モックの参加者を動かして運営画面を確認する。
/// モック接続のときだけ表示する（usesMockBackendProvider）。
class MockPlayerPanel extends ConsumerStatefulWidget {
  const MockPlayerPanel({super.key, required this.snapshot});

  final RoomSnapshot snapshot;

  @override
  ConsumerState<MockPlayerPanel> createState() => _MockPlayerPanelState();
}

class _MockPlayerPanelState extends ConsumerState<MockPlayerPanel> {
  /// 1x1 の PNG。モックの撮影写真として使う。
  static final _photo = Uint8List.fromList(
    base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYPj/HwAEAQH/7yMK/AAAAABJRU5ErkJggg=='),
  );

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      final result = await action();
      if (!mounted) return;
      final text = switch (result) {
        JudgePassed(:final reason, :final pointsAwarded) => '合格 +$pointsAwarded点：$reason',
        JudgeRejected(:final reason) => '不合格：$reason',
        _ => 'OK',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(mockBackendProvider);
    final s = widget.snapshot;
    final roomId = s.room.id;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        title: const Text('開発用：モック参加者'),
        subtitle: const Text('プレイヤー画面の代わりに操作します'),
        children: [
          SwitchListTile(
            title: const Text('通信失敗を再現'),
            value: backend.offline,
            onChanged: (v) => setState(() => backend.offline = v),
          ),
          if (s.room.status == RoomStatus.waiting)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('参加者を追加'),
              onTap: () => _run(() {
                final n = s.participants.length + 1;
                return backend.repositoryFor('mock-player-$n').joinRoom(roomId: roomId, displayName: 'テスト参加者$n');
              }),
            ),
          for (final p in s.participants) _playerTile(p),
        ],
      ),
    );
  }

  Widget _playerTile(Participant p) {
    final backend = ref.read(mockBackendProvider);
    final repo = backend.repositoryFor(p.userId);
    final s = widget.snapshot;
    final roomId = s.room.id;
    final cleared = s.clearsOf(p.userId).map((c) => c.checkpointId).toSet();
    final next = s.course.checkpoints.where((c) => !cleared.contains(c.id)).firstOrNull;

    Future<JudgeOutcome> submit({required bool pass}) {
      final judge = backend.judge;
      if (judge is ScriptedPhotoJudge) pass ? judge.enqueuePass() : judge.enqueueReject();
      return repo.submitPhoto(roomId: roomId, checkpointId: next!.id, photo: _photo);
    }

    return ListTile(
      title: Text(p.displayName),
      subtitle: Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: next == null ? null : () => _run(() => submit(pass: true)),
            child: Text(next == null ? '全CP済み' : '${next.name}を合格'),
          ),
          TextButton(
            onPressed: next == null ? null : () => _run(() => submit(pass: false)),
            child: const Text('不合格にする'),
          ),
          TextButton(
            onPressed: () => _run(() => repo.scanGoal(roomId: roomId, qr: s.course.goalQr)),
            child: const Text('ゴールQR'),
          ),
        ],
      ),
    );
  }
}
