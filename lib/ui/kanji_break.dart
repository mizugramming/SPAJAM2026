import 'package:flutter/material.dart';

/// Five hand-staged poses of the supplied fractured glyph, held between cuts.
class KanjiBreak extends StatelessWidget {
  const KanjiBreak({super.key});

  static const atlas = AssetImage('assets/images/kanji-break.webp');
  static const frameCount = 5;
  static const frameMs = 170;
  static const duration = Duration(milliseconds: (frameCount - 1) * frameMs);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return _pose(frameCount - 1);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: duration.inMilliseconds.toDouble()),
      duration: duration,
      builder: (context, time, _) => _pose(time ~/ frameMs),
    );
  }

  Widget _pose(int index) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: FittedBox(
        child: SizedBox.square(
          dimension: 384,
          child: Image(
            key: ValueKey('kanji-fracture-$index'),
            image: atlas,
            fit: BoxFit.none,
            alignment: Alignment(-1 + 2 * index / (frameCount - 1), 0),
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}
