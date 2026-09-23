import '../models/category_type.dart';
import '../models/space_record.dart';
import 'date_key.dart';

List<SpaceRecord> chronological(Iterable<SpaceRecord> records) =>
    List<SpaceRecord>.of(records)..sort((a, b) {
      final time = a.createdAt.compareTo(b.createdAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
List<SpaceRecord> recordsOnDay(Iterable<SpaceRecord> records, DateTime day) =>
    chronological(records.where((r) => dateKey(r.createdAt) == dateKey(day)));
List<SpaceRecord> recordsOnMonth(
  Iterable<SpaceRecord> records,
  DateTime month,
) => chronological(
  records.where(
    (r) => r.createdAt.year == month.year && r.createdAt.month == month.month,
  ),
);
Map<CategoryType, int> categoryCounts(Iterable<SpaceRecord> records) {
  final counts = {for (final category in CategoryType.values) category: 0};
  for (final record in records) {
    counts[record.category] = counts[record.category]! + 1;
  }
  return counts;
}

int planetStage(int count) => count == 0
    ? 0
    : count < 5
    ? 1
    : count < 15
    ? 2
    : 3;
String planetStageLabel(int count) =>
    const ['まだ眠っている惑星', '小さな惑星', '育った惑星', '豊かな惑星'][planetStage(count)];
