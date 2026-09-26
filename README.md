# 「余白」アプリ 共同開発手順

各画面は同じ記録データで接続されています。担当フォルダ内でデザインと動作を変更してください。

- **AIへ最初に渡すルール：[AGENTS.md](AGENTS.md)**
- **環境構築・更新・PR・トラブル対応：[開発ガイド](docs/development.md)**
- [画面間の接続ガイド](docs/feature_integration.md)
- [実際のフォルダ構造と責務](docs/project_structure.md) / [AIへ渡す開始・分担プロンプト](docs/ai_prompts.md)
- [別のアプリでも使う共通ルール一式](docs/reuse_rules.md)
- [画像の追加手順](docs/adding_assets.md) / [別のアプリを新しく始める手順](docs/new_app.md)
- [実装内容とプレビュー](docs/implementation.md) / [設計書](yohaku_app_design.md)

## AIが開発を始めるときの読み方

1. [AGENTS.md](AGENTS.md)：プロジェクト共通のルールブック。「どう開発するか」。
2. このREADME：今回の担当範囲・統合先・環境・参照先。
3. [アプリの設計書](yohaku_app_design.md)と[接続ガイド](docs/feature_integration.md)：何を作り、どのデータ・画面へつなぐか。
4. [開発ガイド](docs/development.md)：このプロジェクトで実行する準備・検証コマンド。
5. [フォルダ構造](docs/project_structure.md)を実際のファイル一覧と照合し、担当の実装・接続先・関連テストを読む。[開始プロンプト](docs/ai_prompts.md)を使い、変更するファイルを明確にしてから進める。

設計書は初期設計です。現在はMVP全体を実装し、その後の画面変更も取り込んでいます。最新のユーザー依頼・決定事項と[実装内容](docs/implementation.md)も確認し、古い設計だけを根拠に既存機能を戻さないでください。

余白の統合先は **`rehearsal/02`** です。**`main` はアプリ共通のルール・プロンプト・資料の雛形を保管するブランチ**へ整理します（PR #26）。余白の開発でmainを取り込んだり、アプリ実装のmain向けPRを作ったりしません。共通ファイルの更新は必要な差分だけを取り込みます。

## 全員で使うバージョン

Flutter **3.41.5** / 同梱Dart **3.11.3**。最新版への更新は各自で行わず、プロジェクト用にFVMで揃えます。Android開発はJDK **17**を使います。

初回は[開発ガイド](docs/development.md#初回セットアップ)を読んでFVMを用意してください。端末に別バージョンのFlutterがあっても、プロジェクトでは指定版を使えます。

## 2回目以降の作業開始

**未コミットの変更があれば先に保存し、コマンドは1行ずつ実行してください。エラーが出たらその時点で止めます。**

```bash
cd SPAJAM2026

git status
git switch 自分のブランチ名

git fetch origin
git merge --ff-only origin/自分のブランチ名
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

登録済み素材フォルダの直下に画像を追加する場合、`pubspec.yaml` の変更は不要です。[画像の追加手順](docs/adding_assets.md)に従い、出典は `docs/asset_sources/担当機能.md` に記録します。この担当別の出典ファイルも各担当の変更範囲です。

## このアプリの変更範囲

| 担当 | ソース | 素材 | テスト |
|---|---|---|---|
| ホーム | `lib/features/home/` | `assets/home/` | `test/features/home/` |
| SPACE | `lib/features/space/` | `assets/space/`, `assets/star/` | `test/features/space/` |
| 今日の星座 | `lib/features/constellation/` | `assets/constellation/` | `test/features/constellation/` |
| 宇宙・振り返り | `lib/features/universe/`, `lib/features/history/` | `assets/universe/`, `assets/history/` | `test/features/universe/`, `test/features/history/` |

担当外ファイルの読み取りはよい。変更は依頼された範囲だけに限定する。共通部分の変更が必要なら、まず理由・対象ファイル・影響を説明して統合担当へ依頼する。担当内で解決できる場合はそのまま進める。

以下は共通管理。担当画面の実装やローカル環境のエラーを理由に、無断で変更しない。

- `lib/app/`, `lib/core/`, `lib/main.dart`, `assets/common/`
- `pubspec.yaml`, `pubspec.lock`, `.fvmrc`, `tool/toolchain.json`
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`
- `.github/`, `tool/`, `analysis_options.yaml`, `.gitignore`, `.gitattributes`, `.vscode/`
- `test/widget_test.dart`, `test/helpers.dart`, `test/core/`, `test/tool/`, 共有ドキュメント・AI指示ファイル

## このアプリの接続ルール

- 全画面の記録は既存の `SpaceRecord` と `spaceRecordsProvider` を使う。独自の保存先や画面専用コピーを新設しない。
- 記録のID、JSONキー、感情・テーマのID、既存のルート・Providerの公開APIを勝手に変更しない。
- 他Featureを直接importせず共通APIを使う。追加・削除・再起動・日付変更でも同じ記録が反映されるようにする。
- 各画面でPC全体の物理サイズを直接参照しない。共通のスマホ表示枠と `MediaQuery` / `LayoutBuilder` を使う。
- 既存の入力保持、二重保存防止、削除確認、SafeArea、スクロール、文字拡大への対応を維持する。

## 共有する前に

[開発ガイドのチェック](docs/development.md#共有前のチェック)を実行し、担当ファイルを指定してコミット・pushします。PR先は `rehearsal/02` です。

**最新の共有ブランチを取り込んだPRで、GitHubの必須チェック `check` がすべて成功してからマージします。** チェック待ち・失敗・競合中はマージせず、原因を解決します。AIにはPR作成とマージを別の依頼として伝えてください。
