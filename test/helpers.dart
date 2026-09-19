import 'package:spajam2026/core/models/category_type.dart';
import 'package:spajam2026/core/models/emotion_type.dart';
import 'package:spajam2026/core/models/space_record.dart';
import 'package:spajam2026/core/repositories/space_repository.dart';

SpaceRecord record(
  int index, {
  DateTime? at,
  EmotionType emotion = EmotionType.tired,
  CategoryType category = CategoryType.workStudy,
  String note = '',
}) => SpaceRecord(
  id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
  createdAt: at ?? DateTime(2026, 9, 19, 10, index),
  emotion: emotion,
  category: category,
  note: note,
);

class MemoryRepository implements SpaceRepository {
  MemoryRepository([List<SpaceRecord>? initial]) : records = [...?initial];
  final List<SpaceRecord> records;
  bool failSave = false;
  bool failRead = false;
  bool failDelete = false;
  @override
  Future<List<SpaceRecord>> getAll() async {
    if (failRead) throw StateError('read failed');
    return [...records];
  }

  @override
  Future<void> save(SpaceRecord record) async {
    if (failSave) throw StateError('write failed');
    records.removeWhere((r) => r.id == record.id);
    records.add(record);
  }

  @override
  Future<void> deleteById(String id) async {
    if (failDelete) throw StateError('delete failed');
    records.removeWhere((r) => r.id == id);
  }
}
