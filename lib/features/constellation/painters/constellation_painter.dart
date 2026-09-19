import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/space_record.dart';

List<Offset> starPositions(List<SpaceRecord> records, Size size) {
  if (records.length == 1) return [size.center(Offset.zero)];
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

class ConstellationPainter extends CustomPainter {
  ConstellationPainter(this.records);
  final List<SpaceRecord> records;
  @override
  void paint(Canvas canvas, Size size) {
    final points = starPositions(records, size);
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
      old.records != records;
}
