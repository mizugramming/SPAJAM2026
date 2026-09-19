# 共同開発の環境と統合ルール

## なぜ固定するか

CIと手元でFlutter/Dartが異なると、同じpubspecでも依存関係や整形結果が変わります。これまで共有されたロックファイルにはFlutter 3.44 / Dart 3.12で解決されたものがあり、CIのFlutter 3.41.5と一致していませんでした。SDKを揃え、ロックファイルを勝手に再生成しない運用にします。

AGENTS.mdはAIへの指示であり、ファイル書き込み権限を物理的に制限する機能ではありません。AIが読むこと、担当範囲の差分レビュー、自動CI、GitHub側のマージ保護を組み合わせます。競合や実機固有の不具合を完全にゼロにする保証ではありません。

## ルールブックと設計書の分担

`AGENTS.md` は別のアプリでも使える共通ルールです。新しいプロジェクトではこれをそのまま置き、READMEにそのアプリの設計書・担当フォルダ・統合先・環境設定・検証方法を記載します。AIは共通ルールを読んでからREADMEと今回の設計書を読み、作業を開始します。

SDKのバージョンや具体的なファイル名はプロジェクト側で管理します。同じルールブックを使っても、次のアプリまで今回のFlutterバージョンに固定する必要はありません。

[新規アプリの開始手順](new_app.md)に、用意するファイル・最初に動かす基盤・AIへの依頼文をまとめています。素材の追加は[画像の追加手順](adding_assets.md)を参照してください。

## 固定する環境

| 項目 | 共有値・管理場所 |
|---|---|
| Flutter | 3.41.5（`.fvmrc`） |
| Dart | Flutter同梱の3.11.3（`tool/toolchain.json`） |
| Java | JDK 17（同上。Android実行・ビルド時） |
| Android SDK Platform | API 36 |
| Android Build Tools | 35.0.0 |
| Android NDK | 28.2.13676358（Flutter既定値と一致） |
| Android Gradle Plugin / Kotlin | 8.11.1 / 2.2.20（`android/settings.gradle.kts`） |
| Gradle | 8.14（既存Wrapper。グローバルインストール不要） |
| パッケージ | コミット済み `pubspec.lock` のバージョンとハッシュ |

Androidの値は現在の設定を基準にしています。NDKやSDKは画面担当が個別に書き換えません。JavaはAndroid Studioの同梱JDKが17とは限らないため、実際に使われるものを確認します。

## 初回セットアップ

1. [FVM公式手順](https://fvm.app/documentation/getting-started/installation)でOSに対応するFVMを導入します。Windowsは公式のChocolateyまたはstandalone版、macOSはHomebrewなどが利用できます。
2. リポジトリのルートで次を1行ずつ実行します。

```bash
git fetch origin
git switch rehearsal/02
git pull --ff-only origin rehearsal/02
fvm install
fvm use 3.41.5
fvm flutter --version
fvm dart tool/check_environment.dart
fvm flutter pub get --enforce-lockfile
fvm flutter doctor -v
git switch -c feature/自分の担当名
git push -u origin feature/自分の担当名
fvm flutter run -d chrome
```

`.fvmrc` の指定バージョンをインストールします。既にある自分のブランチを使う場合は `git switch -c` ではなく `git switch` で切り替え、最新の `origin/rehearsal/02` を取り込みます。FVMを使わないCI・特殊な開発環境でも、同じFlutter/Dartで環境チェックを通す必要があります。

- VS Codeはコミット済みの `.vscode/settings.json` で `.fvm/flutter_sdk` を指定します。FVM導入後にウィンドウを再読み込みしてください。
- Android StudioもFlutter SDKをこのプロジェクトの `.fvm/flutter_sdk` に設定します。絶対パスのIDE設定はコミットしません。
- Dartを別にインストールして組み合わせず、`fvm dart` を使います。
- `.fvm/` はSDKへのローカルリンクです。Gitには含めません。初回ダウンロードには時間とディスク容量が必要です。

### Android実機で確認する場合

Android StudioのSDK Managerで上表のSDK Platform、Build Tools、Command-line Tools、Platform Tools、NDKを用意します。JDK 17を用意し、次を確認します。

```bash
java -version
fvm dart tool/check_environment.dart --android
fvm flutter doctor --android-licenses
fvm flutter doctor -v
fvm flutter devices
fvm flutter run -d デバイスID
```

`doctor -v` に表示されるFlutterのJavaが17でない場合は、ローカル環境で `fvm flutter config --jdk-dir "JDK17のインストール先"` を設定します。これはその端末のFlutter設定なので、他プロジェクトにも影響する点を把握して実施してください。Android StudioのGradle JDKも17に揃えます。

Android SDKの場所が見つからない場合は、その端末の設定でSDKの場所を指定します。`android/local.properties`、SDK本体、USBドライバーを共有Gitへ入れません。REDMI Note 15などの実機ではUSBデバッグと接続許可が必要です。SDKのAPI番号は実機のAndroidバージョンを変更する指定ではありません。

## 日々の作業と競合を減らす方法

1. AIへ `AGENTS.md` と担当機能を渡す。
2. 未コミット変更を保存し、作業ブランチで `git pull --ff-only`、`git fetch origin`、`git merge origin/rehearsal/02`。
3. `fvm dart tool/check_environment.dart` と `fvm flutter pub get --enforce-lockfile` で環境を確認。
4. 1つの目的に絞り、担当フォルダ内を小さなコミットで変更。関係のない整形・名前変更・全体リファクタリングを混ぜない。
5. 他のPRがマージされたら自分のPRにも最新版を取り込んで再チェックする。大きなPRを同時にマージせず、1件ずつ順番に進める。

`git merge` で競合したら次のコマンドで対象を確認します。

```bash
git status
git diff --name-only --diff-filter=U
```

双方の変更意図を確認してファイルごとに解決します。「全部こちら」「全部相手」で処理しません。モデル・依存関係・共通ルーターの競合は統合担当へ渡します。解決後は対象ファイルを指定して `git add`、マージを完了し、チェックを再実行します。

`git pull --ff-only` が失敗したときも、force pushやresetで片付けません。同じ作業ブランチに別の変更が入った可能性があるので履歴を確認します。マージ済みブランチが削除された場合は、最新の `rehearsal/02` から新しい作業ブランチを作ります。

## 共有前のチェック

### 複数人のPRが同時にある場合

作業ブランチは1人・1タスクを原則とし、共有ブランチへの統合は1件ずつ行います。例えばホーム担当Aと宇宙担当Bが同時にPRを出した場合：

1. Aが最新の統合先を取り込み、チェック成功後にマージする。
2. Bは自分のブランチで `git fetch origin` → `git merge origin/rehearsal/02` を実行し、Aの変更を取り込む。
3. Bは競合を解決し、接続動作を含めて再検証・pushする。
4. Bの最新チェック成功を確認してマージする。途中でCが先に入った場合は再び最新状態へ更新する。

この運用ではマージコミット方式（`gh pr merge --merge`）に揃えます。squashやrebaseを各自で混ぜず、マージ後の新しいタスクは最新の統合先から別の作業ブランチを作ると履歴を追いやすくなります。

| 変更の組み合わせ | 対応 |
|---|---|
| 担当別ソース・担当別画像 | 通常は自動統合可能。画像本体と参照コードを同じPRにする |
| 同じファイルの同じ行 | Gitが競合を検出する。双方の意図を確認して解消 |
| 同じ画像を両者が差し替え | 画像を見比べて選択、または別名で残して参照先を調整 |
| 共通API変更と別画面の呼び出し変更 | Gitの競合がなくても壊れる可能性がある。統合担当が仕様と接続を確認 |
| 依存関係・SDK・ロックの変更 | 画面変更から分けて統合担当が1つのPRで管理 |

2026-09-19にGitHubの有効なルールをAPIで確認し、統合先の最新状態と必須 `check` 成功を要求する設定が有効でした。隔離した一時Gitリポジトリでも、担当別ソース・バイナリ素材の並行追加が両方残ること、共通ファイルの同一行変更が競合として停止することを確認しています。この確認はあらゆる変更の安全性を保証するものではありません。

### ローカルで実行する検証

まず変更したDartファイルだけを `fvm dart format ファイル名...` で整形します。次は全体の読み取り検証です。

```bash
fvm dart tool/check_environment.dart
fvm flutter pub get --enforce-lockfile
git diff --exit-code -- pubspec.lock
fvm dart format --output=none --set-exit-if-changed lib test tool
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build web --release --no-web-resources-cdn --no-pub
git diff --check
git diff --name-only
```

Android環境がある担当者は `fvm flutter build apk --debug --no-pub` も実行します。CIでは全PRのAndroidデバッグAPKをビルドします。ビルド成功は実機の表示・操作確認の代わりではありません。

通常の画面変更では `pubspec.lock` の差分はゼロです。依存変更を明示的に承認された統合担当は、固定SDKで `pub get` を実行してロックを生成し、意図した差分だけを確認・コミットした後、上記のチェックを実行します。SDKを上げる場合は `.fvmrc`、toolchain設定、pubspec制約、CI・全開発端末を同じPRで揃えます。

## PRと安全なマージ

対象ファイルだけをステージして差分を確認し、コミット・pushします。

```bash
git add 自分が変更したファイル名
git diff --staged
git commit -m "feat: 変更内容"
git push
gh pr create --base rehearsal/02
```

PRテンプレートに検証結果を記入し、共通ファイルを変更した場合は理由と確認者を明記します。

統合担当またはマージを明示的に依頼されたAIは、PR番号を指定してチェックします。

```bash
gh pr checks PR番号 --watch
```

成功を確認したあとにだけ、次を実行します。

```bash
gh pr merge PR番号 --merge
```

マージ直前に別PRが先に入った場合は、再度 `git fetch origin` → `git merge origin/rehearsal/02` → 検証・pushを行い、新しいチェックを待ちます。通常の開発では、必須チェックがブロックしても `--admin` や保護解除で突破しません。

### GitHub側の保護

共有する設定は `.github/rehearsal-ruleset.json` と `.github/main-ruleset.json` です。リポジトリにJSONを置くだけでは有効になりません。管理者がGitHub Settings → Rulesで適用し、有効なルールを確認します。

- `rehearsal/02` への変更はPR経由。
- 必須チェック `check` の成功と、PRが最新の共有ブランチを取り込んでいることを要求。
- force push・ブランチ削除を禁止し、未解決のレビュー会話があればマージを止める。
- 所有者 `mizugramming`（ユーザーID `228197245`）だけ、本人の明示承認によりPRマージ時の例外を設定。ほかの開発者や管理者ロール全体には例外を付けない。
- 承認レビューの人数は0。新たな承認者待ちで作業を止めず、共通ファイルのレビューは運用として統合担当が確認する。

`main` は共通の開発キットを保管する用途へ整理します（PR #26）。PR・最新状態・必須チェックに加え、1人の承認レビューを必要とします。余白の実装やアプリリリースのPR先にはしません。mainの `check` はキットの文書・構成、rehearsal/02の `check` はアプリの解析・テスト・ビルドを検証します。

所有者の例外は `main` と `rehearsal/02` の両方で `pull_request` モードです。本人はPR画面の保護ルールを迂回する操作、または `gh pr merge PR番号 --merge --admin` により、承認・必須チェックの完了を待たずにマージできます。直接push・force push・ブランチ削除にはこの例外を適用しません。CI自体は引き続き実行されます。

AIは例外権限があることだけを理由にチェック失敗を無視しません。通常は成功を確認し、例外の使用はユーザーが指示した範囲で行います。設定JSONのユーザーIDはこのリポジトリ固有です。別リポジトリへ流用するときは、所有者と例外の要否を確認してください。

`check` は整形・解析・テスト・Web/Androidビルド・SDK/ロックの整合性を検査します。担当外の変更や仕様の妥当性まで自動判定するものではないため、PRの差分レビューも必要です。

## AIへの依頼テンプレート

[AIへ渡すプロンプト集](ai_prompts.md)に、作成者が用意した基盤での担当作業開始・作業再開の2種類を用意しています。担当作業では、AGENTS → README・設計書・接続資料 → 構成図と実ファイル → 担当コード・接続先・関連テストの順に確認します。

AGENTS.mdを自動では読まないAIにも、プロンプトを最初に送ります。Claude向け `CLAUDE.md` とCopilot向け指示ファイルも同じルールを参照します。

## エラー別の確認

| 症状 | 対応 |
|---|---|
| Dart/FlutterのSDK制約に合わない | `fvm install` → `fvm use 3.41.5`。グローバルのflutterではなく `fvm flutter --version` を確認 |
| ロックファイルが無効・更新を要求 | 最新の共有ブランチを取得し、固定SDKを確認。lock削除・pub upgradeはしない |
| SDKは正しいがネットワーク/証明書エラー | 接続・プロキシ・証明書をその端末で確認。依存バージョン変更でごまかさない |
| Java/Gradleエラー | `java -version` と `fvm flutter doctor -v`。実際のJDKを17に揃え、Gradle Wrapperを使う |
| Android SDK/NDKが見つからない | SDK Managerで指定コンポーネントとライセンスを確認 |
| IDEだけ別のSDKを使う | IDEのSDKパスを `.fvm/flutter_sdk` に揃え、再読み込み |
| 整形チェックで他人のファイルまで変わる | Dartの版を確認。全体を整形して押し切らない |
| ローカルでは成功、CIで失敗 | 最新のCIログ・SDK版・未追跡ファイル・大文字小文字を確認。失敗したままマージしない |
| 以前の画面がブラウザに残る | 実行プロセスを再起動してブラウザを強制再読み込み。データを残すならストレージ削除はしない |

## 根拠となる公式資料

- [FVMのプロジェクト設定](https://fvm.app/documentation/getting-started/configuration)
- [Dart pub getとロックファイルの強制](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile)
- [GitHubの保護ブランチと必須チェック](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [AGP 8.11の互換性](https://developer.android.com/build/releases/agp-8-11-0-release-notes)

## mainへの誤マージを戻した履歴

PR #20のマージ `6831203` は、revertコミット `a56e99a` で取り消しています。最新の開発内容は復元した `rehearsal/02` に保持しています。通常の開発ではmainを作業ブランチへ取り込まず、`origin/rehearsal/02` を使ってください。

その後、mainは共通開発キットを保管する方針となったため、余白をmainへ再マージする手順は使いません。mainとrehearsal/02のブランチ全体を相互にマージすると、アプリの削除や不要な復活を招きます。共通ルールだけをファイル単位で反映し、アプリの公開・リリース先は統合担当が別途決めます。

整理前のmainは保存タグ `archive/yohaku-main-before-cleanup-20260919` に保持しています。現在のアプリ開発は引き続きrehearsal/02を使います。
