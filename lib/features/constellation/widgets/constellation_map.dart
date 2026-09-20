import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/space_record.dart';
import '../../../core/widgets/record_detail.dart';
import '../painters/constellation_painter.dart';

class ConstellationMap extends StatelessWidget {
  const ConstellationMap({super.key, required this.records, this.shape});
  final List<SpaceRecord> records;

  /// The matching book entry's layout, so the day's stars trace the same
  /// silhouette as its encyclopedia entry.
  final List<Offset>? shape;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.max(260.0, records.length * 72.0);
      final size = Size(constraints.maxWidth, height);
      final positions = starPositions(records, size, shape: shape);
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: ConstellationPainter(records, shape: shape),
              ),
            ),
            for (var i = 0; i < records.length; i++)
              Positioned(
                left: positions[i].dx - 24,
                top: positions[i].dy - 24,
                child: Semantics(
                  button: true,
                  label:
                      '${DateFormat('HH:mm').format(records[i].createdAt.toLocal())} ${records[i].emotion.label} ${records[i].category.label}',
                  child: Tooltip(
                    message: records[i].emotion.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => showRecordDetail(context, records[i]),
                      child: const SizedBox.square(dimension: 48),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
