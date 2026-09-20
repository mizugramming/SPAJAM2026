import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/constellation_rarity.dart';
import '../../../core/models/emotion_type.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/utils/date_key.dart';
import '../../../core/utils/record_queries.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/record_list.dart';
import '../widgets/constellation_map.dart';
import '../widgets/rarity_badge.dart';

class ConstellationPage extends ConsumerWidget {
  const ConstellationPage({super.key, this.date});
  final DateTime? date;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final day = date ?? today;
    return PageFrame(
      eyebrow: 'YOUR CONSTELLATION',
      title: dateKey(day) == dateKey(today) ? '今日の星座' : 'あの日の星座',
      subtitle: DateFormat('yyyy年M月d日（E）', 'ja').format(day),
      children: [
        ref
            .watch(spaceRecordsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const ErrorState(),
              data: (records) {
                final stars = recordsOnDay(records, day);
                if (stars.isEmpty) {
                  return const EmptyState(message: 'この日は、静かな宇宙。');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: RarityBadge(rarity: computeRarity(stars))),
                    const SizedBox(height: 16),
                    GlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      child: ConstellationMap(records: stars),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '星にふれると、そのときの気持ちがひらきます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: DesignTokens.muted),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        for (final emotion in EmotionType.values)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                emotion.icon,
                                color: emotion.color,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                emotion.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: DesignTokens.muted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('この日に生まれた星', style: TextStyle(letterSpacing: 1)),
                    const SizedBox(height: 14),
                    RecordList(records: stars),
                  ],
                );
              },
            ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.constellationBook),
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text('星座図鑑を見る'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.history),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('ほかの日を振り返る'),
        ),
      ],
    );
  }
}
