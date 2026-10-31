import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_store.dart';
import 'routes.dart';

/// 運営か参加者かを選ぶ入口。ログイン画面は持たず、権限はルームの作成者かどうかで決まる。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('まよいクエスト（仮称）')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (session != null) ...[_ResumeCard(session: session), const SizedBox(height: 24)],
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.playerEntry),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('参加者として参加する'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.ownerCreateRoom),
                  icon: const Icon(Icons.flag),
                  label: const Text('運営としてルームを作る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 再起動前のルームに戻る。
class _ResumeCard extends ConsumerWidget {
  const _ResumeCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = session.role == SessionRole.owner;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isOwner ? '運営中のルームがあります' : '参加中のルームがあります'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pushNamed(
                context,
                isOwner ? AppRoutes.ownerRoom : AppRoutes.playerEntry,
                arguments: session.roomId,
              ),
              child: const Text('続きから'),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(sessionStoreProvider).clear();
                ref.invalidate(activeSessionProvider);
              },
              child: const Text('このルームの記録を消す'),
            ),
          ],
        ),
      ),
    );
  }
}
