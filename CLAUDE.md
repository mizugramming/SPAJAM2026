@AGENTS.md

## Claude Codeの入口

- 最初にREADMEを読み、今回の設計・担当・環境・統合先を確認する。
- `.claude/skills/` は呼び出し口。手順の正本は `.agents/skills/` にあり、必要なSkillと参照資料だけ読む。生成された呼び出し口を直接編集しない。
- 共有本文にある `$skill-name` はSkillへの参照。Claude Codeでは対応する `/skill-name` を使うか、その共有本文を直接読む。Codex専用のUIメタデータでClaudeのモデルを変更しない。
- 別PCの準備、Codexとの分担、差分レビュー、引き継ぎは[Claudeとの共同開発](docs/development-kit/claude-code.md)を、提供されたUI見本を使うときは[UI参考資料](docs/development-kit/ui-references.md)を参照する。
