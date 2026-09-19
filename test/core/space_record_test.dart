import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/models/emotion_type.dart';
import 'package:spajam2026/core/models/space_record.dart';
import 'package:spajam2026/core/utils/date_key.dart';
import 'package:spajam2026/core/utils/record_queries.dart';
import '../helpers.dart';

void main() {
  test('JSON preserves stable IDs, local timestamp and trimmed note', () {
    for (final emotion in EmotionType.values) {
      for (final category in CategoryType.values) {
        final original = record(
          1,
          emotion: emotion,
          category: category,
          note: '  自分の時間  ',
        );
        final restored = SpaceRecord.fromJson(original.toJson());
        expect(restored.toJson(), original.toJson());
        expect(restored.note, '自分の時間');
      }
    }
  });
  test('validates UUID and 200 user-perceived characters including emoji', () {
    expect(
      () => SpaceRecord(
        id: '',
        createdAt: DateTime.now(),
        emotion: EmotionType.calm,
        category: CategoryType.self,
      ),
      throwsFormatException,
    );
    expect(record(1, note: '🌌' * 200).note, '🌌' * 200);
    expect(() => record(1, note: 'あ' * 201), throwsFormatException);
    expect(() => EmotionType.fromId('other'), throwsFormatException);
    expect(() => CategoryType.fromId('other'), throwsFormatException);
  });
  test('malformed JSON does not expose memo text in errors', () {
    final json = record(1, note: 'private note').toJson()
      ..['emotion'] = 'invalid';
    try {
      SpaceRecord.fromJson(json);
      fail('should reject');
    } catch (error) {
      expect(error.toString(), isNot(contains('private note')));
    }
  });
  test('strict date parsing and local-day filtering sort chronologically', () {
    expect(parseDateKey('2026-02-30'), isNull);
    expect(parseDateKey('2026-9-1'), isNull);
    expect(parseDateKey('invalid'), isNull);
    expect(dateKey(parseDateKey('2026-09-19')!), '2026-09-19');
    final before = record(1, at: DateTime(2026, 9, 18, 23, 59));
    final start = record(2, at: DateTime(2026, 9, 19));
    final end = record(3, at: DateTime(2026, 9, 19, 23, 59));
    final after = record(4, at: DateTime(2026, 9, 20));
    expect(recordsOnDay([end, before, after, start], DateTime(2026, 9, 19)), [
      start,
      end,
    ]);
    final utc = DateTime.utc(2026, 9, 18, 22);
    expect(recordsOnDay([record(5, at: utc)], utc.toLocal()), hasLength(1));
  });
  test('planet growth counts every emotion equally at all boundaries', () {
    expect([0, 1, 4, 5, 14, 15, 100].map(planetStage), [0, 1, 1, 2, 2, 3, 3]);
    final records = [
      for (final e in EmotionType.values) record(e.index, emotion: e),
    ];
    final counts = categoryCounts(records);
    expect(counts[CategoryType.workStudy], 5);
    expect(counts[CategoryType.challenge], 0);
    expect(counts.length, 6);
  });
}
