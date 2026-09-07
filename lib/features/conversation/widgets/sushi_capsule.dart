import 'package:flutter/material.dart';

import '../../../models/topic.dart';

class _NetaStyle {
  const _NetaStyle(this.color);
  final Color color;
}

const _netaPalette = [
  _NetaStyle(Color(0xFFFFA98F)), // サーモン
  _NetaStyle(Color(0xFFE85D4E)), // まぐろ
  _NetaStyle(Color(0xFFFFD54F)), // たまご
  _NetaStyle(Color(0xFFFFAB91)), // えび
  _NetaStyle(Color(0xFFEDEAE0)), // いか
];

/// くら寿司のような半透明カプセルに入った寿司ネタ(話題)。タップで話題が開く。
class SushiCapsule extends StatelessWidget {
  const SushiCapsule({super.key, required this.topic, required this.onTap});

  final Topic topic;
  final VoidCallback onTap;

  Color get _netaColor => _netaPalette[topic.id.hashCode.abs() % _netaPalette.length].color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 透明な蓋
            Container(
              width: 95,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(140),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withAlpha(217), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 8, offset: const Offset(2, 5)),
                ],
              ),
            ),
            // 寿司(ネタ)
            Container(
              width: 55,
              height: 25,
              decoration: BoxDecoration(
                color: _netaColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(38), blurRadius: 3)],
              ),
            ),
            // ハイライト
            Positioned(
              top: 15,
              left: 22,
              child: Container(
                width: 25,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(166),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
