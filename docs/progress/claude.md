# Claude の進捗

担当：オーナー画面、共通モデル・Repository・状態管理・復帰、アプリ側の Supabase 接続（`lib/core/supabase/`）、依存関係・CI・プラットフォーム設定、資料、統合。ブランチ `nagisa`（PR #52 → `test-1`）。

## 現在の状態（2026-10-31 17:00 更新）
- 作業中：なし（サーバー側の反映待ち）
- 次にやること：Supabase に接続して、ルーム作成→参加→開始→撮影判定→ゴールを Chrome とアプリで確認する
- 待っていること：Codex のサーバー側の反映（db push・seed・judge-photo デプロイ）、ユーザーによる OPENAI_API_KEY の登録

## 相手への依頼・質問
- [C-1] Codex へ：サーバー側の反映（migration・seed・judge-photo）が終わったら、codex.md に「反映済み」と、反映したコミットを書いてください。（状態：未回答）
- [C-2] Codex へ：AI のモデル（現在 gpt-4.1-mini）と1回あたりの費用の目安、推奨案を codex.md に書いてください。決定はユーザーが行います。（状態：未回答）
- [C-3] Codex へ：`nagisa` の最新（接続コード・資料）を `git merge origin/nagisa` で取り込み、`lib/core/supabase/` と接続仕様の食い違いがあれば書いてください。（状態：未回答）

## アプリ側の接続で前提にしていること（Codex 向け）
- rpc の戻り値：create_room / find_room_by_code / join_room は json の1行（配列で返しても可）。scan_checkpoint は text。
- 失敗：`MQ:<コード>` を含むメッセージ（rpc の例外、Function の 4xx `{"error": "MQ:..."}`）。それ以外の失敗と 503 は通信失敗として扱い、再送を案内する。
- RLS 拒否は Postgres コード `42501`、Storage の拒否は 401/403 を権限エラーとして扱う。
- 写真：`photos/{room_id}/{user_id}/{マイクロ秒}.jpg` に contentType `image/jpeg` で置いてから judge-photo を呼ぶ。長辺 1280px 程度に縮小して送る予定。
- Realtime：rooms（id）・participants・checkpoint_clears・submissions（room_id）の変更を購読し、変更が来たら全体を読み直す。

## 記録（新しい順）

### 2026-10-31 17:00
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
