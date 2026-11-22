# 初回準備・起動・検証

## 別のPCで試遊する

GitHubにサインインし、本選ブランチのビルド一覧から、試したいコミットで緑のチェックが付いた実行を開く。ページ下部の「Artifacts」からZIPをダウンロードする。マージ前のPRを試すときは、そのPRの「Checks」から同じ実行を開ける。試遊にはFlutterのインストールもAPIキーの設定も要らない。[本選ブランチのビルド一覧](https://github.com/mizugramming/SPAJAM2026/actions/workflows/check.yml?query=branch%3Ahonsen)

### PCで画面とゲームの流れを試す

1. `migaku-web` を展開する。`index.html` があるフォルダーでターミナルを開き、次のうち自分のOSに合うコマンドを実行する。配信にはPython 3を使う。

   | OS | コマンド |
   |---|---|
   | Windows（PowerShell） | `py -3 -m http.server 8766 --bind 127.0.0.1` |
   | macOS・Linux | `python3 -m http.server 8766 --bind 127.0.0.1` |

2. Chromeで `http://127.0.0.1:8766/` を開く。画像やフォントもこのフォルダーから読み込むので、遊んでいる間はターミナルを開いておく。終わったら Ctrl+C で止める。
3. 「はじめる」から素材を選んで「これを磨く」を押す。声の代わりに「低い」などのボタンを選び、画面のマイクを押す。「磨け！」が出たら「こする」を押すたびに1往復分進む。
4. メダルは10秒ずつ2回磨く。結果画面でメダル上部の箔をマウスでこすると、なぞったところから「最優秀賞」の文字が現れる。「もう一度遊ぶ」で「漢」を選ぶと、今度は磨き加減の勝負。「そろそろ…」が出たら手を止め、そのまま3回目を終えると段位と称号がもらえる。削りすぎるとその場で「漢」が割れる。

### Androidで声・動き・手触りを試す

1. `migaku-android` を展開し、中の `app-debug.apk` をUSBなどで端末へコピーする。実機の確認に使った機種はXiaomi REDMI Note 15 5G（Android 15）。[端末と確認記録](validation.md)
2. 端末の「ファイル」などからAPKを開いてインストールする。初めての場合は、表示に従ってAPKを開いたアプリに「不明なアプリのインストール」を許可する。この許可はインストール後に戻せる。
3. 「磨くでヤンス！」を開いて素材と声域を選ぶ。マイクの使用を許可して「あー」と約1.2秒声を伸ばす。紙やすりが降りて「磨け！」が出たら、スマホを手に持ち、机の少し上で前後に滑らせる。インストール後はオフラインで遊べる。

すでに同じアプリが入っていて署名の違いで更新できない場合は、元の署名鍵で作ったAPKを使うか、別の端末で試す。旧版をアンインストールするとアプリのデータも消える。

## ソースから起動する

本選アプリのブランチ名は `honsen`。Gitを入れたPCで次を実行すると、本選版の最新コミットを取得できる。すでに開発用に取得した人は[担当手順](handoff.md)に従って作業ブランチを用意する。

```sh
git clone --depth 1 --branch honsen https://github.com/mizugramming/SPAJAM2026.git
cd SPAJAM2026
```

PCで遊ぶにはChromeとFVMを用意する。Dartが入っていれば `dart pub global activate fvm` でFVMを導入し、表示された実行ファイルの場所をPATHに加える。リポジトリ直下で次を実行すると、指定のFlutterと同梱したロックファイルに合わせて依存パッケージがそろう。

```bash
fvm install
fvm flutter --version
fvm flutter doctor -v
fvm flutter pub get --enforce-lockfile
```

Androidにもビルドする場合は、JDK 17とAndroid SDKのCommand-line Toolsを用意する。Android StudioのSDK ManagerでAndroid SDK Platform 36、Platform-Tools、Build-Tools 35.0.0、NDK 28.2.13676358を追加し、`fvm flutter doctor --android-licenses` でライセンスを確認する。

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

計測専用入口はゲーム画面に依存しない。通常プレイは次のコマンドで起動し、最初の採音でマイクを許可する。素材選択画面の右上の「設定」→「端末の計測」から同じ計測画面にも入れる。[4条件の手順と記録欄](device_trials.md)

```bash
fvm flutter run -d <端末ID>
```

オフラインのプレイ確認にはAPKをインストールして起動し、通信を切った状態でメダルを2回、漢を最大3回磨いて結果を確認する。APKの場所は `build/app/outputs/flutter-apk/app-debug.apk`。debugビルドは開発用。

## 再現コマンド

### Windowsでビルド済みのWeb版を試す

WSLで下記のWebビルドを済ませ、WindowsのPowerShellで専用の配信ウィンドウを開く。`$web` にはWSL側の実際のディレクトリを指定する。URLはこのPCで使える。

```powershell
$web = '/path/to/SPAJAM2026/build/web'
$argsWeb = '-d', 'Ubuntu', '--exec', '/usr/bin/python3', '-m', 'http.server', '8766',
           '--bind', '127.0.0.1', '--directory', ('"' + $web + '"')
Start-Process wsl.exe -ArgumentList $argsWeb
Start-Process 'http://127.0.0.1:8766/'
```

配信ウィンドウはプレイ中は開いたままにし、止めるときはそのウィンドウで Ctrl+C を押す。起動を確認するには、素材選択を「声が低い人」にして「メダルを磨く」を表示し「これを磨く」を押す。「低い」を選んで丸いマイクを押し、中央に「100 Hz」「粗目のやすり」が出ることを確認する。紙が画面下に着地し、一拍置いて「磨け！」が出る。「残り 10 秒」の表示から「こする」を押すと、メダルに削り粉が舞い、表面の色が変わる。

### 固定SDKの検証とビルド

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
kotlinc "$native"/{VoiceAnalysis,StrokeDetector,DeskMotion,DeskHaptics}.kt tool/native/*.kt -include-runtime -d /tmp/polish-signals.jar
java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.SignalCheckKt &&
  java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.DeskMotionCheckKt &&
  java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.DeskVelocityCheckKt &&
  java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.DeskHapticsCheckKt
```

REDMIの計測CSV（列順 `t_s,x_m_s2,y_m_s2,z_m_s2`）を渡すと、全区間を連続で再生し、往復を受理した時刻を秒単位で1行ずつ出力する。現在の作業面判定は `DeskMotionCheckKt`、従来の3軸判定は `SignalCheckKt` で比較する。CSVに含まれない重力センサーの値・振動指令・ラウンド境界は加えない。

```bash
java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.DeskMotionCheckKt /path/to/acceleration.csv
java -cp /tmp/polish-signals.jar jp.spajam.polish_workshop.SignalCheckKt /path/to/acceleration.csv
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

[CI](../.github/workflows/check.yml)の `check` は共通キットを検証する。`app` はロックファイルどおりに依存を取得し、整形・解析・Flutterテストを実行して、試遊用のAndroidデバッグAPKとWeb版をビルドする。作業は `feat/`、`fix/`、`docs/` の各ブランチで分け、未コミット変更を保護して `origin/honsen` を取り込む。PR先は `honsen`。書き込み権限のあるメンバーは、最新コミットのチェック成功・差分・競合・未解決会話を確認して順番にマージする。他のPRが先に入ったら後続側で最新の統合先を取り込み、再検証する。
