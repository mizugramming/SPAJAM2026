# 調査と採用の記録

確認日：2026-11-17（日本時間）。取得した本文・ファイルと、ここで確認した環境を根拠にしています。過去の会話や修正理由は補っていません。

## 作業対象と既存資料

- 作業フォルダ：SPAJAM2026。開始ブランチは `docs/chat-feedback-skills`、基点は `d61a233`。`origin` は `mizugramming/SPAJAM2026`。
- 開始時から `ios/`、`linux/`、`macos/`、`windows/` が未追跡で、変更していない。作業途中に追加された `docs/retrospectives/tsunagun-chat-feedback-for-skills.md` は、その後ユーザーが完成を連絡して指定したため、原資料を保持して知見を反映した。
- READMEの統合先は既存アプリ用 `honban`。共通キットの `main` と全体マージしない運用。今回はローカルファイルの準備であり、fetch/merge/push/PR作成・公開は行わない。将来共有する際は最新状態と対象差分を再確認する。
- 調査した資料：ルートのAGENTS/README、開発環境、構成・共通接続、端末設計、最新決定、画面文言、実機検証、再利用・リポジトリ運用、提供設計書の案内と出典一覧、既存テンプレート。

## 既存実装から再利用する考え方

| 確認した場所 | 観察した事実 | 次のアプリでの利用条件 |
|---|---|---|
| `lib/app/tsunagun_app.dart`、`lib/app/tsunagun_theme.dart` | 共通枠、色・文字・入力・ボタンを集中管理 | 共通の判断・部品はまとめる。412×900のPCプレビューや配色・書体は引き継がない |
| `docs/feature_integration.md`、`lib/data/`・`lib/domain/` | 画面、単一の状態、通信/保存、報酬モデルの責任を分けている | データの正本と入出力を共有する。ChangeNotifier・Cloudflare等の採用義務にしない |
| `lib/features/duel/`・`cooperative/` と親のゲーム接続 | 機能別のファイルと結果通知で親へつなぐ | 機能・部品単位で分担し、親と共通契約は統合担当へ集約する |
| `test/app/phone_viewport_test.dart`、`test/features/` | 論理領域・文字拡大・insetsとタップ、UI操作を検証 | 次の対象端末・状態に合わせて条件を選ぶ。テストだけで実機成功にしない |
| `docs/device_validation.md` | Web操作、APK導入、実機の画面・ゲーム確認を区別 | 方法・操作・結果・未確認を分けて記録する。過去の成功結果を再実行の代用にしない |

大きな親画面が存在することも確認したため、構成全体をそのまま推奨雛形にしません。既存コードは観察材料であり、当時の修正経緯・ユーザーの意図を証明する資料とは扱いません。

## 既存Skillsの候補比較

OpenAIの `skill-installer` で公式公開一覧を取得し、Flutter公式リポジトリと合わせて候補の本文を確認しました。以下は採否を判断した候補で、一覧の全件調査を意味しません。

| 導入元・候補 | 用途・Flutterへの適合 | 重複・制約と判断 |
|---|---|---|
| Flutter公式 `flutter-fix-layout-issues` | overflow・無限制約・親子関係の診断。Flutterへ直接適合 | **採用**。初期開発Skillから必要時に呼ぶ。記述はMCPに言及するが、本文の診断はCLIでも利用できる |
| Flutter公式 `flutter-add-widget-test` | `WidgetTester`で入力・タップ・スクロールと状態反映を検証 | **採用**。具体的な補助手順として重複が少ない。依存追加や実行はプロジェクトの固定環境に従う |
| Flutter公式 `flutter-build-responsive-layout` | 親制約・`LayoutBuilder`等を扱う | 見送り。大型画面対応・向きの方針まで含み、今回の対象と既存の共通枠へ無条件適用できない |
| Flutter公式 `flutter-apply-architecture-best-practices` | UI/Logic/Dataの構成 | 見送り。本文がMVVM、モデル生成パッケージ、DI登録を一律に求め、小規模・短時間の判断を狭める |
| Flutter公式 `flutter-add-integration-test` | 端末上の導線テスト | 見送り。MCP、Driver用設定・依存追加を前提とする手順を今は増やさず、アプリ決定後に再評価する |
| OpenAI公式 `gh-address-comments` | GitHubのレビュー読取と対応 | 見送り。番号指定の確認・gh認証が中心で、既存のPRルールと重なる。必要時に追加できる |
| OpenAI公式 `gh-fix-ci` | GitHub Actionsの失敗調査 | 見送り。CI専用で今回の不足と異なり、修正前の承認手順も含む。通常の共同開発はAGENTSと引き継ぎ手順で扱う |
| 内蔵 `skill-creator`・`skill-installer`・`openai-docs` | 作成・導入・Codex仕様調査 | 今回使用。内蔵のためリポジトリへ重複導入しない |

採用した公式Skillsの導入元は [flutter/agent-plugins](https://github.com/flutter/agent-plugins)、固定コミットは `17fe9182f4c462d69d6a7963aef01b44b1f7f189`。`skill-installer` のGitHub導入スクリプトに `--repo flutter/agent-plugins --ref 上記コミット --path skills/flutter-fix-layout-issues skills/flutter-add-widget-test --dest .agents/skills` を指定して導入しました。固定コミットの内容を保持し、mainの差分チェックに合わせて行末空白4箇所だけを除去しています。BSD-3-Clauseのライセンス、元のハッシュと変更後のハッシュ・変更内容を同梱しています。

初版では初期開発と修正記録の専用2本で補い、その後受領した記録で繰り返し問題になった起動確認を別の手順として1本追加しました。最終構成は公式2本＋専用3本です。UI/文言・素材/演出・端末・引き継ぎは、条件に応じて読む参照資料にまとめています。詳細は[記録の反映](feedback-applied.md)にあります。

## 配置・形式の確認元

- [CodexのSkills仕様](https://learn.chatgpt.com/docs/build-skills)：リポジトリの `.agents/skills`、YAML frontmatter、明示呼び出しと段階的な読込。
- [AGENTS.mdの仕様](https://learn.chatgpt.com/docs/agent-configuration/agents-md)：ルート・下位ディレクトリの指示、読込順とサイズ制限。常時読むファイルには日常ルールを残す。
- [Flutter公式AIツール](https://docs.flutter.dev/ai/tools)：公式Skillsの位置付け。プラグイン全体は導入せず、必要なSkillのみ同梱。
- [OpenAI公式Skills](https://github.com/openai/skills)：公式一覧、`gh-fix-ci`、`gh-address-comments` の本文を確認。

内蔵のCodexマニュアル取得ヘルパーはサンドボックス内のDNS解決で失敗したため、上記の公式ページをブラウズして配置・形式を確認しました。ローカルに存在しないマニュアルを読んだとは扱いません。

## 今回の開発・検証環境

| 項目 | 今回確認した結果 |
|---|---|
| OS | Ubuntu 24.04 / WSL2 |
| 固定環境 | `.fvmrc`：Flutter 3.41.5、`tool/toolchain.json`：Dart 3.11.3・Java 17。実行結果も一致 |
| Flutter doctor | ChromeとLinuxを検出。Android SDKあり・一部ライセンス未承諾。Linuxビルド用ツールに不足 |
| スマホ検証先 | doctorの出力に実機・エミュレーターなし。今回スマホ操作は未確認 |
| 文書検証 | Python 3.12.3、標準ライブラリ。内蔵Skillの形式検証には既存のPyYAML 6.0.1を利用可能 |
| その他 | Node、gh、Codexあり。今回GitHub認証・push権限・ブランチ保護は未確認 |

SDKの通常キャッシュ更新には、この環境の権限制約により実行時の昇格が必要でした。SDK・依存のバージョン、Androidライセンスの承諾設定、個人設定は今回の準備のために変更していません。これらの数値は現状記録であり、次アプリの必須値ではありません。

大会の持ち込み・時間・提出条件は、今回の依頼に具体的な対象資料がないため未確認です。提供PDFは既存アプリの原図資料として案内されており、大会規約の証拠にしていません。
