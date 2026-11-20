# SPAJAM 本選アプリ — honsen ブランチ

この `honsen` ブランチは、[mizugramming/SPAJAM2026](https://github.com/mizugramming/SPAJAM2026) 内の本選アプリ開発・統合先です。`main` は共通ルール・Skills・資料の雛形を管理する開発キットとして残します。

**現在は開発準備の段階です。アプリ本体、SDK設定、依存ロック、起動・ビルド手順はまだ作成していません。** テーマ、仕様、SDK、担当者は初期開発で決定し、資料へ反映します。

## 最初に行うこと

1. [共通ルール](AGENTS.md)と[初期プロンプト](docs/development-kit/initial-prompt.md)を確認し、本選のアイデア・利用者・主要な体験を伝えます。
2. コンセプト・主要導線・完成条件を合意し、[設計書](docs/app_design.md)へ記録します。
3. アプリ基盤を作成し、SDK・依存ロック・起動方法・解析・テスト・ビルドを[開発手順](docs/development.md)へ記録します。
4. [構成と接続](docs/project_structure.md)で担当ファイルと共通の接続を決め、[引き継ぎ](docs/handoff.md)を更新して分担を始めます。

初期開発には `$spajam-flutter-delivery`、基盤ができた後の担当作業には[開始・再開プロンプト](docs/ai_prompts.md)を使います。登録済みの実機は[端末情報](docs/development-kit/devices.md)を参照します。

別PCのClaude Codeでも同じSkillsを使えます。[Claudeの導入・呼び出し方とCodexとの分担](docs/development-kit/claude-code.md)を参照してください。UI検討には[提供されたサンプル集](docs/development-kit/ui-references.md)も利用できます。

方針と主要画面が固まったら、[別PC向け共有ZIP](docs/development-kit/share-package.md)で、アプリ完成前から開発とプレゼン作りを分担できます。

## 資料と役割

| ファイル | 用途 |
|---|---|
| [AGENTS.md](AGENTS.md) | 共同開発、環境、素材、検証、統合の共通ルール |
| [開発キットの案内](docs/development-kit/README.md) | Skillsの使い方と初期プロンプト |
| [アプリ設計書](docs/app_design.md) | 今回の仕様・完成条件・決定履歴 |
| [構成と接続](docs/project_structure.md) | 実ファイル、共有データ、担当の境界 |
| [環境・開発手順](docs/development.md) | 初回準備、日々の開発、CI、マージ |
| [素材管理](docs/assets.md) | 素材の登録、出典、表示確認 |
| [検証記録](docs/validation.md) | 実施結果と未確認事項 |
| [担当への引き継ぎ](docs/handoff.md) | 会話を読まずに担当作業へ入るための情報 |

現在のアプリ実装範囲・担当者・統合担当は未決定です。同じファイルを複数人へ同時に割り当てず、確定した担当と接続仕様を上記の資料へ記録します。

## ブランチ・PR・マージ

- 本選アプリの統合先・PR先は **`honsen`** です。GitHubのPR作成画面でも `base: honsen` を選びます。
- 作業ブランチは最新の `origin/honsen` から作り、`feat/<内容>`、`fix/<内容>`、`docs/<内容>` を使って1人・1タスクで分けます。
- 書き込み権限を持つメンバーは、自分のPRも他の人の承認を待たずにマージする運用です。レビューは必要に応じて依頼できます。
- マージする人が最新コミットのCI成功、差分、競合の有無、未解決のレビュー会話を確認します。CIを実行することと、GitHubの保護設定で強制することは別です。
- AIへの依頼では、PR作成までか、確認後のマージまでかを伝えてください。

同じリポジトリを取得済みのフォルダで、未コミット変更を確認・保護してから作業ブランチを作ります。以下は文書変更の例です。

```bash
git status --short --branch
git fetch origin
git switch --no-track -c docs/update-guide origin/honsen
```

作業を終えたら[開発手順](docs/development.md)の検証を実行し、変更ファイルを指定してコミット・pushします。

```bash
gh pr create --base honsen
gh pr checks --watch
gh pr merge --merge
```

コマンドは1行ずつ実行します。CIの失敗・未実行・実行中を成功と扱わず、PR画面でも結果と競合を確認してからマージします。他のPRが先に入った場合は、作業ブランチへ最新の `origin/honsen` を取り込み、再検証してpushします。

## 今できる検証

Python 3.12以降を使います。追加パッケージは不要です。

```bash
python3 tool/check_skills.py
python3 tool/check_skills.py --self-test
git diff --check
```

[Honsen development checks](.github/workflows/check.yml) の `check` ジョブは、Skillsのメタデータ・参照・ハッシュ、検証ツールのself-test、差分の空白を確認します。`honsen` とその作業ブランチでは、`lib/` や `pubspec.yaml` などを禁止するキット専用検査は実行しません。

**アプリの解析・テスト・ビルドや実機操作はまだ検証しません。** 基盤を作る際に、固定したSDK・依存ロックに合う検証をCIへ追加します。

## main の共通キットとの関係

このブランチは [main のコミット 72e4b95](https://github.com/mizugramming/SPAJAM2026/commit/72e4b951599f95bb26eb8fc7e09ab18ed1b42349) を起点に準備しています。`AGENTS.md`、`.agents/`、ライセンス、`templates/`、キット用ツールは引き継いでいます。

本選アプリの変更を `main` へ丸ごとマージしません。`main` の共通ルール更新が必要な場合も、対象ファイルの差分を確認して本選の作業ブランチへ反映します。詳しくは[リポジトリの運用](docs/repository_maintenance.md)を参照してください。

`tool/check_kit.py` は `main` の開発キット用として保持し、本選の検証コマンドには使いません。`docs/development-kit/` の調査・試行・修正記録はキット作成時の履歴であり、本選アプリの仕様や動作確認結果ではありません。

Claude用入口の同期と共有ZIPのself-testを含む、現在の検証一覧は[開発手順](docs/development.md)を参照してください。
