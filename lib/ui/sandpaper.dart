import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';

// Average colour of the supplied sheet. At 190 Hz the photo keeps its own tint.
const _sand = Color(0xffc5a27b);

bool _hasPitch(double? hz) => hz != null && hz.isFinite && hz > 0;

Color sandpaperColorFor(double? hz) {
  if (!_hasPitch(hz)) return _sand;
  final pitch = hz!.clamp(65.0, 600.0);
  if (pitch <= 190) {
    return Color.lerp(const Color(0xffc68169), _sand, (pitch - 65) / 125)!;
  }
  const slate = Color(0xff9badb9);
  if (pitch <= 320) return Color.lerp(_sand, slate, (pitch - 190) / 130)!;
  return Color.lerp(slate, const Color(0xff839fae), (pitch - 320) / 280)!;
}

String sandpaperStampFor(VoiceSample sample) {
  if (_hasPitch(sample.hz)) return '${sample.hz!.round()} Hz';
  return '音量 ${(sample.level * 100).round()}%';
}

class SandpaperFace extends StatelessWidget {
  const SandpaperFace({
    super.key,
    required this.grit,
    required this.sample,
    required this.progress,
    required this.strokes,
    required this.inContact,
  });

  static const texture = AssetImage('assets/images/sandpaper_plain.webp');
  final Grit grit;
  final VoiceSample sample;
  final double progress;
  final int strokes;
  final bool inContact;

  @override
  Widget build(BuildContext context) {
    final tint = sandpaperColorFor(sample.hz);
    final stamp = sandpaperStampFor(sample);
    final sheet = ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        1,
        0,
        0,
        0,
        (tint.r - _sand.r) * 255,
        0,
        1,
        0,
        0,
        (tint.g - _sand.g) * 255,
        0,
        0,
        1,
        0,
        (tint.b - _sand.b) * 255,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: const Image(image: texture, fit: BoxFit.fill),
    );
    return Semantics(
      image: true,
      label: '${grit.label}の紙やすり、$stamp',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, frame) {
            final portrait = frame.maxHeight > frame.maxWidth;
            final fontSize = math.min(
              frame.maxWidth * .103,
              frame.maxHeight * .073,
            );
            Widget imprint(Alignment alignment, double angle) => Align(
              alignment: alignment,
              child: Transform.rotate(
                angle: angle,
                child: Text(
                  stamp,
                  maxLines: 1,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'WorkshopSans',
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                    letterSpacing: -.4,
                    color: const Color(0x68463931),
                  ),
                ),
              ),
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: portrait
                      ? Transform.flip(
                          flipX: true,
                          child: RotatedBox(quarterTurns: 3, child: sheet),
                        )
                      : sheet,
                ),
                imprint(const Alignment(-.60, -.36), -.14),
                imprint(const Alignment(.60, .05), -.14),
                imprint(const Alignment(-.36, .33), -.14),
                if (inContact && strokes > 0)
                  CustomPaint(painter: _EdgeDust(progress, grit)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// A few metal filings catch the light at the edge during contact. The motor
// carries the texture of the stroke, so the sheet itself stays still in hand.
class _EdgeDust extends CustomPainter {
  const _EdgeDust(this.progress, this.grit);
  final double progress;
  final Grit grit;

  @override
  void paint(Canvas canvas, Size size) {
    final count = 3 + (progress.clamp(0.0, 1.0) * 10).round();
    final radius = switch (grit) {
      Grit.coarse => 1.5,
      Grit.medium => 1.1,
      Grit.fine => .8,
    };
    final dust = Paint();
    for (var i = 0; i < count; i++) {
      final x = size.width * (.89 + ((i * 19) % 7) / 100);
      final y = size.height * (.55 + ((i * 23) % 28) / 100);
      dust.color = i.isEven ? const Color(0x68927a62) : const Color(0x75f4e1bf);
      canvas.drawCircle(Offset(x, y), radius, dust);
    }
  }

  @override
  bool shouldRepaint(_EdgeDust old) =>
      progress != old.progress || grit != old.grit;
}
