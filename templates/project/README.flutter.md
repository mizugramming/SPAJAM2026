# Flutterアプリの共同開発手順

同じリポジトリを取得済み・開発環境を準備済みのPC向けです。**cloneは不要です。** 既存のプロジェクトフォルダで実行します。

開発者ごとに **`1`・`2`・`3`・`4`** のどれかを割り当て、担当画面が変わっても同じ番号を使います。同じ番号を複数人で使いません。

作成者は配布前に、このREADMEの `develop` をひな形の統合ブランチ名に置き換えてください。各開発者は自分の番号のコマンドをコピーして使えます。

## 1. 自分のブランチで作業する

未コミットの変更があれば、先に元の作業ブランチへ保存します。**初回だけ、自分の番号のブロックを1つ実行します。**

### 開発者1

```bash
git fetch origin
git switch --no-track -c 1 origin/develop
```

### 開発者2

```bash
git fetch origin
git switch --no-track -c 2 origin/develop
```

### 開発者3

```bash
git fetch origin
git switch --no-track -c 3 origin/develop
```

### 開発者4

```bash
git fetch origin
git switch --no-track -c 4 origin/develop
```

**2回目以降は新規作成せず**、自分の番号に応じて `git switch 1` / `git switch 2` / `git switch 3` / `git switch 4` で切り替えます。別PCで同じ番号へpushした変更がある場合は、切り替え後に `git pull --ff-only` で取り込みます。

以下は全員共通です。自分の番号のブランチで、毎回実行します。

```bash
git fetch origin
git merge origin/develop
fvm flutter pub get --enforce-lockfile
fvm flutter run --no-pub
```

指定SDKが未導入の場合だけ `fvm install --skip-pub-get` を実行します。Flutterは `.fvmrc` の指定版を使います。

起動後、自分の担当部分を編集します。AIには配置済みの `docs/ai_prompts.md` の開始・再開プロンプトを渡します。資料：[設計書](docs/app_design.md)・[構成と担当](docs/project_structure.md)・[環境](docs/development.md)・[素材](docs/assets.md)。

## 2. 作業が終わったら検証して共有する

アプリを停止してから実行します。ファイル名とコミットメッセージは実際の変更に合わせます。[環境資料](docs/development.md)に追加の必須検証があれば、それも実行します。

```bash
fvm flutter analyze --no-pub
fvm flutter test --no-pub
git diff --check
git diff
git add -- "変更したファイルのパス"
git diff --cached
git commit -m "担当部分の変更内容"
git push -u origin HEAD
gh pr create --base develop
```

`HEAD` は現在の番号ブランチを指すため、pushコマンドの書き換えは不要です。変更ファイルが複数あれば `git add` に並べます。PR作成時は変更内容と検証結果を入力します。同じ作業のPRが既にある場合は、pushまでで更新されるので `gh pr create` は不要です。

## 3. 確認してマージする

自分の作業ブランチ上で、マージを担当する人が実行します。

```bash
gh pr checks --required --watch
```

必須チェックの成功・競合なし・必要なレビューの完了を確認したら、実行します。

```bash
gh pr merge --merge
```

マージ後も番号ブランチは削除せず、次の作業前に手順1の共通コマンドで統合版を取り込みます。

他の人が先にマージした場合は、`git fetch origin` → `git merge origin/develop` → 依存取得・検証 → `git push` → 必須チェック確認をやり直してからマージします。

各コマンドは1行ずつ実行し、競合やエラーが出たらそこで止めて解決してください。
