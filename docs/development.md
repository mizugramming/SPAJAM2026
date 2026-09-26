# 開発環境・検証・統合

本番アプリの統合先は `honban`。作業は担当ブランチで行い、`main`・`honban` へ直接コミット・pushしません。

## 初回準備

- このリポジトリを取得し、`honban` を起点とする自分の作業ブランチを使います。旧アプリの作業フォルダやブランチと取り違えないでください。
- FVMを導入し、ルートの [.fvmrc](../.fvmrc) が指定するFlutterを `fvm install` で用意します。
- Flutter同梱DartとAndroid用Javaの固定値は [tool/toolchain.json](../tool/toolchain.json) にあります。
- Android確認には対応するAndroid SDK・JDKを用意し、`fvm flutter doctor -v` でFlutterが使うJDKを確認します。PATH上のJavaとFlutterが使うJavaは異なる場合があります。
- Windows/WSLでは、USB接続した実機が実行環境から見える必要があります。`fvm flutter devices` に出ない場合は接続環境を整え、プロジェクトのSDK制約を緩めて回避しません。
- 文書チェックはPython 3.12以降・標準ライブラリだけで動きます。Node、Firebase、NFC設定は一台デモの起動に不要です。

```bash
fvm install
fvm dart tool/check_environment.dart
fvm flutter pub get --enforce-lockfile
fvm flutter doctor -v
fvm flutter devices
```

Androidを扱う場合は `fvm dart tool/check_environment.dart --android` も実行します。環境不一致や依存取得失敗時はその原因を解消し、`pub upgrade`・SDK制約変更・ロック削除・プロジェクト再生成で合わせません。SDKやキャッシュへの書込み制限がある環境では必要な権限を整え、端末固有のパスはコミットしません。

## 起動とデモ

```bash
fvm flutter run -d chrome
```

Android実機では `fvm flutter run -d 端末ID` を使います。デモ操作は [README](../README.md) を参照してください。プロフィール・結果はメモリ内にあり、再起動やリセットで消えます。

REDMI Note 15 5G実機では、[端末条件](app_design.md) の測定欄へOS・文字設定・論理サイズ・表示領域を記録します。PCプレビューだけで実機確認済みにしません。

## 作業開始・更新

最初に `git status --short --branch` で既存変更を確認します。自分の変更は対象ファイルを指定して途中コミットに保護し、他人の変更をまとめてステージしません。秘密情報や生成物は含めません。

```bash
git fetch origin
git merge origin/honban
fvm dart tool/check_environment.dart
fvm flutter pub get --enforce-lockfile
```

新しく開始する場合は、未コミット変更がないことを確認したうえで `git switch -c feature/担当と目的 origin/honban` を使えます。コマンドの担当と目的は実際の作業名へ置き換えます。既に担当ブランチがあれば作り直しません。

競合は両方の意図を確認してファイルごとに解消します。共通モデル・公開API・依存ロックの判断は統合担当へ相談し、他の独立作業は進めて構いません。一括の `ours` / `theirs`、force push、共有履歴のrebase、`reset --hard` は使いません。`pubspec.lock` は行を混ぜず、固定SDKで依存の意図を揃えて統合担当が再生成します。

## ローカルチェック

SDK準備と依存取得の後で、次を実行します。整形を書き込むのは編集したDartファイルだけです。以下の整形コマンドは確認のみで、ファイルを変更しません。

```bash
python3 tool/check_kit.py
fvm dart format --output=none --set-exit-if-changed lib test tool
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build web --no-pub
fvm dart tool/check_environment.dart --android
fvm flutter build apk --debug --no-pub
git diff --check
git diff --name-only
git diff --exit-code -- pubspec.lock
```

APKはデバッグ用のビルド検証で、配布署名済み成果物ではありません。Android SDK・JDK・ネットワーク不足などで実行できない項目は、理由とともに未実施として報告します。テスト削除・skip・解析除外・CI失敗無視で通しません。

`tool/check_kit.py` はファイル名を引き継いでいますが、honbanではアプリ構成・文書リンク・SDK設定・Git管理対象を検証します。アプリファイルを禁止するmain用チェックとは別の役割です。外部リンクの到達性、文意、画面の操作性までは検査しません。

## PR・マージ

- 対象ファイルを指定して `git add` し、`git diff --cached` を確認してコミットします。`git add .`・`git add -A` は使いません。
- PR先を `honban` とし、リポジトリ・宛先・変更ファイル一覧を確認します。ページ単位でよいですが、共有状態・画面遷移への接続は完成前に確認します。
- PR提出中は同じブランチへ次の別タスクを混ぜません。並行するなら、基点と変更の依存関係を整理した別ブランチを使います。
- AI監査と人の仕様・操作確認を併用します。通常は作成者以外の人1人による承認を基本案とし、共通変更は影響する担当も確認します。実際のGitHub設定はマージ前に確認します。
- CIチェック名は `check`。固定SDKの確認、依存ロック取得、文書、整形、解析、テスト、Web・Androidビルドを一つの必須候補チェックで実行します。
- マージは統合担当がPR番号とリポジトリを指定して順番に行います。AIはユーザーから明示的なマージ依頼があるときだけ実行します。
- 最新の統合先を取り込み、最新コミットでチェック成功・競合なし・必要承認・レビュー会話解決を確認します。チェックなし・古い成功・実行中・キャンセルは成功扱いしません。`--admin` や保護解除で迂回しません。
- 2026-09-26の確認では、GitHubのマージ後ブランチ自動削除は有効です。担当番号ブランチの固定運用は未割当です。固定ブランチを再利用する方針にする場合は、自動削除・マージ方式・担当割当を実際の設定へ揃えてください。

## 引き渡し・発表前

全員が同じ基盤コミットを固定SDKで起動し、担当表を埋め、小さなPRを順に統合して接続を確認します。最後は実際のデモ端末で入口から綱引きまで操作し、確認コミット・端末設定・結果を記録します。

初回の実機・各開発者の起動確認は未実施です。CIの定義が存在するだけで成功と扱わず、各PRの結果を確認してください。通常の複数端末運用は通信・永続化・複数端末向けゲーム同期の実装後に別途検証します。
