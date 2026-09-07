import 'package:flutter/material.dart';

class ResultPageIndicator extends StatelessWidget {
  const ResultPageIndicator({
    super.key,
    required this.currentIndex,
    required this.pageCount,
  });

  final int currentIndex;
  final int pageCount;

  static const _vermilion = Color(0xFFE04B36);
  static const _inactive = Color(0xFFE8D8B7);
  static const _darkBrown = Color(0xFF3A2418);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${currentIndex + 1}人目、全$pageCount人',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < pageCount; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: index == currentIndex ? 22 : 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == currentIndex ? _vermilion : _inactive,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${currentIndex + 1} / $pageCount人',
            style: const TextStyle(
              color: _darkBrown,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (pageCount > 1) ...[
            const SizedBox(height: 3),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, color: _vermilion, size: 20),
                Icon(Icons.touch_app_outlined, color: _vermilion, size: 19),
                Icon(Icons.chevron_right, color: _vermilion, size: 20),
                SizedBox(width: 5),
                Text(
                  '左右にスワイプ',
                  style: TextStyle(color: _darkBrown, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
