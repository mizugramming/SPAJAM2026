import 'package:flutter/material.dart';

import '../../../models/topic.dart';

/// 選ばれたネタを全員の画面に表示する。スマホを置いてリアルの会話に集中してもらうための
/// 常時表示バナー(モーダルでは閉じてしまうため使わない)。
class TopicBanner extends StatelessWidget {
  const TopicBanner({
    super.key,
    required this.topic,
    required this.canAdvance,
    required this.onNext,
  });

  final Topic topic;
  final bool canAdvance;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC4935D), Color(0xFFE8C48F), Color(0xFFC9975D)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 40, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('今回のネタ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(color: Colors.white.withAlpha(235), borderRadius: BorderRadius.circular(24)),
                child: Text(
                  topic.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              const Text('顔を上げて、みんなで話してみよう！'),
              const SizedBox(height: 32),
              if (canAdvance)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: onNext, child: const Text('次へ回す')),
                )
              else
                const Text('話し終わったら、選んだ人かホストが次へ回します', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
