import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/emotion_type.dart';
import '../../../core/models/space_record.dart';
import '../../../core/providers/text_sentiment_provider.dart';
import '../../../core/widgets/page_frame.dart';

class MonthlyStatsPanel extends ConsumerWidget {
  const MonthlyStatsPanel({
    super.key,
    required this.month,
    required this.records,
  });

  final DateTime month;
  final List<SpaceRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentimentAsync = ref.watch(monthlyTextSentimentProvider(month));
    final sentiment = sentimentAsync.value;

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${DateFormat('M月', 'ja').format(month)}の統計',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${records.length}件の記録',
                style: const TextStyle(fontSize: 11, color: DesignTokens.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const Text(
              'この月はまだ記録がありません。',
              style: TextStyle(fontSize: 12, color: DesignTokens.muted),
            )
          else
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (final emotion in EmotionType.values)
                  _EmotionCount(
                    emotion: emotion,
                    count: records.where((r) => r.emotion == emotion).length,
                  ),
              ],
            ),
          if (sentiment != null && sentiment.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: DesignTokens.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: DesignTokens.gold,
                ),
                const SizedBox(width: 6),
                Text(
                  '文章から読み取った傾向(平均 '
                  '${sentiment.average.toStringAsFixed(1)}/5・'
                  'メモのある${sentiment.length}件)',
                  style: const TextStyle(
                    fontSize: 11,
                    color: DesignTokens.muted,
                  ),
                ),
              ],
            ),
          ] else if (sentimentAsync.isLoading) ...[
            const SizedBox(height: 14),
            const Text(
              '文章からの傾向を分析中…',
              style: TextStyle(fontSize: 11, color: DesignTokens.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmotionCount extends StatelessWidget {
  const _EmotionCount({required this.emotion, required this.count});
  final EmotionType emotion;
  final int count;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          emotion.icon,
          size: 14,
          color: active
              ? emotion.color
              : DesignTokens.muted.withValues(alpha: .4),
        ),
        const SizedBox(width: 4),
        Text(
          '${emotion.label} $count',
          style: TextStyle(
            fontSize: 11,
            color: active ? DesignTokens.ink : DesignTokens.muted,
          ),
        ),
      ],
    );
  }
}
