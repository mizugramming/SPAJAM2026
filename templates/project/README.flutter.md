# Flutterアプリの共同開発手順

本番用リポジトリを取得済み・開発環境を準備済みのPC向けです。取得済みならcloneは不要です。未取得の人は[初回準備](docs/development.md)に従います。古いアプリやキットのフォルダでは実行しません。

作成者が配布前に記入します。

- 本番用リポジトリ（OWNER/REPOとURL）：未記入。
- リリース先：未記入。統合先は下記の `develop`。
- 統合担当／その人のPRを承認する担当：未記入。
- 番号・担当者・編集範囲・組み込み担当：[構成と担当](docs/project_structure.md)へ記入。
- 必須チェック・人の承認数：[環境](docs/development.md)へ記入。通常PRは作成者以外1人を基本案とする。

番号ブランチを使い続けるため、作成者はGitHubのマージ後自動削除を無効にし、merge commit方式を使用することを確認します。通常の作業で保護の迂回は行いません。

最初に次を実行し、対象リポジトリと既存変更を確認してください。

```bash
git remote -v
git status --short --branch
```

全員が同じ基盤で起動・主要操作を確認してから担当開発へ進みます。担当者が普段読む入口はこのREADMEです。AIには開始・再開プロンプトを渡し、資料の詳細はAIと必要な箇所だけ確認します。

各コマンドは1行ずつ実行し、エラー時は次へ進みません。[保存・競合・エラー時の対応](docs/development.md)を確認してください。

開発者ごとに **`1`・`2`・`3`・`4`** のどれかを割り当て、担当画面が変わっても同じ番号を使います。同じ番号を複数人で使いません。

作成者は配布前に、このREADMEの `develop` をひな形の統合ブランチ名に置き換えてください。各開発者は自分の番号のコマンドをコピーして使えます。

## 1. 自分のブランチで作業する

未コミットの変更があれば、先に元の作業ブランチへ保存します。ファイルをエディタで保存するだけでは不十分です。[開発手順](docs/development.md)の途中コミットで保護し、作業ツリーがクリーンな状態で切り替え・取り込みを行います。**初回だけ、自分の番号のブロックを1つ実行します。**

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

番号のリモートブランチが既にある場合は上の新規作成をせず、`git fetch origin` 後に `git switch --track origin/1` のように自分の番号を取得します（ローカルに同名ブランチがない場合）。同じ番号を別の人に割り当てないでください。

**2回目以降は新規作成せず**、自分の番号に応じて `git switch 1` / `git switch 2` / `git switch 3` / `git switch 4` で切り替えます。別PCで同じ番号へpushした変更がある場合は、切り替え後に `git pull --ff-only` で取り込みます。

指定SDKが未導入なら、以下の依存取得より先に `fvm install --skip-pub-get` を実行します。Flutterは `.fvmrc` の指定版を使い、[環境資料](docs/development.md)のバージョン・環境チェックを済ませます。

以下は全員共通です。自分の番号のブランチで、毎回実行します。

```bash
git fetch origin
git merge origin/develop
fvm flutter pub get --enforce-lockfile
fvm flutter run --no-pub
```

起動先を選べない場合は環境資料の対象端末と起動コマンドを確認します。

起動後、自分の担当部分を編集します。AIには配置済みの `docs/ai_prompts.md` の開始・再開プロンプトを渡します。資料：[設計書](docs/app_design.md)・[構成と担当](docs/project_structure.md)・[環境](docs/development.md)・[素材](docs/assets.md)。

## 2. 作業が終わったら検証して共有する

ページ単位のPRで構いません。共有データ・保存・画面遷移への接続が未確認なら、まず接続が動く段階でPRを出し、その後にページを仕上げます。未完成部分が既存操作を壊す場合はDraftで共有し、マージしません。同じ番号では同時に複数PRを進めません。PR提出後はそのPRの修正だけを行い、次の別作業はマージ後に統合版を取り込んでから始めます。追加pushは提出済みPRにも入ります。

アプリを停止し、未コミット変更を途中コミットで保護してから `git fetch origin` → `git merge origin/develop` → `fvm flutter pub get --enforce-lockfile` を順に実行します。競合は開発手順に従って解決し、次の検証へ進みます。ここではアプリの再起動は不要です。ファイル名とコミットメッセージは実際の変更に合わせます。[環境資料](docs/development.md)に追加の必須検証があれば、それも実行します。

```bash
fvm flutter analyze --no-pub
fvm flutter test --no-pub
git diff --check
git status --short
git diff
git diff --stat origin/develop...HEAD
git diff origin/develop...HEAD
git add -- "変更したファイルのパス"
git diff --cached
git commit -m "担当部分の変更内容"
git push -u origin HEAD
gh pr create --repo OWNER/REPO --base develop
```

途中コミット済みで未コミット差分がなければ、`git add` から `git commit` までは省略し、検証後にpushします。未コミット差分だけでなく、上記の `origin/develop...HEAD` でPR全体のコミット済み差分も確認します。

`OWNER/REPO` は配布前に作成者が本番用の値へ置き換えます。PR作成後も宛先とFiles changedを確認し、他アプリ・他担当の意図しない差分がないことを確かめます。

`HEAD` は現在の番号ブランチを指すため、pushコマンドの書き換えは不要です。変更ファイルが複数あれば `git add` に並べます。PR作成時は変更内容と検証結果を入力します。同じ作業のPRが既にある場合は、pushまでで更新されるので `gh pr create` は不要です。

## 3. 確認してマージする

[開発手順のAI監査](docs/development.md)と人による仕様・操作確認を行います。作成者本人の承認で済ませず、必要な承認を別の担当から得ます。

統合担当は対象のPR番号を指定します。`PR番号` は実際の番号に置き換え、宛先・差分・最新コミットを確認します。

```bash
gh pr view PR番号 --repo OWNER/REPO
gh pr diff PR番号 --repo OWNER/REPO --name-only
gh pr checks PR番号 --repo OWNER/REPO --required --watch
```

必須チェックの成功・競合なし・必要な人の承認とレビュー会話の解決を確認したら、実行します。チェックなし・失敗・実行中・キャンセル・想定した検証のskipは成功扱いにしません。監査後にコミットが変わった場合は再確認します。保護設定に止められても `--admin` で迂回しません。

```bash
gh pr merge PR番号 --repo OWNER/REPO --merge
```

マージ後も番号ブランチは削除せず、次の作業前に手順1の共通コマンドで統合版を取り込みます。

他の人が先にマージした場合は、`git fetch origin` → `git merge origin/develop` → 依存取得・検証 → `git push` → 必須チェック確認をやり直してからマージします。

各コマンドは1行ずつ実行し、競合やエラーが出たらそこで止めて解決してください。
