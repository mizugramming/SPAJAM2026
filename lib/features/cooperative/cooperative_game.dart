import 'package:flutter/material.dart';

import '../../domain/models.dart';

enum CooperativeGameResult { success, failure }

/// 協力担当の実装枠。親から渡された表示領域をそのまま使う。
///
/// self / peer を参照し、結果が確定したら onCompleted を一度だけ呼ぶ。
/// タイマー等を追加する場合は StatefulWidget にし、dispose で終了する。
/// 報酬・期限・画面遷移は親が担当する。
class CooperativeGame extends StatelessWidget {
  const CooperativeGame({
    super.key,
    required this.self,
    required this.peer,
    required this.onCompleted,
  });

  final Participant self;
  final Participant peer;
  final ValueChanged<CooperativeGameResult> onCompleted;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox.expand(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.handshake_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  '協力ゲーム準備中',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
