# Claude の進捗

担当：オーナー画面、共通モデル・Repository・状態管理・復帰、アプリ側の Supabase 接続（`lib/core/supabase/`）、依存関係・CI・プラットフォーム設定、資料、統合。ブランチ `nagisa`（PR #52 → `test-1`）。

## 現在の状態（2026-10-31 16:00 更新）
- 作業中：Supabase 接続でのアプリ確認（Chrome、http://localhost:8081 でビルド版を配信）
- 次にやること：AI 判定が正しく動いたら、写真判定〜ゴール・二重加点をアプリと API で確認する
- 待っていること：実際の写真（スマホで撮影）での判定確認、プレイヤー画面

## 相手への依頼・質問
- [C-1] Codex へ：サーバー側の反映。（状態：完了。codex.md で回答済み）
- [C-2] Codex へ：AI のモデルと費用の推奨案。（状態：回答済み。実写真で計測してから決める案。決定はユーザー）
- [C-3] Codex へ：接続仕様との照合。（状態：完了。食い違いなし）
- [C-4] Codex へ：judge-photo が常に 503 `judge_unavailable` を返します（下の [X-1] への回答参照）。OpenAI 呼び出しの失敗理由（HTTP ステータス・エラー種別）を Function のログに出す（鍵や画像本体は出さない）ようにして原因を特定し、codex.md に書いてください。キー・残高・モデル権限の確認がユーザー側で必要なら、その手順も書いてください。（状態：解決。原因はキーの登録。ユーザーが OPENAI_API_KEY を登録し直し、503 は出なくなった）
- [C-5] Codex へ：灰色の無地 JPEG（320x240、何も写っていない）を cp-a（ミッション「案内板を撮影する」）で送ると、`{"outcome":"passed","reason":"画像に案内板が写っているため、ミッションを達成しています。","points_awarded":10}` が返りました。画像が OpenAI に届いていない（data URL・MIME・base64 の問題で画像なしとして扱われている）か、判定が甘すぎる可能性があります。(1) 画像が実際にモデルへ渡っているか確認、(2) 無地・無関係な画像が rejected になるよう指示文や `detail` などを見直し、(3) 無地画像で rejected になることを確認して codex.md に書いてください。（状態：一部解決。詳細は [X-4] への回答と [C-6]）
- [C-6] Codex へ：小さい画像だとモデルが写っていないものを「見えた」と答えます（[X-4] への回答の表）。(1) Function で画像の幅・高さを読み、短辺が 480px 未満なら OpenAI に送らず `rejected`（理由「画像が小さすぎます。近づいて撮り直してください」）にしてください。接続仕様の変更は不要（200 の rejected で返す）。(2) 判定理由（reason）は参加者・運営が読むので、常に日本語で返すよう指示してください（今は日本語と英語が混在）。(3) 対応後、短辺 240px の画像が rejected、640x480 の無地が rejected になることを確認して codex.md に書いてください。（状態：一部解決。小さい画像の拒否と日本語化は確認済み。無地画像は [C-7]）
- [C-7] Codex へ：640x480 の灰色無地 JPEG を cp-a（案内板）に送ると、同じ画像でも rejected と passed（「画像に案内板がはっきりと写っているため。」）が回によって変わります。モデルが無地画像で幻覚を起こしています。提案：(1) 応答に `observed`（画像に実際に見えるものの記述）を必須にし、先に記述させてから合否を決めさせる。(2) それでも不安定なら、画素の分散（色のばらつき）がほぼない画像は OpenAI に送らず rejected（理由「何も写っていないようです。対象を撮り直してください」）にする。(3) 対応後、灰色 640x480 を5回送って5回とも rejected になることを確認してください。モデル変更（gpt-4.1 など）は費用に関わるので、必要なら選択肢として codex.md に書き、決定はユーザーに任せてください。（状態：確認済み。灰色 640x480 を5回送って5回とも rejected「何も写っていないようです。対象を撮り直してください。」。コミット・push は Codex 待ち）
- [C-8] Codex へ：`test/live/supabase_live_test.dart` は Claude の担当です。nagisa-codex 側の未コミットの変更は `git restore test/live/supabase_live_test.dart` で戻してください（同じ確認は Claude が `nagisa` に入れました）。`supabase/` と `docs/progress/codex.md` だけをコミット・push してください。（状態：未回答）

- [C-9] 松本へ：プレイヤー側の入口を `lib/features/player/player_flow_page.dart` の `PlayerFlowPage({super.key, this.resumeRoomId})`（`String? resumeRoomId`：ホームの「続きから」で渡すルームID、新規参加なら null）として作ってください。Scaffold を持たない body の Widget にし、中で `matchRepositoryProvider`・`roomSnapshotProvider`・`sessionStoreProvider` を使って各 View へ表示値とコールバックを渡してください。できたら matsumoto.md に書いてもらえれば、Claude が `/player` の仮表示と差し替えます（`lib/app/routes.dart` の1行）。（状態：完了。PR #56 を nagisa に取り込み、`/player` を `PlayerShell(child: PlayerFlowPage(...))` に差し替え済み）

- [C-10] Codex へ：仕様変更（ユーザー決定、2026-11-01）。docs/system_design.md の「接続仕様の変更履歴」の通りに supabase/ を変更してください。(1) スタートQRの廃止：scan_checkpoint・_judge_context・scan_goal から start_scanned_at の確認（MQ:startNotScanned）を外し、scan_start 関数を削除。(2) ゴールボーナス：courses.goal_bonus_per_minute int not null default 1、participants.goal_bonus int not null default 0 を追加し、scan_goal で goal_bonus = floor(extract(epoch from ends_at - now()) / 60) × goal_bonus_per_minute（0未満にしない）を設定。seed の sample は 1。既存 migration は書き換えず、新しい migration で。反映（db push）まで行ったら codex.md に書いてください。Claude 側のアプリはこの反映後に test-1 へマージします。（状態：未回答）
- [C-11] 松本へ：スタートQRを廃止しました（ユーザー決定）。参加したら一斉開始を待つ流れです。`MatchRepository.scanStart` と `Participant.isReady` は無くなりました。スタートQR画面（`PlayerQrView` のスタート用の使い方）は不要です。ゴールボーナスを追加し、`snapshot.scoreOf` は合計（チェックポイント＋ボーナス）、内訳は `checkpointScoreOf` と `participant(id).goalBonus` です。結果画面の内訳表示に使ってください。（状態：ユーザーの指示で Claude が対応済み。下の [C-12] 参照）
- [C-12] 松本へ：ユーザーの指示で、PR #56 を `nagisa` に取り込み、C-11 の追従を Claude が行いました（2026-11-01）。変更したのは `player_flow_page.dart` のスタートQRの部分（`_QrPurpose.start`・`scanStart`・`isReady` の除去、参加後は開始待ちへ）と結果内訳のゴールボーナス1行、テスト3ファイルのスタートQR前提の箇所だけです。`lib/features/player/README.md` の C-11 の記述は松本さんのファイルなので変えていません。PR #55（nagisa → test-1）がマージされると #56 の内容も test-1 に入ります。同じ箇所を matsumoto/player-flow で直すと競合するので、次の作業は #55 マージ後の test-1 から始めてください。（状態：未回答）

## 松本の依頼への回答
- [M-1] への回答：`/player` は `PlayerShell`（`lib/app/player_shell.dart`）で包みます。背景は `PlayerNight.background`、AppBar はタイトルなし・同じ濃紺で戻るボタンだけ、ステータスバーは明るいアイコン、下側だけ SafeArea。各 View の見出し・背景はそのまま使えます。入口のクラスは [C-9] の形でお願いします。
- [M-2] への回答：mobile_scanner・image_picker と Android のカメラ権限は追加済み。ほかに必要なパッケージ・権限があれば matsumoto.md に書いてください。
- [M-3] への回答：実コース（案内図・撮影対象・QR配置）は未確定。決まるまでは `lib/core/mock/sample_course.dart` の仮コースで進めてください。

## Codex の依頼への回答
- [X-1] への回答：API を直接呼ぶスモークテスト（匿名ユーザー3人：運営・参加者・無関係）を実行。26/28 成功。
  - 成功：匿名ログイン、courses/checkpoints 読取、create_room（json 1行）、find_room_by_code、join_room（空白除去・再参加は同じ行）、運営の参加不可（MQ:permission）、無関係ユーザーに rooms・submissions が見えない、参加者の start_room 不可、開始前の scan_checkpoint（MQ:roomNotRunning）、scan_start と違うQR（MQ:wrongQr）、start_room でサーバーが started_at/ends_at 設定、2回目の開始（MQ:roomNotWaiting）、scan_checkpoint が text、違うQR、指定未クリアのゴール（MQ:requiredNotCleared）、自分のフォルダへの写真アップロード、他人のフォルダへのアップロード拒否（400）、無関係ユーザーの判定依頼拒否（400 MQ:permission）、運営の写真読取、finish_room、終了後の操作不可。
  - 失敗：judge-photo に無地の JPEG（320x240）を送ると 503 `{"error":"judge_unavailable"}`。そのため submissions に記録されず、運営の判定理由読取も確認できていない。
  - 未実施：アプリ画面からの接続確認（次に実施）、二重加点・時間切れの実サーバーでの確認（AI 判定が通ってから）。
- [X-3] への回答：OPENAI_API_KEY の登録し直し後、judge-photo は 200 を返すようになった（503 は再現しない）。ログ確認は不要になった。
- [X-4] への回答：`2480a48` の Function で確認。画像はモデルに届いている（青を「赤いもの」に送ると rejected）。ただしサイズで結果が変わる：
  | 画像 | ミッション | 結果 |
  |---|---|---|
  | 灰色 320x240 | cp-a 案内板 | passed「画像に案内板がはっきり写っているため。」 |
  | 灰色 640x480 | cp-a 案内板 | rejected |
  | 青 640x480 | cp-a 案内板 | rejected |
  | 灰色 320x240 | cp-free-1 赤いもの | passed「The image clearly shows a red apple…」 |
  | 青 640x480 | cp-free-1 赤いもの | rejected |
  | 赤 640x480 | cp-free-1 赤いもの | passed |
  → [C-6] で対策を依頼。実際の案内板写真での確認は、実機・実写真が用意できてから行う（未実施）。
- Codex の C-6 確認依頼への回答（2026-10-31 17:40、judge_probe で実測）：
  | 画像 | ミッション | 結果 | 理由 |
  |---|---|---|---|
  | 灰色 320x240 | cp-a 案内板 | rejected | 画像が小さすぎます。近づいて撮り直してください。 |
  | 灰色 640x480 | cp-a 案内板 | **passed**（直前の実行では rejected） | 画像に案内板がはっきりと写っているため。 |
  | 赤 640x480 | cp-free-1 赤いもの | rejected | 画像は単色の赤色のみで、具体的な物体や対象が写っていません。 |
  → 1 は期待どおり。2 は期待外れ（[C-7]）。3 は「単色・無地は不合格」という厳格指示に合っているので問題なしと判断（実物の赤い物の写真での確認は未実施）。
- [X-5] への回答：320x240 は rejected「画像が小さすぎます。近づいて撮り直してください。」。640x480 の無地は C-7 の修正後、5回とも rejected「何も写っていないようです。対象を撮り直してください。」。
- [X-2] への回答：config/supabase.json の URL と publishable（anon）キーで接続でき、匿名ログインも有効（/auth/v1/settings で anonymous_users: true）。

## アプリ側の接続で前提にしていること（Codex 向け）
- rpc の戻り値：create_room / find_room_by_code / join_room は json の1行（配列で返しても可）。scan_checkpoint は text。
- 失敗：`MQ:<コード>` を含むメッセージ（rpc の例外、Function の 4xx `{"error": "MQ:..."}`）。それ以外の失敗と 503 は通信失敗として扱い、再送を案内する。
- RLS 拒否は Postgres コード `42501`、Storage の拒否は 401/403 を権限エラーとして扱う。
- 写真：`photos/{room_id}/{user_id}/{マイクロ秒}.jpg` に contentType `image/jpeg` で置いてから judge-photo を呼ぶ。長辺 1280px 程度に縮小して送る予定。
- Realtime：rooms（id）・participants・checkpoint_clears・submissions（room_id）の変更を購読し、変更が来たら全体を読み直す。

## 記録（新しい順）

### 2026-11-01（3）
- ユーザーの指示で PR #56（松本の PlayerFlowPage）を nagisa に取り込み、C-11（スタートQR廃止・ゴールボーナス）に追従：player_flow_page.dart のスタートQR部分を除去、結果内訳にゴールボーナス、テスト3ファイルを更新
- `/player` を `PlayerShell(child: PlayerFlowPage(resumeRoomId: ...))` に差し替え、仮表示を削除
- 検証：analyze 問題なし、test 94件成功、整形差分なし。実サーバー・実機は未確認（Codex の C-10 待ち）

### 2026-11-01（2）
- 仕様変更（ユーザー決定）：スタートQRを廃止、ゴールボーナスは残り時間に比例（1分あたりの点数はコース設定、仮コースは1点）
- アプリ側：モデル・ルール・モック・Supabase 接続・運営画面・テスト・接続仕様を変更。analyze 問題なし、test 64件成功。実サーバー接続テストは [C-10] の反映後に実行
- [C-10]（Codex）・[C-11]（松本）を依頼

### 2026-11-01
- 松本のプレイヤーUI（`e3bed5c`、test-1）を取り込み：analyze 問題なし、test 61件成功、整形差分なし、CI 成功
- プレイヤー側のデータ接続は松本が担当（ユーザー決定）。Claude は `/player` を `PlayerShell` で包み（[M-1]）、入口の形を [C-9] で依頼

### 2026-10-31 18:40
- 実写真での判定（赤いポスターが木の壁に掛かった写真、約1477x1108）：
  | ミッション | 結果 | 理由 |
  |---|---|---|
  | cp-free-1 赤いもの | passed +5 | 赤い背景のポスターが明確に写っているため… |
  | cp-b 階段の踊り場の窓 | rejected | 階段の踊り場の窓が画像に写っていないため… |
  | cp-a 案内板 | passed +10 | 壁に掛かっている赤い案内板がはっきりと写っているため… |
- 判定は動いている。ポスターを「案内板」と判定したのはミッション文のあいまいさが原因。実際のコースではミッション文を具体的にする（例：「フロアの案内図（館内マップ）を撮影する」）。正解写真との比較は未確定事項として残す

### 2026-10-31 18:20
- C-7 の確認：灰色 640x480 を5回送り5回とも rejected。`test/live` も無地画像が必ず rejected・加点なしになることを確認するよう変更し、実サーバーで成功

### 2026-10-31 17:40
- アプリ側：Realtime の通知が抜けても 10 秒ごとに読み直すよう `watchRoom` を修正（実サーバーで購読直後の更新が届かないことがあったため）
- `test/live/supabase_live_test.dart`：実際の Supabase に SupabaseMatchRepository で接続し、運営・参加者2人で作成→参加→スタートQR→開始→チェックポイント→写真判定→終了と Realtime 反映を確認。修正後5回連続成功（修正前は3回中1回、スタートQRの反映待ちでタイムアウト）
- judge-photo：C-6（小さい画像の拒否・日本語）は確認。無地画像の不安定な合格を [C-7] で依頼

### 2026-10-31 17:10
- judge-photo の確認：画像はモデルに届くが、320x240 の小さい画像で誤合格（[X-4] への回答）。[C-6] を依頼

### 2026-10-31 16:40
- OPENAI_API_KEY の登録し直し後、スモークテスト 28/28 成功（judge-photo が 200 を返し、合格で +10 点）。ただし無地画像が合格になったので [C-5] を依頼

### 2026-10-31 16:00
- Supabase のスモークテスト 26/28 成功（詳細は [X-1] への回答）。judge-photo の 503 を [C-4] で依頼

### 2026-10-31 15:30
- `129b476` mobile_scanner・image_picker 追加、Android カメラ権限
- `1560a69` 開発確認用に Web 追加、Android にインターネット権限
- `69532eb` 写真を縮小して送るよう資料に追記
- `334a208` アプリ側の Supabase 接続（SupabaseMatchRepository）、起動時の切替（config/supabase.json があれば Supabase）、ホームの「続きから」
- Codex の `e65fdf4` をアプリ側の実装と照合：テーブル・関数・戻り値・エラーコードは一致。写真の base64 変換と Storage 読み取り範囲を指摘 → Codex が `dd4edbf` で対応済み
- 検証：flutter analyze 問題なし、flutter test 25件成功、debug APK・Web ビルド成功、GitHub CI 成功
- 未実施：Supabase への実接続、実機・複数端末での確認

### 2026-10-31 15:00
- `61f59d1` Flutter 基盤、共通モデル、MatchRepository 契約、メモリ上のモック、オーナー画面
- `eee8fb4` Supabase 接続仕様（docs/system_design.md）
