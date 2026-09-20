import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/space_record.dart';

/// [shape] is the matching book entry's layout (fractional 0..1 offsets).
/// When given, the day's stars are spread evenly along that shape so the
/// constellation looks like its encyclopedia entry; otherwise they fall back
/// to a per-record deterministic layout.
List<Offset> starPositions(
  List<SpaceRecord> records,
  Size size, {
  List<Offset>? shape,
}) {
  if (records.length == 1) return [size.center(Offset.zero)];
  if (shape != null && shape.length >= 2 && records.length > 1) {
    return _positionsAlongShape(shape, records.length, size);
  }
  return List.generate(records.length, (index) {
    var hash = 0;
    for (final code in records[index].id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    final jitter = (hash % 100) / 1000 - .05;
    final x = (const [.22, .69, .35, .77][index % 4] + jitter) * size.width;
    final y = 36 + (size.height - 72) * index / math.max(1, records.length - 1);
    return Offset(x, y);
  });
}

// Walks the shape as a polyline and samples [count] evenly spaced points
// along it, so any number of records still traces the same silhouette.
List<Offset> _positionsAlongShape(List<Offset> shape, int count, Size size) {
  const inset = 30.0;
  final width = math.max(1.0, size.width - inset * 2);
  final height = math.max(1.0, size.height - inset * 2);
  final scaled = [
    for (final point in shape)
      Offset(inset + point.dx * width, inset + point.dy * height),
  ];
  final segments = <double>[];
  var total = 0.0;
  for (var i = 0; i < scaled.length - 1; i++) {
    final length = (scaled[i + 1] - scaled[i]).distance;
    segments.add(length);
    total += length;
  }
  if (total == 0) return List.filled(count, scaled.first);
  return List.generate(count, (index) {
    final target = total * index / (count - 1);
    var traveled = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final end = traveled + segments[i];
      if (target <= end || i == segments.length - 1) {
        final t = segments[i] == 0
            ? 0.0
            : ((target - traveled) / segments[i]).clamp(0.0, 1.0);
        return Offset.lerp(scaled[i], scaled[i + 1], t)!;
      }
      traveled = end;
    }
    return scaled.last;
  });
}

class ConstellationPainter extends CustomPainter {
  ConstellationPainter(this.records, {this.shape});
  final List<SpaceRecord> records;
  final List<Offset>? shape;
  @override
  void paint(Canvas canvas, Size size) {
    final points = starPositions(records, size, shape: shape);
    for (var i = 1; i < points.length; i++) {
      final paint = Paint()
        ..strokeWidth = 1
        ..shader = LinearGradient(
          colors: [
            records[i - 1].emotion.color.withValues(alpha: .6),
            records[i].emotion.color.withValues(alpha: .6),
          ],
        ).createShader(Rect.fromPoints(points[i - 1], points[i]));
      canvas.drawLine(points[i - 1], points[i], paint);
    }
    for (var i = 0; i < points.length; i++) {
      final center = points[i];
      final color = records[i].emotion.color;
      canvas.drawCircle(
        center,
        30,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .38), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: 30)),
      );
      canvas.drawCircle(center, 6, Paint()..color = color);
      canvas.drawCircle(
        center,
        3,
        Paint()..color = Colors.white.withValues(alpha: .85),
      );
      canvas.drawLine(
        center - const Offset(10, 0),
        center + const Offset(10, 0),
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = .6,
      );
      canvas.drawLine(
        center - const Offset(0, 10),
        center + const Offset(0, 10),
        Paint()
          ..color = color.withValues(alpha: .5)
          ..strokeWidth = .6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ConstellationPainter old) =>
      old.records != records || old.shape != shape;
}
