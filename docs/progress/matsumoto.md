# 松本の進捗

担当：プレイヤー画面・QR／撮影・担当テスト。作業ブランチは `matsumoto/player-flow`、PR先は `test-1`。親画面・共通基盤は変更しない。

確認先：[PR #56（matsumoto/player-flow → test-1）](https://github.com/mizugramming/SPAJAM2026/pull/56)。C-11追従待ちのドラフトですが、差分の閲覧・コメントは可能です。

## 嶋本さんの確認手順

1. PR #56の「Files changed」で担当差分を確認してください。入口は `lib/features/player/player_flow_page.dart` の `PlayerFlowPage({String? resumeRoomId})` で、Scaffoldなしのbodyです。
2. `lib/features/player/README.md` の入口の組み込みと共通接続を確認してください。`PlayerShell` 内の仮画面差し替えは嶋本担当です。
3. 共通モックで一周・復帰・失敗時の挙動を確認するテストは `test/features/player/player_flow_page_test.dart` です。PRのChecksからCI結果も確認できます。実機QR／カメラは未確認です。
4. #55の共通APIとC-11は、このPRの旧APIとはそのまま組み合わせられません。#55統合後のスタートQR除去・ボーナス内訳・関連テスト更新は松本側で行います。現在は入口契約と接続方法の確認をお願いします。

自分の作業ブランチを切り替えずに進捗を読む場合：

```bash
git fetch origin matsumoto/player-flow
git show origin/matsumoto/player-flow:docs/progress/matsumoto.md
git show origin/matsumoto/player-flow:lib/features/player/README.md
```

このPRでは親ルートを変更していないため、通常の `flutter run` だけでは新しいプレイヤー画面へ入れません。現時点の操作確認は上記の共通モックのWidgetテスト、実アプリ確認はC-11追従と親ルート差し替え後に行います。

## 現在の状態（2026-11-01 更新）

- 参加・開始待ち・マップ／フロア切替・QR・撮影・写真確認・判定／再撮影・順位・結果の表示部品を実装し、ナイトミッション配色を反映。
- [C-9] の入口を `lib/features/player/player_flow_page.dart` の `PlayerFlowPage({super.key, this.resumeRoomId})` として実装。Scaffoldなしのbodyで、各Viewへ共通状態とcallbackを渡す。
- 地図・写真の拡大、入力保持、二重送信防止、文字拡大、読み上げに対応。
- 現行 `test-1` の `MatchRepository`・`roomSnapshotProvider`・`sessionStoreProvider` へ接続。独自の保存先・得点計算・共有モデル・AI接続は追加していない。
- 共通モックで参加→スタートQR→開始待ち→マップ→地点QR→撮影・判定→ゴール→仮／最終結果を確認。自由ミッション一覧・順位・ルーム復帰も接続した。
- `/player` の仮画面の差し替えは嶋本担当。最新の `origin/nagisa` にある [C-11] は共通APIが `test-1` に未統合のため追従待ち（下記）。

## 嶋本への接続事項

- [C-9・M-1] 回答：`PlayerFlowPage(resumeRoomId: resumeRoomId)` を `PlayerShell` のbodyに渡せます。Scaffold・AppBar・SafeAreaは追加していません。`lib/app/routes.dart` からのimport・仮画面差し替えをお願いします。（状態：担当実装完了、親への接続待ち）
- [M-2] 回答：登録済みの `mobile_scanner` / `image_picker` を使用。QRは読取後・バックグラウンド・破棄時に停止／解放し、重複を抑止。写真は長辺1280px以内・品質80で端末カメラから取得して共通Repositoryへ提出。追加の依存・権限は不要です。（状態：接続済み、実機未確認）
- [M-3] 回答：共通の仮コースを利用。実館内図の代わりにフロア別地点一覧・点数・達成状態を表示し、図面未登録と明示。座標・経路は作っていません。（状態：仮コース接続済み、実コース待ち）
- [C-11] 最新取得時に追加を確認。現 `origin/test-1` は `e3bed5c` の旧APIで、変更は `origin/nagisa` の `3c5e6e6` 以降です。共通変更を `test-1` へ統合したら、松本側でスタートQR・`scanStart` / `isReady` の利用を除去して参加→待機へ変更し、結果内訳を共通の `checkpointScoreOf` / `goalBonus` へ更新します。関連テストも更新・再検証してから統合してください。（状態：共通APIの統合待ち）

## 検証と残る確認

- Flutter 3.44.5 / Dart 3.12.2、`pub get --enforce-lockfile` 成功。依存・lock・SDK設定は変更なし。
- `flutter analyze --no-pub` と `dart analyze lib test`：問題なし。整形チェックと `git diff --check` も成功。全件テストは89件成功、実サーバー用1件は設定未指定のため既存の条件でskip。実サーバーの成功とは扱わない。
- 新規テスト：一周と5状態からの復帰、通信失敗時の同じ写真で再送、不合格からの再撮影、撮影キャンセル、終了／時間切れ後の遅い応答、端末記録の保存／削除失敗、QRの重複・停止／再開、フロア一覧。
- 未実施：Android実機のQR／カメラ／権限、撮影中のプロセス破棄、実サーバー／AI、再起動・複数端末同期、PlayerShellと親ルートを含む実アプリの一周。撮影中にプロセスが失われた場合の未提出写真は復元せず、ルームへ復帰して再撮影する。

## 記録（新しい順）

### 2026-11-01

- PR #56を作成し、嶋本さん向けの確認先・確認手順・C-11追従の担当を追記。コード変更やマージは行っていない。
- ユーザーの [C-9] 指示に従い、自分のブランチで共通基盤との接続を実装。対象は担当ソース・テスト・README・この進捗のみ。既存の未追跡 `ios/` / `linux/` / `macos/` は保持。
- C-9・M-1〜M-3への回答は `test-1` に未反映で `origin/nagisa` に存在することを確認。親Shell・ルートや共通変更は無断で取り込んでいない。
- 保存失敗後の再保存、削除失敗後の再試行、遅い処理中の離脱、写真確認の長いお題を修正し、回帰テストを追加。
- 最新の `nagisa` のC-11は共通APIの次の変更として上記に記録。現在のPRは `test-1` の既存APIに対するC-9実装。マージは行わない。
- 共通側のPR #55（`nagisa` → `test-1`）が未統合であることを確認。C-11追従前の混在を防ぐため、今回のPRはドラフトで共有し、#55統合後の更新対象を明記する。

### 2026-10-31

- ユーザーから現時点のプレイヤーUIを `test-1` へpushする依頼。最新の `origin/test-1`（`c5e5e00`）へ担当ソース10件・テスト5件・担当READMEとこの進捗だけを追加する。共通基盤・依存・lock・Android・CIは変更しない。
- 既存の隔離環境（Flutter 3.44.9 / Dart 3.12.2）で担当テスト36件、9画面の描画、サンプルcallbackによるデモ一周、Webビルドが成功。実機QR／カメラ、実アプリでのプレイヤーフロー、AI、複数端末同期は未検証。
- 最新のFlutter固定版は3.44.5。上記の暫定検証とは区別し、push後にGitHub Actionsの固定環境での結果を確認する。
