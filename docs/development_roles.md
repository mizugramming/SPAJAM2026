# 担当と進め方

## 担当フォルダ

| 担当 | 変更してよい場所 |
|---|---|
| 松本（プレイヤー） | `lib/features/player/`、`test/features/player/`、`assets/player/` |
| 嶋本（オーナー・共通・統合） | `lib/features/owner/`、`lib/app/`、`lib/core/`、`test/core/`、`test/features/owner/`、`pubspec.yaml`、`pubspec.lock`、`android/`、CI、資料 |

プレイヤー画面を `AppRoutes` に組み込むのは嶋本が行う。松本はプレイヤーの最初の画面のクラス名を伝える（今は `/player` が仮画面）。

## ブランチ

- 統合先は `test-1`。各自の作業ブランチから `test-1` へPRを出す。
- 同じ作業ブランチを、別の人や別のAI（Claude と Codex など）と同時に使わない。
- 取り込み：`git fetch origin` → `git merge origin/test-1`。

## プレイヤー画面からの使い方（松本向け）

画面は `lib/core/providers.dart` の Provider と `MatchRepository` だけを使う。保存先やモックを直接触らない。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mayoi_quest/core/models/models.dart';
import 'package:mayoi_quest/core/providers.dart';
import 'package:mayoi_quest/core/repository/match_repository.dart';
import 'package:mayoi_quest/core/ui/messages.dart';

// 参加
final repo = ref.read(matchRepositoryProvider);
final room = await repo.findRoomByCode(code);
await repo.joinRoom(roomId: room.id, displayName: name);

// 状態の購読（待機・開始・時間・順位はここから）
final snapshot = ref.watch(roomSnapshotProvider(roomId)); // AsyncValue<RoomSnapshot>
// snapshot.room.statusAt(now) / snapshot.course / snapshot.scoreOf(repo.currentUserId)
// 順位：standingsOf(snapshot)（lib/core/rules/match_rules.dart）

// QR
await repo.scanStart(roomId: roomId, qr: text);
final checkpoint = await repo.scanCheckpoint(roomId: roomId, qr: text);

// 撮影 → 判定
try {
  final outcome = await repo.submitPhoto(roomId: roomId, checkpointId: checkpoint.id, photo: bytes);
  switch (outcome) {
    case JudgePassed(:final pointsAwarded, :final reason): // 合格（再合格は pointsAwarded == 0）
    case JudgeRejected(:final reason): // AI不合格。撮り直しを案内
  }
} on NetworkFailure {
  // 通信失敗。同じ写真で再送できる。不合格とは別の表示にする
} on MatchException catch (e) {
  // ルール違反・権限など。describeError(e) で表示文を作れる
}

// ゴール
await repo.scanGoal(roomId: roomId, qr: text);
```

モック中に別の参加者として動かしたいときは、テストのように `InMemoryMatchBackend.repositoryFor('ユーザーID')` を使う（`test/core/in_memory_match_backend_test.dart` 参照）。運営画面の「開発用：モック参加者」パネルでも参加者を動かせる。

## 接続仕様の変更

`MatchRepository`・モデル・Provider の引数や戻り値を変えるときは、嶋本がこの資料と `system_design.md` に「変更内容・影響する画面・移行方法」を書き、松本に共有してからマージする。

## 統合の段階

1. 済：共通モデル・Repository 契約・モック・オーナー画面（作成・待機・一斉開始・進行・写真と判定理由の閲覧）。
2. 次：松本のプレイヤー画面をモックのまま `/player` に接続し、1台で一連の流れを確認。
3. Supabase 実装（匿名ログイン・テーブル・RLS・Realtime・Storage）に差し替え、2台で同期を確認。
4. Edge Function で OpenAI 判定と加点を確定。撮影・得点・ゴール・時間切れ・再起動後の復帰を複数端末で確認。
