# 初回準備・起動・検証

## SDKと依存

リポジトリは `mizugramming/SPAJAM2026`。本選の統合先は `honsen`。初期基盤が未統合の間は[担当手順](handoff.md)の取得元を使う。Git・FVM・Chromeを用意する。Androidを扱うPCにはJDK 17、Android SDK Platform 36、Platform-Tools、Build-Tools 35.0.0、NDK 28.2.13676358を用意してSDKライセンスに同意する。FVMはDartがある環境なら `dart pub global activate fvm` で導入できる。実行ファイルのパスを通してからリポジトリ直下で次を実行する。

```bash
fvm install
fvm flutter --version
fvm flutter doctor -v
fvm flutter pub get --enforce-lockfile
```

Flutterの正本は[.fvmrc](../.fvmrc)（3.41.5、Dart 3.11.3）。IDEも `.fvm/flutter_sdk` を参照する。Dart依存は[ロックファイル](../pubspec.lock)、AndroidプラグインとGradleは[settings.gradle.kts](../android/settings.gradle.kts)・[wrapper設定](../android/gradle/wrapper/gradle-wrapper.properties)。Gradle起動用のスクリプトとJARはFlutterがビルド時に用意する。SDK、依存・Gradle資材の初回取得にはネットワークが必要。ゲームにアカウント登録、外部サービスの設定、API鍵は不要。

## 2人の起動

**UI担当** はChromeでゲームを開く。開発用の声と往復を選べる。Android上で同じ疑似入力を使う場合だけフラグを付ける。

```bash
fvm flutter run -d chrome
fvm flutter run -d <Android端末ID> --dart-define=SIMULATE_INPUT=true
```

**端末担当** は端末側でUSBデバッグとPCの許可を有効にし、データ通信対応USBで接続する。以下の `<端末ID>` は一覧に表示された値に置き換える。WSLではWindows側だけにUSBが見えていれば、Windows側のFlutterを使うか、WSLへUSBを接続する。

```bash
fvm flutter devices
fvm flutter run -d <端末ID> -t lib/device_main.dart
```

計測専用入口はゲーム画面に依存しない。通常プレイは次のコマンドで起動し、最初の採音でマイクを許可する。素材選択画面の右上から同じ計測画面にも入れる。[4条件の手順と記録欄](device_trials.md)

```bash
fvm flutter run -d <端末ID>
```

オフラインのプレイ確認にはAPKをインストールして起動し、通信を切った状態で両素材を3回磨く。APKの場所は `build/app/outputs/flutter-apk/app-debug.apk`。debugビルドは開発用。

## 再現コマンド

```bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze --no-pub
fvm flutter test --no-pub
fvm flutter build apk --debug --no-pub
fvm flutter build web --no-pub --no-web-resources-cdn
```

計測信号の回帰検査はJDK 17とKotlinコンパイラーがある環境で以下を実行する（bash例）。

```bash
native=android/app/src/main/kotlin/jp/spajam/polish_workshop
kotlinc "$native/VoiceAnalysis.kt" "$native/StrokeDetector.kt" tool/native/SignalCheck.kt -include-runtime -d /tmp/polish-signals.jar
java -jar /tmp/polish-signals.jar
```

同じJARにREDMIの計測CSV（列順 `t_s,x_m_s2,y_m_s2,z_m_s2`）を渡すと、各往復を受理したCSV上の時刻を秒単位で1行ずつ出力する。全区間を連続で再生する。CSVに含まれない振動指令や10秒のラウンド境界は加えない。

```bash
java -jar /tmp/polish-signals.jar /path/to/acceleration.csv
```

共通キット検証はPython 3.12以降を使う。

```bash
python3 tool/check_skills.py
python3 tool/check_skills.py --self-test
python3 tool/sync_claude_skills.py --check
python3 tool/sync_claude_skills.py --self-test
python3 .agents/skills/spajam-share-package/scripts/build_package.py --self-test
git diff --check
```

[CI](../.github/workflows/check.yml)の `check` は共通キット、`app` はロック取得・整形・解析・Flutterテスト・Androidデバッグビルドを実行する。作業は `feat/`、`fix/`、`docs/` の各ブランチで分け、未コミット変更を保護して `origin/honsen` を取り込む。PR先は `honsen`。書き込み権限のあるメンバーは、最新コミットのチェック成功・差分・競合・未解決会話を確認して順番にマージする。他のPRが先に入ったら後続側で最新の統合先を取り込み、再検証する。
