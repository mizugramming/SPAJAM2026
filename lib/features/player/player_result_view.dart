import 'package:flutter/material.dart';

import 'player_ui.dart';

/// Result body displaying scores and ranks supplied by the common game state.
class PlayerResultView extends StatelessWidget {
  const PlayerResultView({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.scoreLabel,
    required this.rankLabel,
    required this.isFinal,
    this.scoreBreakdown = const [],
    this.rankingRows = const [],
    this.onOpenRanking,
    this.onClose,
  });

  final String title;
  final String statusLabel;
  final String scoreLabel;
  final String rankLabel;
  final bool isFinal;
  final List<Widget> scoreBreakdown;
  final List<Widget> rankingRows;
  final VoidCallback? onOpenRanking;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);

    return PlayerPage(
      title: title,
      eyebrow: 'NIGHT MISSION / REPORT',
      description: statusLabel.trim().isEmpty ? null : statusLabel,
      actions: onOpenRanking == null && onClose == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onOpenRanking != null)
                  ElevatedButton.icon(
                    onPressed: onOpenRanking,
                    icon: const Icon(Icons.leaderboard_outlined),
                    label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('ランキングを見る')),
                  ),
                if (onOpenRanking != null && onClose != null) const SizedBox(height: 12),
                if (onClose != null)
                  OutlinedButton(
                    onPressed: onClose,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('閉じる')),
                  ),
              ],
            ),
      children: [
        PlayerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: PlayerNight.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isFinal ? PlayerNight.lime : PlayerNight.cyan),
                      boxShadow: [
                        BoxShadow(
                          color: (isFinal ? PlayerNight.lime : PlayerNight.cyan).withValues(alpha: 0.10),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Icon(
                      isFinal ? Icons.emoji_events_outlined : Icons.hourglass_top,
                      size: 48,
                      color: isFinal ? PlayerNight.lime : PlayerNight.cyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isFinal ? PlayerNight.lime : PlayerNight.raised,
                      borderRadius: BorderRadius.circular(30),
                      border: isFinal ? null : Border.all(color: PlayerNight.cyan),
                    ),
                    child: Text(
                      isFinal ? '最終結果' : '仮集計',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isFinal ? PlayerNight.ink : PlayerNight.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFinal ? 'スコアと順位が確定しました。' : 'スコアと順位は確定前です。最終結果は集計完了後にご確認ください。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: PlayerNight.muted, height: 1.6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final score = PlayerMetric(label: '獲得スコア', value: scoreLabel, icon: Icons.bolt_outlined, accent: true);
            final rank = PlayerMetric(label: '順位', value: rankLabel, icon: Icons.leaderboard_outlined);
            if (constraints.maxWidth >= 500 && MediaQuery.textScalerOf(context).scale(16) <= 24) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: score),
                  const SizedBox(width: 12),
                  Expanded(child: rank),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [score, const SizedBox(height: 12), rank],
            );
          },
        ),
        if (scoreBreakdown.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _ResultHeading(label: 'スコアの内訳'),
          const SizedBox(height: 12),
          for (var index = 0; index < scoreBreakdown.length; index++) ...[
            scoreBreakdown[index],
            if (index < scoreBreakdown.length - 1) const SizedBox(height: 12),
          ],
        ],
        if (rankingRows.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _ResultHeading(label: 'ランキング'),
          const SizedBox(height: 12),
          for (var index = 0; index < rankingRows.length; index++) ...[
            rankingRows[index],
            if (index < rankingRows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      style: PlayerNight.themeOf(
        context,
      ).textTheme.titleLarge?.copyWith(color: PlayerNight.text, fontWeight: FontWeight.w800),
    ),
  );
}
