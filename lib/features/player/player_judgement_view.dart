import 'package:flutter/material.dart';

import 'player_ui.dart';

/// 表示の切替だけに使う。AIの判定やゲームの進行状態は共通側が決定する。
enum PlayerJudgementDisplayState { processing, success, retake, error }

/// 共通側の判定結果と表示文言を受け取る、Scaffoldのbody用表示。
class PlayerJudgementView extends StatelessWidget {
  const PlayerJudgementView({
    super.key,
    required this.state,
    required this.message,
    this.awardedScoreLabel,
    this.onContinue,
    this.onRetake,
    this.onRetry,
    this.continueLabel = 'マップへ戻る',
  });

  final PlayerJudgementDisplayState state;
  final String message;

  /// 得点を計算・整形せず、そのまま表示する。
  final String? awardedScoreLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onRetake;
  final VoidCallback? onRetry;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PlayerNight.themeOf(context);
    final isProcessing = state == PlayerJudgementDisplayState.processing;
    final isError = state == PlayerJudgementDisplayState.error;
    final isSuccess = state == PlayerJudgementDisplayState.success;
    final color = isError
        ? theme.colorScheme.error
        : isSuccess
        ? PlayerNight.lime
        : PlayerNight.cyan;

    String title;
    String guidance;
    String caption;
    IconData icon;
    Widget? actions;
    switch (state) {
      case PlayerJudgementDisplayState.processing:
        title = '写真を判定中';
        caption = 'ANALYZING';
        guidance = '判定結果を確認しています。しばらくお待ちください。';
        icon = Icons.hourglass_empty;
        break;
      case PlayerJudgementDisplayState.success:
        title = 'ミッションクリア！';
        caption = 'MISSION COMPLETE';
        guidance = '達成内容を確認して、次の行動へ進みましょう。';
        icon = Icons.check_rounded;
        actions = ElevatedButton.icon(
          onPressed: onContinue,
          icon: const Icon(Icons.arrow_forward),
          label: Text(continueLabel),
        );
        break;
      case PlayerJudgementDisplayState.retake:
        title = 'もう一度撮影しよう';
        caption = 'TRY AGAIN';
        guidance = '判定理由を確認して、対象を撮り直してください。';
        icon = Icons.camera_alt_outlined;
        actions = ElevatedButton.icon(
          onPressed: onRetake,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('撮り直す'),
        );
        break;
      case PlayerJudgementDisplayState.error:
        title = '判定できませんでした';
        caption = 'ANALYSIS ERROR';
        guidance = onRetry == null ? '表示された案内を確認してください。' : '表示された案内を確認して、同じ写真で再試行できます。';
        icon = Icons.error_outline;
        actions = ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('同じ写真で再試行する'),
        );
        break;
    }

    return PlayerPage(
      title: title,
      description: guidance,
      eyebrow: caption,
      actions: actions,
      children: [
        PlayerSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              ExcludeSemantics(
                child: Center(
                  child: SizedBox(
                    width: 144,
                    height: 144,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: 0.35)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSuccess ? color : color.withValues(alpha: 0.10),
                              border: isSuccess ? null : Border.all(color: color, width: 1.5),
                            ),
                            child: Icon(icon, size: 58, color: isSuccess ? PlayerNight.ink : color),
                          ),
                        ),
                        if (isProcessing)
                          CircularProgressIndicator(strokeWidth: 2, color: color, backgroundColor: PlayerNight.line),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ExcludeSemantics(
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(color: color, letterSpacing: 2),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              ),
              if (isSuccess && awardedScoreLabel != null && awardedScoreLabel!.isNotEmpty) ...[
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.45)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ExcludeSemantics(child: Icon(Icons.bolt_rounded, color: color)),
                        const SizedBox(height: 8),
                        Text(
                          awardedScoreLabel!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (isProcessing) ...[
          const SizedBox(height: 16),
          const PlayerNotice(message: '判定が完了すると結果が表示されます。', busy: true),
        ],
        if ((state == PlayerJudgementDisplayState.success && onContinue == null) ||
            (state == PlayerJudgementDisplayState.retake && onRetake == null) ||
            (isError && onRetry == null)) ...[
          const SizedBox(height: 16),
          const PlayerNotice(message: '次の操作の準備ができるまでお待ちください。'),
        ],
      ],
    );
  }
}
