import 'dart:typed_data';

import '../models/course.dart';
import '../models/participant.dart';
import '../models/room.dart';
import '../models/room_snapshot.dart';

/// 対戦データの唯一の窓口。画面はこの契約だけを使い、保存先を直接触らない。
///
/// 失敗は MatchException（NetworkFailure / PermissionDenied / NotFound /
/// MatchRuleViolation）で投げる。AIの不合格は例外ではなく JudgeRejected。
/// 実装：モック（InMemoryMatchBackend）→ 後で Supabase 実装に差し替え。
abstract interface class MatchRepository {
  /// 匿名ログインのユーザーID。ルームの ownerId と比べて運営か参加者かを決める。
  String get currentUserId;

  Future<List<Course>> listCourses();

  // ---- 運営 ----

  Future<Room> createRoom({required String courseId});

  /// 全員一斉に開始する。開始・終了時刻はサーバーが決める。
  Future<void> startRoom(String roomId);

  /// 時間前に終了する。時間切れは自動で終了扱い（Room.statusAt）。
  Future<void> finishRoom(String roomId);

  // ---- 参加者 ----

  Future<Room> findRoomByCode(String code);

  Future<Participant> joinRoom({required String roomId, required String displayName});

  /// チェックポイントQRを読み、撮影するチェックポイントを返す。
  Future<Checkpoint> scanCheckpoint({required String roomId, required String qr});

  /// 写真を保存してAI判定し、合格なら加点する。同じチェックポイントの再合格は加点しない。
  Future<JudgeOutcome> submitPhoto({required String roomId, required String checkpointId, required Uint8List photo});

  Future<void> scanGoal({required String roomId, required String qr});

  // ---- 共通 ----

  /// ルームの状態を購読する。最初に現在の状態を1回流し、以後は変更のたびに流す。
  Stream<RoomSnapshot> watchRoom(String roomId);

  /// 写真を取得する。運営はルーム内の全員分、参加者は自分の分だけ。
  Future<Uint8List> loadPhoto({required String roomId, required String photoRef});
}

sealed class JudgeOutcome {
  const JudgeOutcome(this.reason);

  final String reason;
}

class JudgePassed extends JudgeOutcome {
  const JudgePassed(super.reason, {required this.pointsAwarded, required this.alreadyCleared});

  /// 今回加算された点数。既にクリア済みなら 0。
  final int pointsAwarded;
  final bool alreadyCleared;
}

class JudgeRejected extends JudgeOutcome {
  const JudgeRejected(super.reason);
}
