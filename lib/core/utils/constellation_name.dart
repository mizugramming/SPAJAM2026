import '../models/emotion_type.dart';
import '../models/space_record.dart';

const _kConstellationNouns = [
  '灯',
  '波',
  '風',
  '雫',
  '橋',
  '扉',
  '道',
  '欠片',
  '花',
  '光',
];

EmotionType? _dominantEmotion(List<SpaceRecord> records) {
  if (records.isEmpty) return null;
  final counts = <EmotionType, int>{};
  for (final record in records) {
    counts[record.emotion] = (counts[record.emotion] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

// Deterministic so the same day's stars always produce the same name.
String constellationName(List<SpaceRecord> records) {
  final dominant = _dominantEmotion(records);
  if (dominant == null) return '静かな星座';
  var hash = 0;
  for (final record in records) {
    for (final code in record.id.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
  }
  final noun = _kConstellationNouns[hash % _kConstellationNouns.length];
  return '${dominant.label}の$noun座';
}

String constellationDescription(List<SpaceRecord> records) {
  final dominant = _dominantEmotion(records);
  if (dominant == null) return '今日は、まだ何も語られていない。';
  return switch (dominant) {
    EmotionType.joyful => 'うれしさが、いくつも重なった夜。',
    EmotionType.calm => '穏やかな時間が、そっと集まった夜。',
    EmotionType.neutral => 'いつも通りの一日が、星になった。',
    EmotionType.tired => '疲れた心にも、小さな光がともる。',
    EmotionType.uneasy => '不安な気持ちも、夜空の一部になる。',
  };
}
