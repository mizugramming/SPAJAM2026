import 'dart:collection';
import 'dart:typed_data';

import '../models/models.dart';

class PhotoVerdict {
  const PhotoVerdict({required this.passed, required this.reason});

  final bool passed;
  final String reason;
}

/// 写真のAI判定。本番は Supabase Edge Function から OpenAI を呼ぶため、アプリ側では使わない。
/// 通信できない場合は NetworkFailure を投げ、不合格（passed: false）と区別する。
abstract interface class PhotoJudge {
  Future<PhotoVerdict> judge({required Checkpoint checkpoint, required Uint8List photo});
}

/// 結果を順番に返すモック。予定がなければ合格を返す。
class ScriptedPhotoJudge implements PhotoJudge {
  final Queue<Object> _script = Queue();

  void enqueuePass([String reason = 'ミッションの対象が写っています（モック判定）']) =>
      _script.add(PhotoVerdict(passed: true, reason: reason));

  void enqueueReject([String reason = 'ミッションの対象が確認できません（モック判定）']) =>
      _script.add(PhotoVerdict(passed: false, reason: reason));

  void enqueueNetworkFailure() => _script.add(const NetworkFailure('AI判定に接続できませんでした'));

  @override
  Future<PhotoVerdict> judge({required Checkpoint checkpoint, required Uint8List photo}) async {
    if (_script.isEmpty) {
      return PhotoVerdict(passed: true, reason: '「${checkpoint.mission}」を確認しました（モック判定）');
    }
    final next = _script.removeFirst();
    if (next is NetworkFailure) throw next;
    return next as PhotoVerdict;
  }
}
