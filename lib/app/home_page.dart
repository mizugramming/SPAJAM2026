import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_store.dart';
import '../features/player/player_night_style.dart';
import 'routes.dart';

/// タイトル画面。参加者か運営かを選ぶ入口も兼ねる。
/// ログイン画面は持たず、権限はルームの作成者かどうかで決まる。配色はプレイヤー画面（ナイトミッション）に合わせる。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider).value;
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PlayerNight.background,
        body: Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: _MazeBackdropPainter())),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const _TitleBlock(),
                        const SizedBox(height: 48),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (session != null) ...[_ResumeCard(session: session), const SizedBox(height: 20)],
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: PlayerNight.lime,
                                foregroundColor: PlayerNight.ink,
                                minimumSize: const Size.fromHeight(56),
                                textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.playerEntry),
                              icon: const Icon(Icons.directions_walk),
                              label: const Text('参加者として参加する'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: PlayerNight.cyan,
                                side: const BorderSide(color: PlayerNight.line, width: 1.5),
                                minimumSize: const Size.fromHeight(52),
                              ),
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.ownerCreateRoom),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('運営としてルームを作る'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.explore_outlined, color: PlayerNight.lime, size: 44),
        const SizedBox(height: 20),
        Text('MAYOI QUEST', style: theme.textTheme.labelLarge?.copyWith(color: PlayerNight.cyan, letterSpacing: 4)),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(
            'まよい\nクエスト',
            style: theme.textTheme.displayMedium?.copyWith(
              color: PlayerNight.text,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '案内図を手がかりに館内を歩き、\nQRと撮影ミッションでチェックポイントを巡ろう。',
          style: theme.textTheme.bodyLarge?.copyWith(color: PlayerNight.muted, height: 1.6),
        ),
      ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PlayerNight.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlayerNight.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(isOwner ? '運営中のルームがあります' : '参加中のルームがあります', style: const TextStyle(color: PlayerNight.text)),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PlayerNight.cyan, foregroundColor: PlayerNight.ink),
              onPressed: () => Navigator.pushNamed(
                context,
                isOwner ? AppRoutes.ownerRoom : AppRoutes.playerEntry,
                arguments: session.roomId,
              ),
              child: const Text('続きから'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: PlayerNight.muted),
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

/// 館内図をイメージした方眼と、迷いながらゴールへ向かう点線の道すじ。
class _MazeBackdropPainter extends CustomPainter {
  const _MazeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = PlayerNight.line.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 寄り道しながら右上のゴールへ向かう道。
    final w = size.width, h = size.height;
    final route = [
      Offset(w * 0.12, h * 0.62),
      Offset(w * 0.12, h * 0.52),
      Offset(w * 0.38, h * 0.52),
      Offset(w * 0.38, h * 0.60),
      Offset(w * 0.62, h * 0.60),
      Offset(w * 0.62, h * 0.40),
      Offset(w * 0.48, h * 0.40),
      Offset(w * 0.48, h * 0.30),
      Offset(w * 0.82, h * 0.30),
      Offset(w * 0.82, h * 0.16),
    ];
    final dash = Paint()
      ..color = PlayerNight.cyan.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < route.length - 1; i++) {
      _dashedLine(canvas, route[i], route[i + 1], dash);
    }
    canvas.drawCircle(route.first, 5, Paint()..color = PlayerNight.cyan.withValues(alpha: 0.6));
    canvas.drawCircle(route.last, 9, Paint()..color = PlayerNight.lime.withValues(alpha: 0.25));
    canvas.drawCircle(route.last, 4, Paint()..color = PlayerNight.lime.withValues(alpha: 0.8));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 6.0, gap = 6.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    for (var d = 0.0; d < total; d += dashLength + gap) {
      final end = d + dashLength < total ? d + dashLength : total;
      canvas.drawLine(a + dir * d, a + dir * end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MazeBackdropPainter oldDelegate) => false;
}
