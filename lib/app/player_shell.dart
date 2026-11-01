import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/player/player_night_style.dart';

/// プレイヤー画面の外枠。各 View が見出しと濃紺の背景を持つので、ここでは戻るボタンだけを置く。
class PlayerShell extends StatelessWidget {
  const PlayerShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PlayerNight.background,
        appBar: AppBar(
          backgroundColor: PlayerNight.background,
          foregroundColor: PlayerNight.text,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 44,
        ),
        body: SafeArea(top: false, child: child),
      ),
    );
  }
}
