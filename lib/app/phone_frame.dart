import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 開発中に Chrome で見るとき、画面をスマホの大きさの枠に収める。Android では何もしない。
///
/// 枠の中には MediaQuery でスマホの画面サイズを渡すので、各画面は実機と同じ大きさで配置される。
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.enabled = kIsWeb});

  final Widget child;
  final bool enabled;

  /// 一般的なスマホの論理サイズ（iPhone 14 相当）。
  static const phoneSize = Size(390, 844);
  static const _bezel = 12.0;
  static const _margin = 16.0;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final media = MediaQuery.of(context);
    // ブラウザの窓が小さいときは、縦横比を保たずに入る範囲で縮める。
    final width = math.min(phoneSize.width, media.size.width - (_bezel + _margin) * 2);
    final height = math.min(phoneSize.height, media.size.height - (_bezel + _margin) * 2);
    if (width <= 0 || height <= 0) return child;
    final screen = Size(width, height);

    return ColoredBox(
      color: const Color(0xFF2B2F36),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(_bezel),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(48),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: SizedBox.fromSize(
              size: screen,
              child: MediaQuery(
                data: media.copyWith(
                  size: screen,
                  // 実機のステータスバーとホームバーの分だけ余白を取る。
                  padding: const EdgeInsets.only(top: 44, bottom: 24),
                  viewPadding: const EdgeInsets.only(top: 44, bottom: 24),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
