# 「余白」アプリ 共同開発手順

各画面は同じ記録データで接続されています。担当フォルダ内でデザインと動作を変更してください。

- **AIへ最初に渡すルール：[AGENTS.md](AGENTS.md)**
- **環境構築・更新・PR・トラブル対応：[開発ガイド](docs/development.md)**
- [画面間の接続ガイド](docs/feature_integration.md)
- [実装内容とプレビュー](docs/implementation.md) / [設計書](yohaku_app_design.md)

## 全員で使うバージョン

Flutter **3.41.5** / 同梱Dart **3.11.3**。最新版への更新は各自で行わず、プロジェクト用にFVMで揃えます。Android開発はJDK **17**を使います。

初回は[開発ガイド](docs/development.md#初回セットアップ)を読んでFVMを用意してください。端末に別バージョンのFlutterがあっても、プロジェクトでは指定版を使えます。

## 2回目以降の作業開始

**未コミットの変更があれば先に保存し、コマンドは1行ずつ実行してください。エラーが出たらその時点で止めます。**

```bash
cd SPAJAM2026
git switch 自分のブランチ名
git pull --ff-only
git fetch origin
git merge origin/rehearsal/02
fvm install
fvm dart tool/check_environment.dart
fvm flutter pub get --enforce-lockfile
fvm flutter run -d chrome
```

初回に `git push -u origin 自分のブランチ名` を実行して追跡先を設定します。Androidでは最後を `fvm flutter run -d デバイスID` に置き換えます。PCではアプリ全体が最大430×932のスマホ相当サイズになります。

## 分担

| 担当 | 作業ブランチ例 | 主なソース |
|---|---|---|
| ホーム（永松さん） | `feature/yohaku-home` | `lib/features/home/` |
| SPACE（松本くん） | `feature/yohaku-space` | `lib/features/space/` |
| 今日の星座（嶋本さん） | `feature/yohaku-constellation` | `lib/features/constellation/` |
| 宇宙・振り返り（北林） | `feature/yohaku-universe-history` | `lib/features/universe/`, `lib/features/history/` |

各担当の素材は `assets/担当機能/`、テストは `test/features/担当機能/` に置きます。SPACEは `assets/star/` も使用します。共通ファイルは統合担当へ相談してください。

## 共有する前に

[開発ガイドのチェック](docs/development.md#共有前のチェック)を実行し、担当ファイルを指定してコミット・pushします。PR先は `rehearsal/02` です。

**最新の共有ブランチを取り込んだPRで、GitHubの必須チェック `check` がすべて成功してからマージします。** チェック待ち・失敗・競合中はマージせず、原因を解決します。AIにはPR作成とマージを別の依頼として伝えてください。
