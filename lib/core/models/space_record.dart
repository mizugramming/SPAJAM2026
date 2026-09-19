import 'package:characters/characters.dart';
import 'category_type.dart';
import 'emotion_type.dart';

class SpaceRecord {
  SpaceRecord({
    required this.id,
    required this.createdAt,
    required this.emotion,
    required this.category,
    String note = '',
  }) : note = note.trim() {
    if (!_uuid.hasMatch(id)) {
      throw const FormatException('記録IDはUUIDである必要があります。');
    }
    if (this.note.characters.length > 200) {
      throw const FormatException('メモは200文字以内で入力してください。');
    }
  }
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  final String id;
  final DateTime createdAt;
  final EmotionType emotion;
  final CategoryType category;
  final String note;
  Map<String, Object> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'emotion': emotion.id,
    'category': category.id,
    'note': note,
  };
  factory SpaceRecord.fromJson(Map<String, dynamic> json) {
    try {
      return SpaceRecord(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        emotion: EmotionType.fromId(json['emotion'] as String),
        category: CategoryType.fromId(json['category'] as String),
        note: json['note'] as String,
      );
    } catch (_) {
      // Never include the stored payload or note in an error message.
      throw const FormatException('記録データを読み込めません。');
    }
  }
}
