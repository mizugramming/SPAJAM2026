# 余白：共同開発するAIへの指示

回答は日本語で簡潔に。作業前にこのファイル、README.md、docs/development.md、docs/feature_integration.mdを読む。
このルールは担当者の変更を安全に統合するためのもの。ユーザーが今回の作業で範囲外の変更を明示的に依頼している場合は、その許可を繰り返し求めない。

## 最初に確認すること

- `git status --short --branch` でブランチと未コミット変更を確認。他人の作業・既存の変更を上書きしない。
- 自分の担当機能をユーザーの依頼から特定し、変更するフォルダと目的を短く伝える。特定できない場合だけ質問する。
- `main` / `rehearsal/02` へ直接コミット・pushしない。担当の作業ブランチを使う。
- `.fvmrc` のFlutterと `tool/toolchain.json` のDartを使用。通常は `fvm flutter` / `fvm dart`。バージョンが同じことを検証できるCIなどでは直接実行してよい。
- 作業前に `fvm dart tool/check_environment.dart`、`fvm flutter pub get --enforce-lockfile` を実行する。違うSDKに合わせて設定を書き換えない。

## 担当者が変更してよい範囲

| 担当 | ソース | 素材 | テスト |
|---|---|---|---|
| ホーム | `lib/features/home/` | `assets/home/` | `test/features/home/` |
| SPACE | `lib/features/space/` | `assets/space/`, `assets/star/` | `test/features/space/` |
| 今日の星座 | `lib/features/constellation/` | `assets/constellation/` | `test/features/constellation/` |
| 宇宙・振り返り | `lib/features/universe/`, `lib/features/history/` | `assets/universe/`, `assets/history/` | `test/features/universe/`, `test/features/history/` |

担当外ファイルの読み取りはよい。変更は依頼された範囲だけに限定する。共通部分の変更が必要なら、まず理由・対象ファイル・影響を説明して統合担当へ依頼する。担当内で解決できる場合はそのまま進める。

以下は共通管理。担当画面の実装やローカル環境のエラーを理由に、無断で変更しない。

- `lib/app/`, `lib/core/`, `lib/main.dart`, `assets/common/`
- `pubspec.yaml`, `pubspec.lock`, `.fvmrc`, `tool/toolchain.json`
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`
- `.github/`, `tool/`, `analysis_options.yaml`, `.gitignore`, `.gitattributes`, `.vscode/`
- `test/widget_test.dart`, `test/helpers.dart`, `test/core/`, `test/tool/`, 共有ドキュメント・AI指示ファイル

## 接続を壊さない

- 全画面の記録は既存の `SpaceRecord` と `spaceRecordsProvider` を使う。独自の保存先や画面専用コピーを新設しない。
- 記録のID、JSONキー、感情・テーマのID、既存のルート・Providerの公開APIを勝手に変更しない。
- 他Featureを直接importせず共通APIを使う。追加・削除・再起動・日付変更でも同じ記録が反映されるようにする。
- 各画面でPC全体の物理サイズを直接参照しない。共通のスマホ表示枠と `MediaQuery` / `LayoutBuilder` を使う。
- 既存の入力保持、二重保存防止、削除確認、SafeArea、スクロール、文字拡大への対応を維持する。

## 禁止する回避策

- 無断で `flutter upgrade`, `pub upgrade`, `flutter create .`、ロックファイル削除、SDK制約の緩和、Gradle/Kotlin/JDKの設定変更をしない。
- テストの削除・skip、解析除外やlint無効化、CIの削除、`continue-on-error`、ブランチ保護の解除でチェックを通さない。
- 変更していないファイルまで一括整形しない。整形は自分が編集したDartファイルだけ。
- `git add .`, `git add -A`、force push、共有履歴のrebase、`reset --hard`、競合への一括 `ours` / `theirs` を使わない。
- SDK本体、`.fvm/`, `.dart_tool/`, `build/`, `local.properties`、端末固有パス、鍵・トークンをコミットしない。
- GitHubの赤い・未完了・キャンセルされたチェックを無視してマージしない。チェックのないPRも成功扱いにしない。

## 最新版の取り込みと競合

1. 作業中の変更を保護してから `git fetch origin` → `git merge origin/rehearsal/02`。
2. 競合したら双方の目的を確認し、担当内の意味が明確な競合だけ解消する。新しい方を丸ごと採用しない。
3. 共通のモデル・依存関係・画面遷移の競合で判断が必要なら、そのファイル名と選択肢を統合担当へ示す。他の作業は進めてよい。
4. 統合後は再検証する。以前のコミットの緑チェックでは代用しない。
5. `pubspec.lock` の競合は手で行を混ぜない。統合担当が固定SDKでpubspecの依存意図を解決して再生成し、差分と全チェックを確認する。

## 終了・PR・マージ

- `git diff --name-only` と `git diff --check` で担当外変更・競合マーカー・不用意な差分を確認。
- `docs/development.md` のローカルチェックを実行。失敗は原因を直す。実行できないチェックは未実施として明記。
- `git add ファイル名...` で対象を指定し、ステージ差分をレビューしてコミット。
- PR先は `rehearsal/02`。PRには担当範囲、動作の変更、共通ファイル変更の理由、検証結果を記載。
- ユーザーから明示的にマージを依頼されていない場合は、PR作成まで。依頼されている場合は、最新の共有ブランチを取り込み、最新コミットの必須チェック成功と競合なしを確認してマージ。
- 結果は変更箇所・実行した検証・残る未確認事項を短く報告する。「全端末で動作確認済み」といった未検証の断定はしない。
