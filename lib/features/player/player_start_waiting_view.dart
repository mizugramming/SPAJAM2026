import 'package:flutter/material.dart';

import 'player_ui.dart';

/// Displays shared start status without running a clock or starting the game.
class PlayerStartWaitingView extends StatelessWidget {
  const PlayerStartWaitingView({
    super.key,
    required this.roomName,
    required this.playerName,
    this.startsAtLabel,
    this.remainingTimeLabel,
    this.isReconnecting = false,
    this.errorMessage,
    this.onRetry,
  });

  final String roomName;
  final String playerName;
  final String? startsAtLabel;
  final String? remainingTimeLabel;
  final bool isReconnecting;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final hasStartLabel = startsAtLabel?.trim().isNotEmpty ?? false;
    final hasRemainingLabel = remainingTimeLabel?.trim().isNotEmpty ?? false;
    final hasError = errorMessage?.trim().isNotEmpty ?? false;

    return PlayerPage(
      title: '一斉開始を待っています',
      eyebrow: 'NIGHT MISSION / STANDBY',
      description: '開始の合図をお待ちください。',
      actions: hasError && onRetry != null
          ? OutlinedButton.icon(
              onPressed: isReconnecting ? null : onRetry,
              icon: const Icon(Icons.refresh),
              label: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('もう一度確認する')),
            )
          : null,
      children: [
        PlayerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PlayerNight.raised,
                      border: Border.all(color: PlayerNight.line),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.sensors, size: 36, color: PlayerNight.lime),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (hasRemainingLabel)
                _WaitingDetail(label: '開始まで', value: remainingTimeLabel!, prominent: true)
              else
                Text(
                  '開始の合図を待機中',
                  style: theme.textTheme.headlineSmall?.copyWith(color: PlayerNight.lime, fontWeight: FontWeight.w800),
                ),
              if (hasStartLabel) ...[
                const SizedBox(height: 24),
                const Divider(height: 1),
                const SizedBox(height: 20),
                _WaitingDetail(label: '開始予定', value: startsAtLabel!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlayerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WaitingDetail(label: '参加中のルーム', value: roomName),
              const SizedBox(height: 20),
              _WaitingDetail(label: 'プレイヤー', value: playerName),
            ],
          ),
        ),
        if (isReconnecting) ...[const SizedBox(height: 16), const PlayerNotice(message: '開始状況を再確認しています…', busy: true)],
        if (hasError) ...[
          const SizedBox(height: 16),
          PlayerNotice(message: errorMessage!, icon: Icons.error_outline, isError: true),
        ],
      ],
    );
  }
}

class _WaitingDetail extends StatelessWidget {
  const _WaitingDetail({required this.label, required this.value, this.prominent = false});

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final textTheme = PlayerNight.themeOf(context).textTheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: textTheme.labelLarge?.copyWith(color: PlayerNight.muted)),
          const SizedBox(height: 8),
          Text(
            value,
            style: prominent
                ? textTheme.displayMedium?.copyWith(
                    color: PlayerNight.lime,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.2,
                  )
                : textTheme.titleLarge?.copyWith(color: PlayerNight.text, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
