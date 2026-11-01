import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dev/mock_player_panel.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_store.dart';
import '../../../core/ui/messages.dart';
import '../widgets/owner_progress_view.dart';
import '../widgets/owner_waiting_view.dart';

/// 運営中の記録を消してホームへ戻る。
Future<void> leaveOwnerRoom(BuildContext context, WidgetRef ref) async {
  await ref.read(sessionStoreProvider).clear();
  ref.invalidate(activeSessionProvider);
  if (context.mounted) Navigator.popUntil(context, (route) => route.isFirst);
}

/// 運営：ルームの待機・進行・結果。状態に応じて表示を切り替える。
class OwnerRoomPage extends ConsumerWidget {
  const OwnerRoomPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(roomSnapshotProvider(roomId));
    final showMockPanel = ref.watch(usesMockBackendProvider);
    return Scaffold(
      appBar: AppBar(title: Text(snapshot.whenOrNull(data: (s) => 'ルーム ${s.room.code}') ?? 'ルーム')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(describeError(e), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(roomSnapshotProvider(roomId)),
                    child: const Text('再接続'),
                  ),
                  if (e is NotFound || e is PermissionDenied)
                    TextButton(onPressed: () => leaveOwnerRoom(context, ref), child: const Text('ホームに戻る（このルームの記録を消す）')),
                ],
              ),
            ),
          ),
          data: (s) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.room.status == RoomStatus.waiting)
                OwnerWaitingView(snapshot: s)
              else
                OwnerProgressView(snapshot: s),
              if (showMockPanel) ...[const SizedBox(height: 24), MockPlayerPanel(snapshot: s)],
            ],
          ),
        ),
      ),
    );
  }
}
