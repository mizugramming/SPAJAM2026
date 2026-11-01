import 'package:flutter/material.dart';

import '../features/player/player_night_style.dart';

/// プレイヤーの入口（松本担当の PlayerFlowPage）を接続するまでの仮表示。PlayerShell の中に置く。
class PlayerEntryPlaceholderPage extends StatelessWidget {
  const PlayerEntryPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'プレイヤー画面は準備中です',
          textAlign: TextAlign.center,
          style: TextStyle(color: PlayerNight.text),
        ),
      ),
    );
  }
}
