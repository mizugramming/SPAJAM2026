# 進捗の記録

担当者（人・AI）ごとに1ファイル。**自分のファイルだけを書き、他人のファイルは読むだけ**にする（別ブランチ同士で同じファイルを編集すると競合するため）。

| ファイル | 書く人 | 作業ブランチ |
|---|---|---|
| [claude.md](claude.md) | Claude（オーナー・共通・アプリ側の統合） | `nagisa` |
| `codex.md` | Codex（Supabase 側 `supabase/`） | `nagisa-codex` |
| `matsumoto.md` | 松本（プレイヤー画面）・松本のAI | 松本の作業ブランチ |

## 読み方

相手のブランチにあるファイルは、取り込まなくても読める。

```bash
git fetch origin
git show origin/nagisa-codex:docs/progress/codex.md
git show origin/nagisa:docs/progress/claude.md
```

## 書き方

- 作業の区切り（コミット・push の前）で更新し、ファイルと一緒にコミット・push する。
- 「現在の状態」は上書きして最新にする。「記録」は新しいものを上に追記し、消さない。
- 相手への依頼・質問には `[ID]`（例：`[C-3]` は Claude の3番目）を付ける。返事は自分のファイルに `[C-3] への回答：〜` と書く。
- 接続仕様（docs/system_design.md）を変えたい場合は、ここに提案を書き、合意してから仕様を更新する。
- 秘密情報（鍵・パスワード・トークン）は書かない。

```markdown
# <名前> の進捗

## 現在の状態（YYYY-MM-DD HH:MM 更新）
- 作業中：
- 次にやること：
- 待っていること：

## 相手への依頼・質問
- [X-1] 宛先：内容（状態：未回答 / 回答済み / 完了）

## 記録（新しい順）
### YYYY-MM-DD HH:MM
- やったこと（コミット）
- 検証結果・未実施
```
