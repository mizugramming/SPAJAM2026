/// 固定コース。初版はアプリ内の定義を使い、コース編集は後続。
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.goalQr,
    required this.timeLimit,
    required this.goalBonusPerMinute,
    required this.checkpoints,
  });

  final String id;
  final String name;

  /// ゴールQRに埋め込む文字列。
  final String goalQr;

  final Duration timeLimit;

  /// ゴール時の残り時間1分あたりのボーナス点。
  final int goalBonusPerMinute;

  final List<Checkpoint> checkpoints;

  Iterable<Checkpoint> get requiredCheckpoints => checkpoints.where((c) => c.required);

  Checkpoint? checkpointById(String id) {
    for (final c in checkpoints) {
      if (c.id == id) return c;
    }
    return null;
  }

  Checkpoint? checkpointByQr(String qr) {
    for (final c in checkpoints) {
      if (c.qr == qr) return c;
    }
    return null;
  }
}

class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.name,
    required this.floor,
    required this.qr,
    required this.mission,
    required this.points,
    required this.required,
  });

  final String id;
  final String name;
  final String floor;
  final String qr;

  /// 撮影ミッションの内容。AI判定にもこの文を渡す。
  final String mission;

  final int points;

  /// true: ゴールに必要な指定チェックポイント / false: 自由ミッション。
  final bool required;
}
