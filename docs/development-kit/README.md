# 本選の開発体制

これはFlutterスマホアプリのための開発キットです。この `honsen` ブランチでは本選のアプリ基盤を作成します。テーマ・仕様・SDK・大会条件は未決定で、アプリ本体はまだありません。現在の統合先と手順は[ルートREADME](../../README.md)と[本選の開発手順](../development.md)を参照してください。

## 使うもの

| 入口 | 役割 |
|---|---|
| [AGENTS.md](../../AGENTS.md) | 毎日の担当・共通管理・環境・統合・検証の約束 |
| [事前登録した利用端末](devices.md) | 今後使う実機の機種と未確認事項。開発開始時に参照する |
| [spajam-flutter-delivery](../../.agents/skills/spajam-flutter-delivery/SKILL.md) | 認識合わせ → 初期実装 → UI/端末確認 → 引き継ぎ。既存UIやボタン単位の改善にも使う |
| [spajam-feedback](../../.agents/skills/spajam-feedback/SKILL.md) | 提供記録を事実・推測・適用条件に分け、既存手順へ反映 |
| [spajam-run-app](../../.agents/skills/spajam-run-app/SKILL.md) | 既存の方法で開く・開き直す・発表用画面を準備し、利用者側の表示を確認 |
| [flutter-fix-layout-issues](../../.agents/skills/flutter-fix-layout-issues/SKILL.md) | 制約違反・overflowの原因と修正 |
| [flutter-add-widget-test](../../.agents/skills/flutter-add-widget-test/SKILL.md) | 入力・タップ・スクロールと状態反映を確かめるWidgetテスト |
| [本選の設計資料](../app_design.md) / `templates/project/` | 本選の資料は `docs/` へ展開済み。元の雛形は参照用として保持 |

普段は該当Skillだけ読みます。UI、端末、共同開発の専用Skillをさらに並べず、初期開発Skillの参照資料へまとめています。[調査記録](research.md)、[試行記録](trial.md)、[修正記録の反映](feedback-applied.md)は、共通キット作成時の履歴です。そこに登場する旧アプリ・SDK・ブランチ・結果を、本選アプリの仕様や検証実績として扱いません。

使用するスマホは事前登録を参照するため、毎回の依頼で機種名を入力し直す必要はありません。追加のOS・端末、台数や通信など新しい条件があれば伝えてください。

## GitHubからの再現

現行Codexのリポジトリ用配置は `.agents/skills/<name>/SKILL.md` です。`name` と `description` をYAML frontmatterへ記載し、必要なときだけ本文・参照資料を読みます。[公式仕様](https://learn.chatgpt.com/docs/build-skills)

1. このブランチのファイルをGitHubで共有し、同じコミットを取得する。個人用Skillsフォルダへのインストールは不要。
2. リポジトリのルートでCodexを開始し、Skill名を明示して使う。導入後は次のターンから利用する。表示されなければCodexを再起動し、一覧と読み込んだファイルを確認する。
3. 外部のプラグイン、MCP、Figma、GitHub CLIの認証はこのキットだけでは有効にならない。必要な機能だけ各環境で準備する。Skill内に個人の絶対パスや鍵を保存しない。

Claude Codeでは `CLAUDE.md` と `.claude/skills/` から同じ本文を読み、`/spajam-flutter-delivery` などで呼び出します。[別PCの準備・分担・レビュー・更新手順](claude-code.md)にまとめています。CodexとClaudeで同じファイルを並行編集せず、担当と接続仕様を共有します。

ユーザー提供のUIサンプルは[UI参考資料](ui-references.md)から確認できます。見本名と採用したい操作を指定し、コンセプトに合わせてFlutterへ設計します。

公式Skillsは固定コミットを元に同梱しています。mainの差分チェックに合わせて行末空白4箇所だけを除去し、手順の内容は維持しています。元のハッシュ・変更後のハッシュ・変更内容も記録しています。取得元とファイルハッシュは [.agents/skills-lock.json](../../.agents/skills-lock.json)、配布条件は [Flutterのライセンス](../../.agents/third-party/flutter-agent-plugins.LICENSE) にあります。clone後の再ダウンロードは不要です。更新時だけ本文・差分を再確認し、固定コミット・ハッシュ・必要なライセンスを一緒に更新します。`metadata.model` は導入元の付加情報であり、このキットはモデル変更を設定しません。

別のプロジェクトへの移し方は[共通セットの再利用](../reuse_rules.md)にまとめています。今回の `honsen` は同じリポジトリの `main` から共通ファイルを継承し、本選の資料を配置済みです。旧アプリのコード・設定・ロックは流用しません。統合先は `honsen` で、旧番号ブランチや `develop` は今回の既定にしません。

## 検証

Python 3.12以降・標準ライブラリで、ルートから実行できます。以下は `honsen` と本選の作業ブランチで行う確認です。アプリ基盤を作ったら、[開発手順](../development.md)に記載するアプリ用の検証も加えます。

```bash
python3 tool/check_skills.py
python3 tool/check_skills.py --self-test
python3 tool/sync_claude_skills.py --check
python3 tool/sync_claude_skills.py --self-test
git diff --check
git diff --name-only
git status --short --branch
```

`check_skills.py` は同梱Skillsの単一行の識別情報、名前、UIメタデータ、ローカル参照、導入元の固定値・ハッシュを検査します。汎用YAMLパーサーやCodexの自動選択試験ではありません。新しい形式へ広げる際は `skill-creator` の `quick_validate.py` でも検証します。`tool/check_kit.py` は `main` のキット専用として保持し、アプリファイルを置く `honsen` の検証には使いません。

アプリ開発時は今回のREADME・環境資料にあるSDK・依存取得・解析・テスト・ビルドのコマンドを使います。SDK値をSkillsへ固定しません。端末の操作確認はビルドと分けて記録します。

## 本選で最初に送るプロンプト

[穴埋め式の初期プロンプト](initial-prompt.md)をコピーして使います。アイデア・利用者と場面・一番大切な体験を中心に、分かる項目だけ記入してください。未定の内容は具体案を添えて確認します。

登録済み端末は自動的に参照するよう指示しています。参考画像は任意で、ある場合は取り入れたい点と、雰囲気の参考・配置の指定・使用素材のどれかを伝えられます。

## UI/UXとボタンを磨く入力例

```text
$spajam-flutter-delivery
この画面のUI/UXを改善してください。
コンセプトに合う見た目と、主操作への分かりやすさを確認し、
配色・日本語フォント・余白・素材の組み合わせを、採用理由も含めて点検してください。
ボタンやリンクを一つずつ、文言・配置・押しやすさ・反応・状態ごとに点検してください。
修正後は同じ条件の画面と実操作で再確認し、確認できない項目は残してください。
```

対象を「保存ボタンだけ」、範囲を「今回は指摘と改善案まで」と絞ることもできます。企画全体の認識合わせへ戻さず、指定した範囲で使います。

## 後から修正記録を渡す入力例

```text
$spajam-feedback を使って、以下の修正記録を反映してください。
指摘→原因→採用修正→適用条件→次回の確認方法で整理し、事実と推測を分けてください。
既存の手順へ統合し、アプリ固有の好みや理由不明の変更は必須ルールにしないでください。
今回はSkills・ルール・資料への反映までで、アプリコードは変更しません。
【修正記録】
ここへ貼り付け、または保存したファイルの場所を伝える。
```

共通キットでは旧アプリ「つなぐん」の記録を、根拠と適用条件に分けて手順へ反映しています。本選で新しく得た記録は、同じ入力例を使い、今回の事実と適用条件を確認して追加します。
