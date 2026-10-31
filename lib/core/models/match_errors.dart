/// MatchRepository が投げる失敗。AIの不合格は失敗ではなく JudgeRejected で返す。
sealed class MatchException implements Exception {
  const MatchException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 通信できなかった。操作は反映されていないので再試行してよい。
class NetworkFailure extends MatchException {
  const NetworkFailure([super.message = '通信に失敗しました']);
}

/// 運営・参加者の権限がない操作。
class PermissionDenied extends MatchException {
  const PermissionDenied([super.message = 'この操作の権限がありません']);
}

class NotFound extends MatchException {
  const NotFound([super.message = '見つかりません']);
}

enum MatchRule { roomNotWaiting, roomNotRunning, timeUp, wrongQr, startNotScanned, alreadyFinished, requiredNotCleared }

/// 対戦のルール上できない操作。
class MatchRuleViolation extends MatchException {
  MatchRuleViolation(this.rule) : super(_messages[rule]!);

  final MatchRule rule;

  static const _messages = {
    MatchRule.roomNotWaiting: 'このルームは受付を終了しています',
    MatchRule.roomNotRunning: '対戦が開始されていません',
    MatchRule.timeUp: '時間切れです',
    MatchRule.wrongQr: 'このコースのQRではありません',
    MatchRule.startNotScanned: '先にスタートQRを読み取ってください',
    MatchRule.alreadyFinished: 'すでにゴールしています',
    MatchRule.requiredNotCleared: '指定チェックポイントが残っています',
  };
}
