import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/features/constellation/painters/constellation_painter.dart';
import '../../helpers.dart';

void main() {
  test('0/1/multiple star layouts are deterministic and inside hit bounds', () {
    const size = Size(320, 360);
    expect(starPositions([], size), isEmpty);
    expect(starPositions([record(1)], size), [const Offset(160, 180)]);
    final records = [record(1), record(2), record(3)];
    final first = starPositions(records, size);
    expect(starPositions([record(1), record(2), record(3)], size), first);
    for (final position in first) {
      expect(position.dx, inInclusiveRange(24, size.width - 24));
      expect(position.dy, inInclusiveRange(24, size.height - 24));
    }
    expect(first[0].dy < first[1].dy && first[1].dy < first[2].dy, true);
  });
}
