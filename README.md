# 本番開発の準備（honban）

## 今回の本番仕様（AI・基盤作成者は先に読む）

- 本番の設計書：[docs/app_design.md](docs/app_design.md)。動作確認端末は **Xiaomi REDMI Note 15 5G**。
- Androidスマホのタッチ操作・縦向きを基本に骨組みを作る。画面全体の寸法・倍率を各ページで独自変更しない。詳細は設計書の共通レイアウト規則に従う。
- 本番作業の統合先・PR先は **`honban`**。`main` は再利用する共同開発キットの保管先であり、本番固有の変更を戻さない。
- 現在は資料準備段階。アプリコード・共通レイアウト・固定SDKは未実装／未確定で、実機での論理サイズも未計測。資料だけで画面制御が実装されたとは扱わない。
- 基盤作成時はこの設計書を正本として拡充し、下記の未記入の雛形で上書きしない。既存の開始プロンプトは基盤完成後の担当開発用。

## 始める前に

基盤完成後の各担当は、AIに指示を出す前に[担当作業の開始・再開プロンプト](docs/ai_prompts.md)をそのまま渡してください。AIがルール・設計書・実際の構成を確認し、まだ伝わっていない担当と変更内容を質問します。

アプリの基盤は作成者が用意します。以下はmainから引き継いだ再利用キットの案内です。honbanでは上記の本番仕様を優先し、基盤完成後に実際の起動・検証手順を追記します。

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
docs/repository_maintenance.md    このリポジトリのブランチ運用・旧アプリの保管先
templates/project/               アプリごとに作成者が完成させる資料の雛形
.github/copilot-instructions.md   再利用するAI向けの入口
.github/PULL_REQUEST_TEMPLATE.md  このキットの変更をレビューする様式
.github/workflows/check.yml      このキットの文書・構成チェック
tool/check_kit.py                 上記チェックの実装
```

このキットのCIやチェックツールは、アプリ用のCIとは用途が異なります。アプリではSDK固定・依存ロック・解析・テスト・ビルド・ブランチ保護を別途用意します。

## このブランチの資料を変更するとき

作業ブランチから `honban` 向けにPRを作成します。文書は `docs/`、アプリごとの資料雛形は `templates/project/`、共通ルール・AI指示・CIは共通管理です。担当範囲は依頼に応じて確認してください。

ローカルの検証にはPython 3.12以降を使います。追加パッケージは不要です。

```bash
python3 tool/check_kit.py
git diff --check
```

現在の資料CIのチェック名は `check` です。GitHubの必須設定の有無は別途確認します。資料の有無・ローカルリンク先・アプリ固有ファイルの混入を検査します。文意、外部URLの有効性、アプリの起動までは検査しません。

現在開発中のアプリとmainは用途が異なります。[このリポジトリの運用](docs/repository_maintenance.md)を確認し、相互にブランチ全体をマージしないでください。
