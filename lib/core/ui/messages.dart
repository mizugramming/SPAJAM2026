import '../models/match_errors.dart';

/// 画面に出すエラー文。通信失敗とそれ以外を区別して表示する。
String describeError(Object error) {
  return switch (error) {
    NetworkFailure() => '通信に失敗しました。電波を確認してもう一度お試しください',
    MatchException(:final message) => message,
    ArgumentError(:final message) => '$message',
    _ => '予期しないエラーが発生しました',
  };
}

String formatRemaining(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String formatTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
