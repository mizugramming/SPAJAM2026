import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A broad polishing pass catches the light locally while its travel
/// advances the finish of the whole metal face.
class MedalHandPolish extends StatefulWidget {
  const MedalHandPolish({
    super.key,
    required this.shinyFace,
    required this.onTravel,
  });

  final Widget shinyFace;
  final ValueChanged<double> onTravel;

  @override
  State<MedalHandPolish> createState() => _MedalHandPolishState();
}

class _MedalHandPolishState extends State<MedalHandPolish> {
  final _rubbed = <Offset>{};
  Offset? _previous;

  void _move(Offset point) {
    final previous = _previous;
    _previous = point;
    if (previous == null) return;

    // Clip the travelled segment to the illustrated disc. Dragging off the
    // medal and coming back must not polish the workbench or credit a jump.
    const center = Offset(.5, .5);
    const radius = .47;
    final delta = point - previous;
    final length = delta.distance;
    if (length <= 0) return;
    final direction = delta / length;
    final origin = previous - center;
    final along = origin.dx * direction.dx + origin.dy * direction.dy;
    final across = origin.dx * direction.dy - origin.dy * direction.dx;
    if (across.abs() >= radius) return;
    final half = math.sqrt(radius * radius - across * across);
    final start = math.max(0.0, -along - half);
    final end = math.min(length, -along + half);
    if (end <= start) return;

    // Store only distinct brush locations on a normalized grid. This keeps
    // the touched metal aligned through relayout and bounds the mask size.
    final distance = end - start;
    final samples = (distance * 36).ceil();
    for (var i = 0; i <= samples; i++) {
      final p = previous + direction * (start + distance * i / samples);
      _rubbed.add(Offset((p.dx * 48).round() / 48, (p.dy * 48).round() / 48));
    }
    setState(() {});
    widget.onTravel(distance);
  }

  @override
  Widget build(BuildContext context) => ClipOval(
    child: LayoutBuilder(
      builder: (context, bounds) {
        final diameter = bounds.maxWidth;
        return GestureDetector(
          key: const ValueKey('medal-hand-polish'),
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (d) => _previous = d.localPosition / diameter,
          onPanUpdate: (d) => _move(d.localPosition / diameter),
          onPanEnd: (_) => _previous = null,
          onPanCancel: () => _previous = null,
          child: _rubbed.isEmpty
              ? const SizedBox.expand()
              : ClipPath(
                  clipper: _BuffedMetal(_rubbed.toList()),
                  child: Opacity(opacity: .44, child: widget.shinyFace),
                ),
        );
      },
    ),
  );
}

class _BuffedMetal extends CustomClipper<Path> {
  const _BuffedMetal(this.points);
  final List<Offset> points;

  @override
  Path getClip(Size size) {
    final path = Path();
    for (final point in points) {
      path.addOval(
        Rect.fromCenter(
          center: point * size.width,
          width: size.width * .13,
          height: size.height * .095,
        ),
      );
    }
    return path;
  }

  @override
  bool shouldReclip(_BuffedMetal oldClipper) =>
      oldClipper.points.length != points.length;
}
