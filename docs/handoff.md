# UI担当・端末担当への引き継ぎ

リポジトリを取得したら、最新の本選版から自分の作業ブランチを作る。次はUI担当が新しい作業を始める例。ブランチ名は担当と作業内容に合わせる。

```bash
git fetch origin
git switch --no-track -c feat/polish-ui-next origin/honsen
```

既存の作業ブランチで続ける場合は、自分の変更をコミットしてから `git fetch origin`、`git merge origin/honsen` を実行する。PRの宛先は `honsen`。[初回起動と検証の手順](development.md)

| 担当 | 編集する範囲 | 最初の操作と完成条件 |
|---|---|---|
| ① UI担当 | `lib/ui/`、UI用素材、`test/workshop_flow_test.dart`。親画面WorkshopとUI部品の組み込みも担当 | Chromeで低・中・高を選び、両素材を3回磨く。動作指示・操作の押しやすさ、サビ・輪郭・光沢、停止中と結果の整合を同じ進捗で確認 |
| ② 端末担当 | `lib/device/`、`lib/device_main.dart`、Androidの `MainActivity.kt / VoiceAnalysis.kt / DeskMotion.kt / StrokeDetector.kt / DeskHaptics.kt`、`tool/native/` と計測画面のテスト | REDMIでHz・音量・選択やすりと4条件の往復数を記録。本編で最初の横押し、真上への持ち上げ、速さ・やすり・研磨率ごとの触感を比較 |
| 共通・統合 | `lib/main.dart`、`lib/game/game.dart`、`test/game_test.dart`、SDK・依存・Manifest・CI | 入力受け口とゲームの状態を管理。型・単位・ID・チャンネルや依存を変えたいときは、両担当が作業PR上で影響を共有してから統合担当が変更 |

UI担当は `Workshop(game: ..., actions: ...)` から状態を読み、入力イベントだけ返す。端末担当は往復を1イベント、音声をHzと音量、出力をパルス長と振幅として扱う。詳しい境界、素材と採点の追加方法は[構成と接続](project_structure.md)。端末調整をUIの完成まで待つ必要はない。

今回の統合版はWindows Chromeの疑似入力でメダル・漢ともに3回の研磨と再挑戦まで確認した。REDMIでのこの版のプレイは端末担当が確認する。過去の実機測定と今回の検証条件は[検証記録](validation.md)にまとめている。
