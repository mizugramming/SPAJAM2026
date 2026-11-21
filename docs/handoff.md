# UI担当・端末担当への引き継ぎ

基盤は `origin/honsen` の `52154e7` から作成した `feat/polishing-workshop`。基盤PRが統合された後は `origin/honsen` を起点にする。先に並行着手するときは同じ基盤のコミットをチェックアウトし、各自の作業ブランチを作る。例は初期基盤の統合前を想定。

```bash
git fetch origin
git switch --no-track -c feat/polish-ui origin/feat/polishing-workshop
```

端末担当は最後のコマンドの作業ブランチ名を `feat/polish-device` に置き換える。既に作成済みなら自分の作業ブランチに戻る。各自のPCで[開発手順](development.md)を実行し、初回起動の結果を[検証記録](validation.md)へ追記する。

| 担当 | 編集する範囲 | 最初の操作と完成条件 |
|---|---|---|
| ① UI担当 | `lib/ui/`、UI用素材、`test/workshop_flow_test.dart`。親画面WorkshopとUI部品の組み込みも担当 | Chromeで低・中・高を選び、両素材を3回磨く。動作指示・操作の押しやすさ、サビ・輪郭・光沢、停止中と結果の整合を同じ進捗で確認 |
| ② 端末担当 | `lib/device/`、`lib/device_main.dart`、Androidの `MainActivity.kt / VoiceAnalysis.kt / StrokeDetector.kt`、`tool/native/` と計測画面のテスト | 専用入口からREDMIでHz・音量・選択やすりを記録。4条件と前半・後半の触感を比較。調整後は本編でも同じ動きを再確認 |
| 共通・統合 | `lib/main.dart`、`lib/game/game.dart`、`test/game_test.dart`、SDK・依存・Manifest・CI | 入力受け口とゲームの状態を管理。型・単位・ID・チャンネルや依存を変えたいときは、両担当が作業PR上で影響を共有してから統合担当が変更 |

UI担当は `Workshop(game: ..., actions: ...)` から状態を読み、入力イベントだけ返す。端末担当は往復を1イベント、音声をHzと音量、出力をパルス長と振幅として扱う。詳しい境界、素材と採点の追加方法は[構成と接続](project_structure.md)。端末調整をUIの完成まで待つ必要はない。

役割は今回指定された2人の分担。氏名・統合責任者名、別PCでの起動再現、登録実機の試験結果は未確認。2件の作業PRは基盤を先に `honsen` へ取り込み、その後それぞれ最新の統合先に合わせて再検証する。
