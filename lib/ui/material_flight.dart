import 'package:flutter/material.dart';

/// The supplied movie, sampled front-to-front in row-major order.
const copperSpin = AssetImage('assets/images/copper_medal_spin.webp');
const materialDepartureDuration = Duration(milliseconds: 540);
const materialLandingDuration = Duration(milliseconds: 620);

class MaterialFlight extends StatelessWidget {
  const MaterialFlight({
    super.key,
    required this.materialId,
    required this.progress,
    required this.entering,
    required this.distanceToTop,
    required this.face,
  });

  final String materialId;
  final double progress;
  final bool entering;
  final double distanceToTop;
  final Widget face;

  @override
  Widget build(BuildContext context) {
    final t = progress;
    final remaining = entering
        ? 1 - Curves.easeOutCubic.transform(t)
        : Curves.easeInCubic.transform(t);
    final opacity = entering
        ? const Interval(0, .42).transform(t)
        : 1 - const Interval(.40, 1).transform(t);
    final movieOpacity = entering
        ? 1 - const Interval(.72, 1).transform(t)
        : const Interval(0, .19).transform(t);
    final frame = ((entering ? 1 + t : t) * 23 / 2).round();
    return Transform.translate(
      key: ValueKey(entering ? '$materialId-landing' : '$materialId-departure'),
      offset: Offset(0, -distanceToTop * remaining),
      child: Opacity(
        opacity: opacity,
        child: materialId != 'medal'
            ? face
            : Image(
                image: copperSpin,
                // BoxFit.none samples one 320px square from the 6-by-4 atlas.
                fit: BoxFit.none,
                alignment: Alignment(
                  (frame % 6) * 2 / 5 - 1,
                  (frame ~/ 6) * 2 / 3 - 1,
                ),
                excludeFromSemantics: true,
                frameBuilder: (context, pixels, decodedFrame, _) {
                  if (decodedFrame == null || movieOpacity == 0) return face;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (movieOpacity < 1)
                        Opacity(opacity: 1 - movieOpacity, child: face),
                      Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Opacity(
                            opacity: movieOpacity,
                            child: FittedBox(
                              child: SizedBox.square(
                                dimension: 320,
                                child: pixels,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                errorBuilder: (_, _, _) => face,
              ),
      ),
    );
  }
}
