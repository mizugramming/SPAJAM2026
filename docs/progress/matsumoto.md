# 松本の進捗

担当：プレイヤー画面・担当テスト。今回の保存先はユーザー指定の `test-1`。元の未追跡ファイルを保護するため、最新の `origin/test-1` を取得した一時作業コピーから反映する。

## 現在の状態（2026-10-31 更新）

- 参加・開始待ち・マップ／フロア切替・QR・撮影・写真確認・判定／再撮影・順位・結果の表示部品を実装し、ナイトミッション配色を反映。
- 各Viewは親のScaffoldへ渡すbody。最初の画面は `PlayerJoinView`（`lib/features/player/player_join_view.dart`）。表示値とcallbackを受け取り、保存・得点計算・AI接続は持たない。
- 地図・写真の拡大、入力保持、二重送信防止、文字拡大、読み上げに対応。
- 最新の共通基盤・Repository・Provider・QR／撮影パッケージ・接続仕様を確認済み。各Viewとの接続は未実装で、アプリの `/player` は既存の仮画面のまま。
- 次は共通状態を表示値・callbackへ接続し、モックで一周確認する。今回の依頼は現時点のUIを保存するところまで。

## 嶋本への接続事項

- [M-1] `PlayerJoinView(onJoin: ...)` がプレイヤー側の入口。親ルートへの組み込みは嶋本担当。body内にヘッダーと濃紺背景があるため、親AppBarとの表示重複・背景色を統合時に調整する。（状態：未接続）
- [M-2] `PlayerQrView.scanner`・`PlayerCaptureView.preview`・`PlayerPhotoReviewView.photo` に実際のQR／撮影Widgetを渡す。読取の停止・再開、提出、復帰は提供済みのRepository／Providerへつなぐ。（状態：次のプレイヤー実装）
- [M-3] `PlayerMapView.floors` はフロア名と案内図Widget。実コースの案内図・撮影対象・QR配置を受け取って表示を確定する。（状態：実コース未受領）

## 記録（新しい順）

### 2026-10-31

- ユーザーから現時点のプレイヤーUIを `test-1` へpushする依頼。最新の `origin/test-1`（`c5e5e00`）へ担当ソース10件・テスト5件・担当READMEとこの進捗だけを追加する。共通基盤・依存・lock・Android・CIは変更しない。
- 既存の隔離環境（Flutter 3.44.9 / Dart 3.12.2）で担当テスト36件、9画面の描画、サンプルcallbackによるデモ一周、Webビルドが成功。実機QR／カメラ、実アプリでのプレイヤーフロー、AI、複数端末同期は未検証。
- 最新のFlutter固定版は3.44.5。上記の暫定検証とは区別し、push後にGitHub Actionsの固定環境での結果を確認する。
