import 'package:flutter/material.dart';

/// プレイヤー画面（松本担当）を接続するまでの仮画面。lib/features/player/ ができたらルートを差し替える。
class PlayerEntryPlaceholderPage extends StatelessWidget {
  const PlayerEntryPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('参加する')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('プレイヤー画面は準備中です', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
