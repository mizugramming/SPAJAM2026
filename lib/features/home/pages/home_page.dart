import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/providers/constellation_creation_provider.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/providers/star_reminder_provider.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/constellation_creation_flow.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/planet_orb.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _reminderDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingReveal());
  }

  Future<void> _checkPendingReveal() async {
    final state = await ref.read(constellationCreationProvider.future);
    final pending = state.pendingReveal;
    if (pending == null || !mounted) return;
    final date = parseDateKey(pending);
    await ref.read(constellationCreationProvider.notifier).clearPendingReveal();
    if (date == null || !mounted) return;
    if (GoRouterState.of(context).uri.path != AppRoutes.home) return;
    context.push(AppRoutes.constellationRevealOn(date));
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final records = ref.watch(spaceRecordsProvider);
    final reminderDue = ref.watch(starReminderDueProvider);
    final createdToday =
        ref.watch(constellationCreationProvider).value?.isCreated(today) ??
        false;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    DateFormat('M月d日（E）', 'ja').format(today),
                    style: const TextStyle(
                      color: DesignTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    'Y O H A K U',
                    style: TextStyle(
                      color: DesignTokens.muted,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              if (reminderDue && !_reminderDismissed) ...[
                const SizedBox(height: 16),
                GlassPanel(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        color: DesignTokens.gold,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '星を作る時間です。\n今の気持ちを、ひとつ残しませんか？',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => context.push(AppRoutes.space),
                            child: const Text('作る'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _reminderDismissed = true),
                            child: const Text(
                              '後で',
                              style: TextStyle(color: DesignTokens.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
              const Text(
                '余 白',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 12,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'すこし、止まって。わたしを見つける。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: DesignTokens.muted,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '今日も、\n少しだけ余白を。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Center(
                child: PlanetOrb(
                  color: Color(0xFF90B8BE),
                  size: 236,
                  stage: 3,
                  seed: 8,
                  rings: true,
                ),
              ),
              records.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, _) => const ErrorState(),
                data: (all) {
                  final stars = recordsOnDay(all, today);
                  return GlassPanel(
                    child: Column(
                      children: [
                        const Text(
                          '今日の余白',
                          style: TextStyle(fontSize: 12, letterSpacing: 2),
                        ),
                        const SizedBox(height: 14),
                        if (stars.isEmpty) ...[
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: DesignTokens.gold,
                            size: 28,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'あなたのペースで、星をひとつ。',
                            style: TextStyle(
                              color: DesignTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 10,
                            children: stars
                                .take(7)
                                .map(
                                  (r) => Tooltip(
                                    message:
                                        '${r.emotion.label}・${r.category.label}',
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: r.emotion.color,
                                      size: 30,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${stars.length}つの気持ちが、星になりました。',
                            style: const TextStyle(
                              color: DesignTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.constellationOn(today)),
                          child: const Text(
                            '今日の星座を眺める  →',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => createTodayConstellationFlow(
                  context,
                  ref,
                  alreadyCreated: createdToday,
                ),
                icon: Icon(
                  createdToday
                      ? Icons.check_circle_outline
                      : Icons.auto_awesome,
                ),
                label: Text(
                  createdToday ? '今日の星座は作成ずみです' : '今日の星座を作成する',
                ),
              ),
              const SizedBox(height: 24),
              GlowButton(
                label: 'SPACE',
                onPressed: () => context.push(AppRoutes.space),
              ),
              const SizedBox(height: 12),
              const Text(
                '心に、余白を。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: DesignTokens.muted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => context.go(AppRoutes.universe),
                      icon: const Icon(Icons.public, size: 17),
                      label: const Text(
                        '宇宙を眺める',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => context.go(AppRoutes.history),
                      icon: const Icon(Icons.calendar_month_outlined, size: 17),
                      label: const Text('振り返る', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'ここに残す気持ちは、あなたの端末の中だけに。',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignTokens.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
