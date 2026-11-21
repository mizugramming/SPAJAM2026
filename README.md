# いろみがき｜SPAJAM 本選

声でやすりを選び、スマホを前後に動かして、サビたメダルや汚れた「漢」の色を磨き出すゲームです。同じ素材を10秒ずつ3回磨き、最後に自分の仕上がりを見てもう一度遊べます。

## 起動

FVMでリポジトリのFlutterを使います。初回のSDK・Android・Chromeの準備、実機IDの選び方は[開発手順](docs/development.md)にあります。

```bash
fvm install
fvm flutter pub get --enforce-lockfile
fvm flutter run -d chrome
```

| 担当 | 開き方 | 作業の入口 |
|---|---|---|
| UI担当 | Chromeの「はじめる」から疑似音声と「1往復を入力」でプレイ。開発版では「配置を編集」から各画面を調整 | [デザイン・共通部品](docs/app_design.md)、[画面の配置表](lib/ui/workshop_layout.dart)、[素材・フォント](docs/assets.md) |
| 端末担当 | 登録Androidに `fvm flutter run -d <端末ID> -t lib/device_main.dart`。ゲーム全体は `-t` 以降を外す | `lib/device/` とAndroidのKotlin実装。[声・往復・振動の4条件試験](docs/device_trials.md) |
| 共通・組み込み | ゲーム、時間、入出力の境界を保って統合 | [共有データ・素材追加・採点の差し替え](docs/project_structure.md)、[2人への引き継ぎ](docs/handoff.md) |

本番想定は **Xiaomi REDMI Note 15 5G 1台・オフライン**。実機の判定と手触りは現地確認が必要です。画面画像、疑似入力テスト、APKビルド、実機の確認状況は[検証記録](docs/validation.md)にあります。

## 共同開発

本選アプリの統合先・PR先は `honsen`。基盤作業ブランチは `feat/polishing-workshop` です。基盤取り込み前に作業を始める場合の取得元と担当範囲は[引き継ぎ](docs/handoff.md)を参照してください。

- [共同開発ルール](AGENTS.md)・[環境とCI](docs/development.md)・[登録端末](docs/development-kit/devices.md)
- [開発キットとSkills](docs/development-kit/README.md)・[担当者の開始プロンプト](docs/ai_prompts.md)・[別PCのClaude Code](docs/development-kit/claude-code.md)・[共有ZIPの手順](docs/development-kit/share-package.md)

`main` は共通キットです。本選の変更は作業ブランチから順に `honsen` へ統合します。キットの取り扱いは[リポジトリの運用](docs/repository_maintenance.md)にあります。
