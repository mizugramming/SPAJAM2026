# システム設計

接続・データ・状態・未確定事項。「決定」は合意済み、「暫定」は実装上の仮置きで変更前提、「未確定」は判断待ち。

## 全体（決定：Supabase / OpenAI）

```text
アプリ（運営・参加者）
  └ MatchRepository（lib/core/repository/match_repository.dart）
       ├ 今：InMemoryMatchBackend（モック。端末内だけで完結）
       └ 予定：Supabase 実装
            ├ Auth：匿名ログイン → ユーザーID
            ├ Postgres + Realtime：ルーム・参加者・クリア・提出の正本と同期
            ├ Storage：撮影写真
            └ Edge Function：写真判定（OpenAI）と加点を1回の処理で確定
```

画面は `MatchRepository` と `lib/core/providers.dart` だけを使う。Supabase 実装に替えても画面のコードは変えない。

## データ

| モデル | 主な項目 | 備考 |
|---|---|---|
| Course / Checkpoint | QR文字列、撮影ミッション、点数、指定/自由 | 初版は固定コースをアプリ内に定義 |
| Room | 参加コード、ownerId、状態（waiting/running/finished）、開始・終了時刻 | 時刻はサーバーが決める |
| Course | ゴールQR、制限時間、ゴールボーナス（残り1分あたりの点数） | |
| Participant | 名前、ゴール時刻、ゴールボーナス | 参加者×ルームで1件 |
| PhotoSubmission | 写真の参照、合否、AIの理由 | 通信失敗の提出は残さない |
| CheckpointClear | 参加者、チェックポイント、点数 | 参加者×チェックポイントで1件だけ（二重加点防止） |

得点は `CheckpointClear` の合計＋ゴールボーナス（`Participant.goalBonus`）。ゴールボーナスはゴール時にサーバーが確定し、それ以外の場所に得点を持たない。

## 共通基盤の条件と実装

- **正本：** 開始・終了時刻、クリア、ゴールはサーバー側だけが書く。モックも同じ規則で動く。
- **二重加点の防止：** クリアは参加者×チェックポイントで1件。合格判定の直後、追加する直前に既存のクリアを確認する（同時提出のテストあり）。Supabase ではテーブルに一意制約を付け、Edge Function で `insert … on conflict do nothing` を使う。
- **権限：** ログイン画面はない。匿名ログインのユーザーIDがルームの `ownerId` と一致すれば運営。運営は開始・終了・全員の写真閲覧ができる。参加者は自分の操作と自分の写真だけ。Supabase では RLS で同じ制限をかける。
- **AIの鍵：** OpenAI の鍵は Supabase の secrets に置き、Edge Function だけが使う。アプリと Git には入れない。
- **通信失敗とAI不合格：** 通信失敗は `NetworkFailure`（例外。操作は反映されないので再送してよい）。不合格は `JudgeRejected`（理由つきの結果。提出として残る）。

## 対戦の流れと規則

1. 運営が固定コースを選んでルーム作成 → 6桁の参加コードを表示。
2. 参加者がコードで参加（待機中のみ。同じ端末の再参加は同じ参加者として扱う）。
4. 運営が一斉開始 → サーバーが開始時刻と終了時刻（開始＋制限時間）を記録。
5. 参加者がチェックポイントQRを読む → 撮影 → AI判定 → 合格なら加点。
6. 指定チェックポイントを全てクリアした参加者だけがゴールQRで完了できる。ゴール時の残り時間（1分未満は切り捨て）×コースの「1分あたりの点数」をゴールボーナスとして加点する。時間切れ後はゴールできないのでボーナスなし。
7. 終了時刻を過ぎるか運営が終了すると、参加者の操作を受け付けない。

**暫定**（決まったら差し替える）
- ゴールボーナスの1分あたりの点数：仮コースは1点（ユーザー決定は「残り時間に比例」まで。点数は未確定）。
- 順位：得点の高い順 → ゴール済みが先 → ゴールが早い順。得点とゴール時刻が同じなら同順位。
- 参加者は全員のクリア状況（順位）を見られ、写真と判定理由は自分の分だけ見られる。
- 全員ゴールしても自動では終了しない（運営が終了する）。
- 仮コースの内容・点数・制限時間（30分）。
- チェックポイントQRを読まなくても、そのチェックポイントの写真を提出できる（QR読取の記録は未実装）。

## 未確定

- 順位の決め方、同点の扱い、時間切れ時にゴールしていない人の扱い。
- 開始後の途中参加を認めるか。
- 実際の固定コース（案内図・撮影対象・正解写真・QR設置場所）。
- AI判定の基準（正解写真と比べるか、ミッション文だけで判定するか）と、使うモデル・費用上限。実写真の確認では、ミッション文「案内板を撮影する」に対してポスターが合格になった。ミッション文は撮影対象が一意に決まるよう具体的に書く（例：「フロアの案内図（館内マップ）を撮影する」）。
- Supabase プロジェクトの作成者、無料枠で足りるか。

## Supabase 接続仕様（アプリ ⇔ サーバー）

アプリ側（`lib/core/supabase/`）とサーバー側（`supabase/`）はこの仕様だけで接続する。変更するときは両方の担当で合意し、この節を先に更新する。

### 認証
- アプリは起動時に匿名ログイン（`auth.signInAnonymously()`）。`auth.uid()` がユーザーID。
- 運営 = `rooms.owner_id = auth.uid()`。参加者 = `participants` に自分の行がある人。

### テーブル（public。列名は snake_case、時刻は timestamptz）

| テーブル | 列 | 制約 |
|---|---|---|
| courses | id text PK, name, goal_qr, time_limit_seconds int, goal_bonus_per_minute int | start_qr 列は使わない（残してもよい） |
| checkpoints | id text PK, course_id → courses, name, floor, qr, mission, points int, required bool, sort_order int | |
| rooms | id uuid PK, code text, course_id, owner_id uuid, status text（waiting/running/finished）, created_at, started_at, ends_at, finished_at | 進行中の code は一意 |
| participants | room_id, user_id uuid, display_name, joined_at, goal_at, goal_bonus int（既定0） | PK(room_id, user_id)。start_scanned_at 列は使わない |
| submissions | id uuid PK, room_id, participant_id uuid, checkpoint_id, photo_path, submitted_at, status text（pending/passed/rejected）, reason, judged_at | |
| checkpoint_clears | room_id, participant_id uuid, checkpoint_id, points int, cleared_at, submission_id | UNIQUE(room_id, participant_id, checkpoint_id) |

### 読み取り（RLS）
- courses / checkpoints：ログイン済みなら読める。
- rooms / participants / checkpoint_clears：そのルームの運営と参加者が読める。
- submissions：運営は全件、参加者は自分の分だけ。
- アプリからの insert / update / delete は全テーブルで禁止。書き込みは下の関数だけが行う。
- Realtime：rooms, participants, submissions, checkpoint_clears を publication に入れる。アプリは `room_id`（rooms は `id`）で絞って購読し、変更が来たら読み直す。

### 書き込み（Postgres 関数。`rpc` で呼ぶ。security definer で中で権限を確認）

| 関数 | 引数 | 戻り値 | 誰が |
|---|---|---|---|
| create_room | p_course_id | rooms の1行（json） | 誰でも（作った人が運営） |
| start_room | p_room_id | なし。started_at=now()、ends_at=now()+制限時間 | 運営 |
| finish_room | p_room_id | なし | 運営 |
| find_room_by_code | p_code | rooms の1行（json） | 誰でも |
| join_room | p_room_id, p_display_name | participants の1行（json）。再参加は既存の行を返す | 運営以外 |
| scan_checkpoint | p_room_id, p_qr | checkpoint_id（text） | 参加者 |
| scan_goal | p_room_id, p_qr | なし。goal_at=now()、goal_bonus=floor((ends_at−now())/60秒)×goal_bonus_per_minute（0未満にしない） | 参加者 |

時刻はすべてサーバーの `now()`。規則は上の「対戦の流れと規則」と `lib/core/mock/in_memory_match_backend.dart` と同じにする。

### 写真と判定
1. アプリが Storage バケット `photos`（非公開）の `{room_id}/{user_id}/{任意}.jpg` に写真を置く。参加者は自分のフォルダにだけ置ける。運営はルームの写真を全部読める。
2. アプリが Edge Function `judge-photo` を呼ぶ：`{"room_id", "checkpoint_id", "photo_path"}`。
3. Function は呼び出し元が対戦中の参加者か確認 → 写真を OpenAI で判定 → submissions に記録 → 合格なら checkpoint_clears に `on conflict do nothing` で追加。
4. 成功時（200）：`{"outcome": "passed" | "rejected", "reason": "...", "points_awarded": 0以上, "already_cleared": bool}`
5. OpenAI に接続できない・タイムアウト：503 `{"error": "judge_unavailable"}`。submissions に記録しない。
6. OpenAI の鍵は Supabase secrets（`OPENAI_API_KEY`）。

### エラーの返し方
- 関数・Function のルール違反は、`MQ:` で始まる文字列で返す。関数は `raise exception 'MQ:roomNotRunning'`、Function は 4xx の `{"error": "MQ:roomNotRunning"}`。
- コード：`MQ:permission`、`MQ:notFound`、`MQ:roomNotWaiting`、`MQ:roomNotRunning`、`MQ:timeUp`、`MQ:wrongQr`、`MQ:alreadyFinished`、`MQ:requiredNotCleared`（アプリの `MatchRule` と同じ名前）。
- それ以外の失敗は、アプリでは通信失敗として扱う。

### 未対応・注意
- checkpoints の qr 列は参加者からも読めるので、QRを読まずに値を知ることができる。初版では許容し、後で関数側の照合に寄せる。
- 端末の時計とサーバー時刻のずれは補正していない（残り時間の表示が数秒ずれる可能性）。

### 接続仕様の変更履歴
- 2026-11-01：スタートQRを廃止（ユーザー決定）。参加した時点で準備完了、運営の一斉開始で全員開始。`scan_start` 関数と `MQ:startNotScanned` を廃止し、scan_checkpoint・judge-photo・scan_goal は start_scanned_at を確認しない。ゴールボーナスを追加（courses.goal_bonus_per_minute、participants.goal_bonus、scan_goal で確定）。
  - 移行順：(1) サーバー側でスタートQRの確認を外し、列を追加（アプリの旧版も動く）→ (2) アプリの新版を test-1 にマージ。逆順だと新アプリが startNotScanned で止まる。
  - アプリは goal_bonus_per_minute・goal_bonus が無い間は 0 として読む。

## 保存・復帰

- 今のモックはメモリ上だけなので、アプリを再起動するとデータが消える。
- 端末には「役割（運営/参加者）とルームID」だけを保存する（`lib/core/session/session_store.dart`）。対戦データはサーバーから `watchRoom` で取り直す。
- Supabase の匿名ログインは端末に保持されるので、再起動しても同じユーザーIDで戻れる。
