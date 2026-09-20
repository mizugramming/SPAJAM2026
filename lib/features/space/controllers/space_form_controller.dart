import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/category_type.dart';
import '../../../core/models/emotion_type.dart';
import '../../../core/models/space_record.dart';

enum SpaceStep { pause, emotion, category, note, review }

class SpaceFormController extends ChangeNotifier {
  SpaceStep step = SpaceStep.pause;
  EmotionType? emotion;
  CategoryType? category;
  String note = '';
  bool saving = false;
  String? error;
  String? _recordId;
  DateTime? _createdAt;
  bool _disposed = false;
  bool get hasInput => emotion != null || category != null || note.isNotEmpty;
  bool get canSave =>
      step == SpaceStep.review &&
      emotion != null &&
      category != null &&
      !saving;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void next() {
    if (saving || step == SpaceStep.review) {
      return;
    }
    if (step == SpaceStep.emotion && emotion == null) return;
    if (step == SpaceStep.category && category == null) return;
    step = SpaceStep.values[step.index + 1];
    _changed();
  }

  void back() {
    if (saving || step.index == 0) return;
    step = SpaceStep.values[step.index - 1];
    _changed();
  }

  void selectEmotion(EmotionType value) {
    emotion = value;
    error = null;
    _changed();
  }

  void selectCategory(CategoryType value) {
    category = value;
    error = null;
    _changed();
  }

  void setNote(String value) {
    note = value;
    error = null;
    _changed();
  }

  Future<SpaceRecord?> save(Future<void> Function(SpaceRecord) persist) async {
    if (!canSave) return null;
    saving = true;
    error = null;
    _changed();
    try {
      // Reuse the ID on retries, including a successful write followed by a failed read.
      _recordId ??= const Uuid().v4();
      _createdAt ??= DateTime.now();
      final record = SpaceRecord(
        id: _recordId!,
        createdAt: _createdAt!,
        emotion: emotion!,
        category: category!,
        note: note,
      );
      await persist(record);
      emotion = null;
      category = null;
      note = '';
      return record;
    } catch (_) {
      error = '記録を保存できませんでした。入力内容はそのまま残っています。';
      return null;
    } finally {
      saving = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
