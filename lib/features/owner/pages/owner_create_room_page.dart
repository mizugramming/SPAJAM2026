import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/models/models.dart';
import '../../../core/providers.dart';
import '../../../core/session/session_store.dart';
import '../../../core/ui/messages.dart';

/// 運営：固定コースを選んでルームを作る。
class OwnerCreateRoomPage extends ConsumerStatefulWidget {
  const OwnerCreateRoomPage({super.key});

  @override
  ConsumerState<OwnerCreateRoomPage> createState() => _OwnerCreateRoomPageState();
}

class _OwnerCreateRoomPageState extends ConsumerState<OwnerCreateRoomPage> {
  bool _creating = false;

  Future<void> _create(Course course) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final room = await ref.read(matchRepositoryProvider).createRoom(courseId: course.id);
      await ref.read(sessionStoreProvider).save(ActiveSession(role: SessionRole.owner, roomId: room.id));
      ref.invalidate(activeSessionProvider);
      if (!mounted) return;
      await Navigator.pushReplacementNamed(context, AppRoutes.ownerRoom, arguments: room.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ルームを作る')),
      body: SafeArea(
        child: courses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Retry(message: describeError(e), onRetry: () => ref.invalidate(coursesProvider)),
          data: (list) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('コースを選んでください', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final course in list)
                Card(
                  child: ListTile(
                    title: Text(course.name),
                    subtitle: Text(
                      '制限時間 ${course.timeLimit.inMinutes}分・'
                      '指定 ${course.requiredCheckpoints.length}か所・'
                      '自由 ${course.checkpoints.length - course.requiredCheckpoints.length}か所',
                    ),
                    trailing: _creating ? null : const Icon(Icons.chevron_right),
                    enabled: !_creating,
                    onTap: () => _create(course),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}
