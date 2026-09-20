import 'dart:math';
import '../models/emotion_type.dart';
import '../models/space_record.dart';

/// A day's constellation: a name, a poetic one-line message, and an
/// illustration matching one of the 20 entries in the constellation book.
class ConstellationResult {
  const ConstellationResult({
    required this.name,
    required this.message,
    required this.imagePath,
  });

  final String name;
  final String message;
  final String imagePath;
}

// records must be in chronological order (as recordsOnDay already returns).
ConstellationResult createConstellationResult(List<SpaceRecord> records) {
  if (records.isEmpty) {
    return const ConstellationResult(name: '', message: '', imagePath: '');
  }

  if (records.length == 1) {
    return _createFirstStar(records.first.emotion);
  }

  if (records.length == 2) {
    return _createPairStar(records[0].emotion, records[1].emotion);
  }

  return _createNormalConstellation(records);
}

/// ==========================================
/// ⭐ 1個 → 一番星
/// ==========================================

ConstellationResult _createFirstStar(EmotionType emotion) {
  return ConstellationResult(
    name: '一番星',
    message: _firstStarMessage(emotion),
    imagePath: 'assets/constellation/first_star.png',
  );
}

String _firstStarMessage(EmotionType emotion) {
  switch (emotion) {
    case EmotionType.joyful:
      return '今日のうれしいが、ひとつ星になりました。';
    case EmotionType.calm:
      return '静かな気持ちが、ひとつ星になりました。';
    case EmotionType.neutral:
      return '何でもない今も、ひとつの星に。';
    case EmotionType.tired:
      return '今日を過ごした証を、ひとつ星に。';
    case EmotionType.uneasy:
      return '抱えていた気持ちを、ここに置いていこう。';
  }
}

/// ==========================================
/// ⭐⭐ 2個 → よりそい座
/// ==========================================

ConstellationResult _createPairStar(EmotionType first, EmotionType second) {
  return ConstellationResult(
    name: 'よりそい座',
    message: _pairMessage(first, second),
    imagePath: 'assets/constellation/yorisoi.png',
  );
}

String _pairMessage(EmotionType first, EmotionType second) {
  if (first == second) {
    switch (first) {
      case EmotionType.joyful:
        return 'ふたつのうれしいが、今日を照らしている。';
      case EmotionType.calm:
        return '静かなふたつの気持ちが、そっと寄り添った。';
      case EmotionType.neutral:
        return '何でもないふたつの時間も、今日の大切な記憶。';
      case EmotionType.tired:
        return 'ふたつの星が、今日もよく過ごしたねと寄り添っている。';
      case EmotionType.uneasy:
        return '抱えていた気持ちが、ひとりじゃない星になった。';
    }
  }
  return '違うふたつの気持ちが、今日という一日で出会った。';
}

/// ==========================================
/// ⭐⭐⭐ 3個以上
/// ==========================================

ConstellationResult _createNormalConstellation(List<SpaceRecord> records) {
  final scores = records.map((r) => _emotionScore(r.emotion)).toList();

  final first = scores.first;
  final last = scores.last;

  final maxScore = scores.reduce(max);
  final minScore = scores.reduce(min);
  final range = maxScore - minScore;

  // 雨上がり座: 低い気分から最後に上向いた
  if (first <= 2 && last >= 4) {
    return const ConstellationResult(
      name: '雨上がり座',
      message: '曇っていた気持ちの向こうに、少し光が見えた日。',
      imagePath: 'assets/constellation/after_rain.png',
    );
  }

  // 日の出座: 最初より最後がかなり高い
  if (last - first >= 2) {
    return const ConstellationResult(
      name: '日の出座',
      message: '少しずつ、心に光が差してきた日。',
      imagePath: 'assets/constellation/sunrise.png',
    );
  }

  // ジェットコースター座: 感情差がかなり大きい
  if (range >= 4) {
    return const ConstellationResult(
      name: 'ジェットコースター座',
      message: '上がったり、下がったり。それも今日のあなた。',
      imagePath: 'assets/constellation/roller_coaster.png',
    );
  }

  // なみのり座: 上下を繰り返している
  if (_countDirectionChanges(scores) >= 2) {
    return const ConstellationResult(
      name: 'なみのり座',
      message: '揺れる気持ちの波を、今日もひとつ越えてきた。',
      imagePath: 'assets/constellation/wave.png',
    );
  }

  final average = scores.reduce((a, b) => a + b) / scores.length;

  // 太陽座: 全体的に明るい
  if (average >= 4.3) {
    return const ConstellationResult(
      name: '太陽座',
      message: 'あたたかな気持ちが、一日を照らしていた。',
      imagePath: 'assets/constellation/sun.png',
    );
  }

  // 雨雲座: 全体的につらい・疲れている
  if (average <= 2.0) {
    return const ConstellationResult(
      name: '雨雲座',
      message: '曇った日にも、星はちゃんとそこにいる。',
      imagePath: 'assets/constellation/rain_cloud.png',
    );
  }

  // 凪座: 感情の変化が小さい
  if (range <= 1) {
    return const ConstellationResult(
      name: '凪座',
      message: '静かな時間が、今日の心をそっと包んでいた。',
      imagePath: 'assets/constellation/calm.png',
    );
  }

  return const ConstellationResult(
    name: 'きらめき座',
    message: 'いろんな気持ちが、今日の空にきらめいた。',
    imagePath: 'assets/constellation/sparkle.png',
  );
}

/// 5 = うれしい, 4 = 穏やか, 3 = ふつう, 2 = 疲れた, 1 = つらい・不安
int _emotionScore(EmotionType emotion) {
  switch (emotion) {
    case EmotionType.joyful:
      return 5;
    case EmotionType.calm:
      return 4;
    case EmotionType.neutral:
      return 3;
    case EmotionType.tired:
      return 2;
    case EmotionType.uneasy:
      return 1;
  }
}

/// 感情の上昇・下降が何回切り替わったか
int _countDirectionChanges(List<int> scores) {
  if (scores.length < 3) return 0;

  var changes = 0;
  var previousDirection = 0;

  for (var i = 1; i < scores.length; i++) {
    final difference = scores[i] - scores[i - 1];
    if (difference == 0) continue;

    final direction = difference > 0 ? 1 : -1;
    if (previousDirection != 0 && direction != previousDirection) {
      changes++;
    }
    previousDirection = direction;
  }

  return changes;
}
