import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/space_record.dart';
import '../utils/record_queries.dart';
import 'space_repository.dart';

class LocalSpaceRepository implements SpaceRepository {
  LocalSpaceRepository(this._preferences);
  static const storageKey = 'space_records_v1';
  final SharedPreferences _preferences;
  Future<void> _pending = Future<void>.value();
  // Serialize read-modify-write operations to prevent lost updates.
  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<SpaceRecord>> _read() async {
    await _preferences.reload();
    final raw = _preferences.getString(storageKey);
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw) as List<dynamic>;
      final records = json
          .map((item) => SpaceRecord.fromJson(item as Map<String, dynamic>))
          .toList();
      if (records.map((r) => r.id).toSet().length != records.length) {
        throw const FormatException();
      }
      return chronological(records);
    } catch (_) {
      // Do not overwrite unreadable data with an empty universe.
      throw const FormatException('保存済みの記録を読み込めません。');
    }
  }

  Future<void> _write(List<SpaceRecord> records) async {
    final saved = await _preferences.setString(
      storageKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
    if (!saved) throw StateError('記録を保存できませんでした。');
  }

  @override
  Future<List<SpaceRecord>> getAll() => _exclusive(_read);
  @override
  Future<void> save(SpaceRecord record) => _exclusive(() async {
    final records = await _read();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      records.add(record);
    } else {
      records[index] = record;
    }
    await _write(chronological(records));
  });
  @override
  Future<void> deleteById(String id) => _exclusive(() async {
    final records = await _read();
    records.removeWhere((record) => record.id == id);
    await _write(records);
  });
}
