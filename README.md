# SPAJAM2026

アプリごとに開発ブランチを分けています。現在の「まよいクエスト」は **[`test-1`](https://github.com/mizugramming/SPAJAM2026/tree/test-1)** を開いてください。この `main` は共同開発キットの保管先です。

## 目的別の入口

| 目的 | ブランチ・資料 | PR先 |
|---|---|---|
| まよいクエストの開発 | [`test-1` のREADME](https://github.com/mizugramming/SPAJAM2026/blob/test-1/README.md) | `test-1` |
| つなぐんの確認・保守 | [`honban` のREADME](https://github.com/mizugramming/SPAJAM2026/blob/honban/README.md) | `honban` |
| 余白の確認・保守 | [`rehearsal/02` のREADME](https://github.com/mizugramming/SPAJAM2026/blob/rehearsal/02/README.md) | `rehearsal/02` |
| 初回練習アプリの参照 | [`rehearsal/01`](https://github.com/mizugramming/SPAJAM2026/tree/rehearsal/01) | 続ける場合は目的・統合先を確認 |
| 共通ルール・資料雛形の再利用・改善 | このページの以下の案内 | `main` |

作業・起動・検証は対象ブランチのREADMEに従います。アプリのPRを `main` へ送らず、アプリ間でブランチ全体をマージしないでください。

[ブランチ運用と整理の手順](docs/repository_maintenance.md) ／ [2026-11-04のブランチ・PR棚卸し](docs/repository_inventory_20261104.md)

## 始める前に

AIに指示を出す前に、[担当作業の開始・再開プロンプト](docs/ai_prompts.md)をそのまま渡してください。AIがルール・設計書・実際の構成を確認し、まだ伝わっていない担当と変更内容を質問します。

アプリの基盤は作成者が用意します。このmainは、別のアプリでも使うルール・プロンプト・資料の雛形を保管する場所です。

## 次のアプリへ持っていくもの

| ファイル | 用途 |
|---|---|
| [AGENTS.md](AGENTS.md) | 共通ルールブック。そのまま使う |
| [docs/ai_prompts.md](docs/ai_prompts.md) | 開発者がそのままAIへ渡すプロンプト |
| [CLAUDE.md](CLAUDE.md) / [.github/copilot-instructions.md](.github/copilot-instructions.md) | 利用するAI向けの入口 |
| [templates/project/](templates/project/README.md) | 今回のREADME・設計・構成・環境・素材管理・PRの雛形 |
| [Flutter用README](templates/project/README.flutter.md) | 開発者1〜4の番号別コマンドと、更新・開発・PR・マージの手順 |

[コピーと引き渡しの手順](docs/reuse_rules.md)を参照してください。雛形の内容は、作成者が実装した基盤に合わせて完成させます。担当開発者がプロンプトへ項目を記入する必要はありません。

## このキットの構成

```text
AGENTS.md / CLAUDE.md             再利用するルールとAI向けの入口
docs/ai_prompts.md                担当作業の開始・再開
docs/reuse_rules.md               コピーと引き渡しの手順
docs/repository_maintenance.md    このリポジトリのブランチ運用・整理手順
docs/repository_inventory_*.md    日付付きのブランチ・PR棚卸し
templates/project/               アプリごとに作成者が完成させる資料の雛形
.github/copilot-instructions.md   再利用するAI向けの入口
.github/PULL_REQUEST_TEMPLATE.md  対象・PR先・変更範囲・検証を記録する様式
.github/workflows/check.yml      このキットの文書・構成チェック
tool/check_kit.py                 上記チェックの実装
```

このキットのCIやチェックツールは、アプリ用のCIとは用途が異なります。アプリではSDK固定・依存ロック・解析・テスト・ビルド・ブランチ保護を別途用意します。

## このキットを変更するとき

作業ブランチから `main` 向けにPRを作成します。文書は `docs/`、アプリごとの資料雛形は `templates/project/`、共通ルール・AI指示・CIは共通管理です。担当範囲は依頼に応じて確認してください。

ローカルの検証にはPython 3.12以降を使います。追加パッケージは不要です。

```bash
python3 tool/check_kit.py
git diff --check
```

必須チェック名は `check` です。資料の有無・ローカルリンク先・アプリ固有ファイルの混入を検査します。文意、外部URLの有効性、アプリの起動までは検査しません。

現在開発中のアプリとmainは用途が異なります。[このリポジトリの運用](docs/repository_maintenance.md)を確認し、相互にブランチ全体をマージしないでください。
