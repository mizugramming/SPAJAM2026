# Flutterアプリ：cloneから開発・マージまで

作成者が用意した基盤を取得し、各担当が自分のPCで開発するための手順です。基盤を作成し直す必要はありません。

**作成者へ：配布前に次の表と、このREADME中の `OWNER/APP`・`develop` を実際の値に置き換えてください。** `feature/my-task` は各開発者の作業ブランチ例です。AIに担当を答えると、その担当とタスクに合う名前・変更ファイルを調べてコマンドを提示できます。共通キット自体のリポジトリをclone先に指定しないでください。

| 項目 | このアプリの値 |
|---|---|
| リポジトリ | `https://github.com/OWNER/APP.git` |
| 統合ブランチ | `develop`（このREADMEの例） |
| リリース先 | 作成者が記載。統合先と同じ場合はその旨を記載 |
| Flutter | `.fvmrc` にコミットされた固定版。各自で最新版へ変更しない |
| Dart | 指定Flutterに同梱された版を使う |
| AndroidのJDK・SDK・NDK | 作成者が[環境資料](docs/development.md)へ検証済みの値を記載 |
| 必須CIチェック・レビュー方針 | 作成者が記載 |
| 統合担当・担当フォルダ | 作成者が[構成・接続資料](docs/project_structure.md)へ記載 |

作成者は `.fvmrc`、`pubspec.yaml`、`pubspec.lock`、アプリ用CI、`lib/`・`test/`、対象プラットフォームを用意してから共有します。`.fvm/`・SDK・キャッシュはGitへ含めません。FVMによる意図しない設定更新を避けるため、`.fvmrc` の `updateVscodeSettings`・`updateGitIgnore`・`runPubGetOnSdkChanges` を `false` にし、必要なIDE設定や `.gitignore` は作成者が共有します。

コマンドは1行ずつ実行し、エラーが出たらそこで止めます。WindowsはPowerShell、macOSはターミナル、UbuntuはBashを使います。OS別と書いた箇所以外の `git`・`gh`・`fvm` コマンドは共通です。

## 1. 初回だけ：PCにツールを入れる

必要なのはGit、GitHub CLI（`gh`）、FVM、ブラウザです。Flutter SDKはclone後にFVMで指定版を取得します。既に導入済みのツールは再インストール不要です。

### Windows：PowerShell

WindowsのWinGetが使える環境で実行します。見つからない場合はMicrosoftの「アプリ インストーラー」を用意してください。

```powershell
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
winget install --id Google.Chrome --exact
```

ターミナルを開き直します。FVMは公式のstandalone版をユーザーフォルダへ配置します。以下はWindows x64用です。ARM64ではURLの `windows-x64` を `windows-arm64` に変更します。導入済みならこのブロックは不要です。

```powershell
$fvmInstallDir = Join-Path $env:LOCALAPPDATA "Programs\FVM"
$fvmArchive = Join-Path $env:TEMP ("fvm-" + [guid]::NewGuid().ToString() + ".zip")
Invoke-WebRequest -Uri "https://github.com/leoafarias/fvm/releases/download/4.3.1/fvm-4.3.1-windows-x64.zip" -OutFile $fvmArchive
Expand-Archive -Path $fvmArchive -DestinationPath $fvmInstallDir
$fvmBin = Join-Path $fvmInstallDir "fvm"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $fvmBin) { [Environment]::SetEnvironmentVariable("Path", ($userPath + ";" + $fvmBin), "User") }
$env:Path = $env:Path + ";" + $fvmBin
fvm --version
```

FVM 4.3.1の公式配布構造に合わせた例です。以後はターミナルやIDEを開き直してPATHを反映します。これはアプリのFlutterバージョンの指定ではありません。[FVM公式導入手順](https://fvm.app/documentation/getting-started/installation)も参照できます。

### macOS：ターミナル

[Homebrew](https://brew.sh/)がなければ公式手順で導入します。その後、次を実行します。

```bash
brew install git gh fvm
brew install --cask google-chrome
```

### Ubuntu：Bash（デスクトップ環境）

GitとFVMの導入に必要なツールを用意します。GitHub CLIは公式のパッケージリポジトリを使用します。

```bash
sudo apt update
sudo apt install -y git curl tar unzip xz-utils zip ca-certificates
sudo install -d -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /tmp/githubcli-archive-keyring.gpg
sudo install -m 644 /tmp/githubcli-archive-keyring.gpg /etc/apt/keyrings/githubcli-archive-keyring.gpg
printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update
sudo apt install -y gh
curl -fsSL https://fvm.app/install.sh -o /tmp/install-fvm.sh
bash /tmp/install-fvm.sh
```

FVMのインストーラーが表示するPATH設定を適用し、ターミナルを開き直します。Chromeを使うx86_64環境では次で導入できます。

```bash
curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/google-chrome-stable.deb
sudo apt install -y /tmp/google-chrome-stable.deb
```

ARMなど別の環境は利用できるブラウザとFlutterの対応を確認してください。WSLやGUIのない環境は、このネイティブPC向け手順とは接続・ブラウザ起動方法が異なります。[GitHub CLI公式導入手順](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)も参照できます。

### 全OS共通：確認とGitHubへのログイン

```bash
git --version
gh --version
fvm --version
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
gh auth status
```

ブラウザで自分のGitHubアカウントにログインします。非公開リポジトリの場合は、作成者からの招待を先に承諾してください。トークンをREADMEやチャットへ貼り付ける必要はありません。

## 2. 初回だけ：cloneして自分のブランチを作る

アプリを置きたい親フォルダで実行します。`app-work` はローカルフォルダ名です。同名フォルダが既にあれば、別名を使うか既存のcloneを開いてください。

```bash
git clone --branch develop https://github.com/OWNER/APP.git app-work
cd app-work
git remote -v
git status --short --branch
git switch -c feature/my-task
```

`feature/my-task` は1人・1タスクの固有名にします。同じブランチを他の人と共有しません。既にリモートにある自分の作業を再開する場合は、新規作成の代わりに `git fetch origin`、`git switch --track origin/自分のブランチ名` を使います。

コミットに使う名前とメールを確認します。

```bash
git config user.name
git config user.email
```

未設定なら、次の値を自分のものにして設定します。このリポジトリだけに適用されます。メールはGitHubのSettings → Emailsにある自分のnoreplyアドレスでも構いません。

```bash
git config user.name "自分の表示名"
git config user.email "自分のGitHub登録メールまたはnoreplyアドレス"
```

## 3. 指定版Flutterを入れて起動する

プロジェクトのルート（`pubspec.yaml` のある場所）で実行します。

```bash
fvm install --skip-pub-get
fvm use --skip-pub-get
fvm flutter --version
fvm dart --version
fvm flutter pub get --enforce-lockfile
git diff --exit-code -- .fvmrc pubspec.yaml pubspec.lock
fvm flutter doctor -v
fvm flutter devices
fvm flutter run -d chrome
```

`fvm use` は既存の `.fvmrc` の指定版を使います。ファイルがない場合やバージョンの選択を求められた場合は、勝手に最新版を選ばず作成者へ確認します。環境差を回避するために `pubspec.lock` を削除したり、`pub upgrade` したりしません。

Flutter同梱のDartを使用します。IDEのFlutter SDKも `.fvm/flutter_sdk` に合わせます。VS CodeならFlutter/Dart拡張を導入し、設定後にウィンドウを再読み込みしてください。

Web起動が確認できたら、端末で `q` または `Ctrl+C` を押して停止できます。ブラウザに古い画面が残る場合は再実行・再読み込みします。データを残す場合はブラウザストレージを削除しません。

`doctor` の未完了項目は、今回の対象プラットフォームに必要なものを解決します。Webだけを確認するときに、不要なiOSなどを追加する必要はありません。

## 4. Android実機でも確認する場合

Android Studioと、このアプリで指定されたJDK・SDKを用意します。[環境資料](docs/development.md)の値を使い、最新版という理由で各自変更しません。

Android StudioのSDK Managerで指定SDK Platform、Build Tools、Command-line Tools、Platform Toolsを導入し、必要な場合は指定NDKも導入します。これらはPC側へ入れ、アプリのGitフォルダへSDK本体をコピーしません。[Flutter公式Android準備](https://docs.flutter.dev/platform-integration/android/setup)を参照してください。

実機の開発者向けオプションとUSBデバッグを有効にし、USBで接続して端末の接続許可を承認します。Windowsでは端末用USBドライバーが必要な場合があります。

```bash
java -version
fvm flutter doctor --android-licenses
fvm flutter doctor -v
fvm flutter devices
```

ライセンスの内容を確認して対話で承諾します。`doctor -v` が使うJavaの版がアプリ指定と違う場合だけ、次を実際のインストール先へ置き換えて実行します。

```bash
fvm flutter config --jdk-dir "指定JDKのインストール先"
```

この設定はPC側のFlutter設定です。同じPCの他プロジェクトへの影響も確認してください。

`devices` に表示された実機のIDを指定して起動します。

```bash
fvm flutter run -d "実機のデバイスID"
```

## 5. AIと担当作業を始める

エディターでプロジェクトのルートを開き、配置済みの `docs/ai_prompts.md` の開始用プロンプトをそのままAIへ渡します。

AIが `AGENTS.md` → README → [設計書](docs/app_design.md)・[構成と接続](docs/project_structure.md) → 担当コード・関連テストを確認します。担当と変更内容を質問されたら、画面名や部品名で答えてください。プロンプトへの事前記入は不要です。

共通データ・保存先・画面の接続を使い、担当フォルダで実装します。画像追加は[素材管理](docs/assets.md)に従います。

## 6. 毎回の作業開始：他の人の変更を取り込む

次は自分の作業ブランチ上で、未コミット変更がない状態で実行します。最初のpush前は追跡先がないので `git pull --ff-only` を省略します。追跡先は次の「共有」手順で設定します。

```bash
git status --short --branch
git pull --ff-only
git fetch origin
git merge origin/develop
fvm install --skip-pub-get
fvm use --skip-pub-get
fvm flutter pub get --enforce-lockfile
git diff --exit-code -- .fvmrc pubspec.yaml pubspec.lock
fvm flutter run -d chrome
```

未コミット変更がある場合は、変更ファイルを指定して作業ブランチへコミットしてから更新します。`pull --ff-only` が失敗した場合は履歴を確認し、`reset --hard` やforce pushで解消しません。

## 7. 共有前に検証する

変更したDartファイルだけを整形します。下のファイル名は例なので、AIが実際の変更ファイルを確認して置き換えます。

```bash
fvm dart format "変更したDartファイルのパス"
```

次は全体の検証です。作成者が別の検証コマンドを追加している場合は、それも実行します。

```bash
fvm flutter pub get --enforce-lockfile
git diff --exit-code -- .fvmrc pubspec.yaml pubspec.lock
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build web --release --no-web-resources-cdn --no-pub
git diff --check
git diff --name-only
git status --short
```

この例はWeb対応・テスト配置済みの基盤を前提とします。作成者は対象プラットフォームに合わせて調整します。`tool/` にDartコードがある場合は整形チェック対象にも含めます。Android環境がある場合は次も実行します。

```bash
fvm flutter build apk --debug --no-pub
```

ビルド成功と実機での表示・操作確認は別です。実行していない確認はPRに未実施と記載します。

## 8. コミット・push・PR作成

まず差分を確認します。

```bash
git diff
git status --short
```

変更したソース・新規画像・出典記録・テストを、実際のパスで個別指定します。AIは対象を調べて `git add` のコマンドへ展開してください。以下の例を、そのまま架空のファイルに対して実行しません。

```bash
git add -- "変更したファイルのパス" "追加したファイルのパス"
git diff --cached --check
git diff --cached
git commit -m "feat: 担当部分の変更内容"
```

最初のpushだけ、OSに合わせて追跡先を設定します。

Windows（PowerShell）：

```powershell
$taskBranch = git branch --show-current
git push -u origin $taskBranch
```

macOS・Ubuntu：

```bash
task_branch=$(git branch --show-current)
git push -u origin "$task_branch"
```

2回目以降は `git push` だけで更新できます。PRを作成します。

```bash
gh pr create --base develop
gh pr view --web
```

タイトルと説明を対話で入力します。担当範囲、共有ファイルを変更した理由、検証結果、未確認の環境を記載してください。既にPRがある場合は再作成せず、そのブランチへpushすると更新されます。

AIへPR作成まで依頼した場合はここまでです。マージは統合担当、またはマージを依頼された人・AIが次の手順で行います。

## 9. チェック・レビューを確認してマージ

自分のPRなら作業ブランチ上で次を実行します。別の担当のPRなら `gh pr checkout PR番号` で対象を開いてから進めます（未コミット変更がないことを確認）。

```bash
gh pr view --json url,baseRefName,headRefName,headRefOid,mergeable,reviewDecision
gh pr checks --required --watch --fail-fast
```

PR先が `develop` で、最新の必須チェックがすべて成功し、競合がなく、必要なレビューが完了していることを確認します。チェックなし・skip・キャンセルは成功の代わりにしません。必要な承認がある場合は、自分で自分のPRを承認しようとせず、別の開発者にPR画面でレビューしてもらいます。

先に別のPRがマージされた場合は、対象ブランチで次を実行します。

```bash
git fetch origin
git merge origin/develop
```

その後「7. 共有前に検証する」を再実行し、変更があればコミット・pushします。

```bash
git push
gh pr checks --required --watch --fail-fast
```

成功後に、直前に確認したPRのコミットを指定してマージします。以下は自分の作業ブランチに対応するPRが対象です。

Windows（PowerShell）：

```powershell
$prHead = gh pr view --json headRefOid --jq .headRefOid
gh pr merge --merge --match-head-commit $prHead
gh pr view --json state,mergedAt,url
```

macOS・Ubuntu：

```bash
pr_head=$(gh pr view --json headRefOid --jq .headRefOid)
gh pr merge --merge --match-head-commit "$pr_head"
gh pr view --json state,mergedAt,url
```

途中で別の変更が入り、最新状態やコミット不一致で止まった場合は、取り込みと検証からやり直します。通常の手順に `--admin` は付けません。所有者が例外権限を設定していて、本人が例外利用を指示した場合だけ `gh pr merge --merge --admin` を使います。この別アプリに例外が自動で引き継がれるわけではありません。

## 10. マージ後：統合版を確認して次の作業へ

```bash
git status --short --branch
git fetch origin
git switch develop
git pull --ff-only origin develop
fvm install --skip-pub-get
fvm use --skip-pub-get
fvm flutter pub get --enforce-lockfile
fvm flutter test --no-pub
fvm flutter run -d chrome
```

未コミット変更があれば切り替え前に保存します。統合版を確認してアプリを停止したら、次のタスクは新しいブランチで始めます。

```bash
git switch -c feature/next-task
```

マージ済みのブランチを何度も再利用せず、最新の統合版を基点にします。ブランチ削除は必須ではありません。

## 11. 競合やエラーで止まったら

競合ファイルの確認：

```bash
git status
git diff --name-only --diff-filter=U
```

双方の変更を確認して編集し、解消したファイルを個別指定してマージを完了します。

```bash
git add -- "競合を解消したファイルのパス"
git diff --cached --check
git merge --continue
```

判断できず今回のマージを取りやめる場合は、解消作業を破棄することを確認して `git merge --abort` を使えます。全ファイルを一括で `ours` / `theirs` にせず、ロックの競合は統合担当が指定環境で解決します。解消後は再検証・push・CI確認が必要です。

| 症状 | 確認すること |
|---|---|
| コマンドが見つからない | ターミナルを開き直し、PATHと導入済みツールを確認 |
| clone・pushが拒否される | 招待の承諾、`gh auth status`、ログインアカウントと権限 |
| Flutter/Dartの版が違う | `.fvmrc` と `fvm flutter --version`。グローバルFlutterで代用しない |
| ロック更新を要求される | 指定SDKと最新ブランチを確認。lock削除やupgradeで回避しない |
| 実機が出ない | USBデバッグ・端末側の許可・ケーブル・ドライバー・`fvm flutter devices` |
| マージできない | PR先、最新状態、競合、必須チェック、承認レビューを確認 |

参考：[FVMコマンド](https://fvm.app/documentation/guides/basic-commands)、[依存ロックを守る取得](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile)、[PRチェック](https://cli.github.com/manual/gh_pr_checks)、[PRマージ](https://cli.github.com/manual/gh_pr_merge)。
