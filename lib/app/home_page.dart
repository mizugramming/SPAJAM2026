import 'package:flutter/material.dart';

import 'routes.dart';

/// 運営か参加者かを選ぶ入口。ログイン画面は持たず、権限はルームの作成者かどうかで決まる。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('まよいクエスト（仮称）')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.playerEntry),
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('参加者として参加する'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.ownerCreateRoom),
                  icon: const Icon(Icons.flag),
                  label: const Text('運営としてルームを作る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
