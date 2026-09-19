# Flutterアプリの共同開発手順

同じリポジトリを取得済み・開発環境を準備済みのPC向けです。**cloneは不要です。** 既存のプロジェクトフォルダで実行します。

`develop` は作成者がひな形を共有する統合ブランチの例です。作成者が実際の名前に置き換えて共有してください。`feature/my-task` は自分の作業ブランチ名に置き換えます。

## 1. 最新のひな形を取り込んで作業する

未コミットの変更があれば、先に自分の作業ブランチへ保存します。

```bash
git fetch origin
git switch feature/my-task
git pull --ff-only
git merge origin/develop
fvm flutter pub get --enforce-lockfile
fvm flutter run --no-pub
```

まだ作業ブランチがない場合は、`git switch` と `git pull` の代わりに `git switch -c feature/my-task origin/develop` を実行します。初回push前で追跡先がない場合は `git pull --ff-only` を省略します。

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
git push -u origin feature/my-task
gh pr create --base develop
```

変更ファイルが複数あれば `git add` に並べます。PR作成時は変更内容と検証結果を入力します。同じ作業のPRが既にある場合は、pushまでで更新されるので `gh pr create` は不要です。

## 3. 確認してマージする

自分の作業ブランチ上で、マージを担当する人が実行します。

```bash
gh pr checks --required --watch
```

必須チェックの成功・競合なし・必要なレビューの完了を確認したら、実行します。

```bash
gh pr merge --merge
```

他の人が先にマージした場合は、`git fetch origin` → `git merge origin/develop` → 依存取得・検証 → `git push` → 必須チェック確認をやり直してからマージします。

各コマンドは1行ずつ実行し、競合やエラーが出たらそこで止めて解決してください。
