import 'package:flutter/material.dart';

import 'player_ui.dart';

/// Displays ranking rows in the order supplied by the common game state.
class PlayerRankingView extends StatelessWidget {
  const PlayerRankingView({
    super.key,
    required this.rows,
    this.title = 'ランキング',
    this.statusLabel,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final List<PlayerRankingRow> rows;
  final String title;
  final String? statusLabel;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final hasStatus = statusLabel?.trim().isNotEmpty ?? false;

    return PlayerPage(
      title: title,
      eyebrow: 'NIGHT MISSION / RANKING',
      actions: onRefresh == null
          ? null
          : OutlinedButton.icon(
              onPressed: isRefreshing ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(isRefreshing ? '更新中…' : 'ランキングを更新'),
              ),
            ),
      children: [
        if (hasStatus) ...[
          PlayerNotice(message: statusLabel!),
          if (isRefreshing || rows.isNotEmpty) const SizedBox(height: 16),
        ],
        if (isRefreshing) ...[
          const PlayerNotice(message: 'ランキングを更新しています…', busy: true),
          if (rows.isNotEmpty) const SizedBox(height: 16),
        ],
        if (rows.isEmpty && !hasStatus && !isRefreshing)
          const PlayerNotice(message: 'ランキングはまだありません。', icon: Icons.leaderboard_outlined),
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A presentation widget; rank and score are formatted by the caller.
class PlayerRankingRow extends StatelessWidget {
  const PlayerRankingRow({
    super.key,
    required this.rankLabel,
    required this.playerName,
    required this.scoreLabel,
    this.isCurrentPlayer = false,
  });

  final String rankLabel;
  final String playerName;
  final String scoreLabel;
  final bool isCurrentPlayer;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final accent = isCurrentPlayer ? PlayerNight.lime : PlayerNight.cyan;

    return Semantics(
      container: true,
      selected: isCurrentPlayer,
      label: '${isCurrentPlayer ? 'あなた、' : ''}$rankLabel、$playerName、$scoreLabel',
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: isCurrentPlayer ? PlayerNight.raised : PlayerNight.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isCurrentPlayer ? PlayerNight.lime : PlayerNight.line,
            width: isCurrentPlayer ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: PlayerNight.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PlayerNight.line),
                    ),
                    child: Text(
                      rankLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(color: accent, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (isCurrentPlayer)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: PlayerNight.lime, borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        'あなた',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: PlayerNight.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                playerName,
                style: theme.textTheme.titleLarge?.copyWith(color: PlayerNight.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: PlayerNight.line),
              const SizedBox(height: 12),
              Text(
                scoreLabel,
                textAlign: TextAlign.end,
                style: theme.textTheme.headlineMedium?.copyWith(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
