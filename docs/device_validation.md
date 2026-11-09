# PC二画面の検証とAndroid実機への導入

2026-11-09。`honban` の通信版を、独立した二つのChromeプロセスから実際に操作して検証します。端末用APKにも同じ公開通信先を含めます。実機はこの検証時点では未接続です。

## すぐ使う手順

USB接続後、端末の開発者向けオプションでUSBデバッグを有効にし、このPCからの接続を端末側で許可します。リポジトリのルートで実行します。

```bash
python3 tool/android_devices.py list
python3 tool/android_devices.py info --serial 端末AのID --serial 端末BのID
python3 tool/android_devices.py install --serial 端末AのID --serial 端末BのID
```

端末IDは `list` の出力を使います。接続した全端末が対象なら `install --all` も使えます。未接続・未許可・offlineの対象があれば、どの端末にも導入する前に停止します。対象指定の省略はできません。

導入するのは `build/device-distribution/tsunagun-device-check.apk` です。記録したSHA-256と照合し、`adb -s ID install -r` で既存データを保持して更新した後、アプリを起動します。インストールの失敗時にアンインストールやデータ削除を自動実行しません。署名不一致が出た場合も停止します。

Android実機を接続する前にAPKを作り直す場合：

```bash
python3 tool/android_devices.py build
```

固定SDK・JDK・ロックファイルを確認し、公開APIを指定した汎用release APKを作成します。ARMv7・ARM64・x86_64の実コードと、その中に公開接続先が含まれることも確認します。生成物と接続先・ソースコミット・ハッシュの記録は `build/device-distribution/` に置き、Gitには含めません。releaseの最適化を使いますが、署名は既存プロジェクトのdebug署名で、実機確認用です。

APKの接続先は `https://tsunagun-rooms.tsunagun-room-server.workers.dev` です。端末自身を指すlocalhostへの接続や、PCへのADBポート転送は不要です。各端末でこの公開HTTPS/WSSへの通信が必要です。

## このPCがWSLの場合

WindowsにUSB接続しても、WSL内のADBから自動で見えるとは限りません。まず `list` で確認します。見えない場合はWindows側のADBを使うか、管理者がMicrosoftの[USB接続手順](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)に従って対象USB機器をWSLへ接続します。SDK設定・ファイアウォール・USB割り当てをツールが勝手に変更することはありません。

このPCでは標準のAndroid SDK配置にWindows用ADBが見つからず、usbipdも利用できなかったため、Google公式のWindows用ADBを `build/device-tools/windows/` に準備しました。別のWindows/WSL環境で同じ準備を行う場合：

```bash
python3 tool/android_devices.py setup-windows-adb
python3 tool/android_devices.py list
```

準備済みなら再ダウンロードしません。WSLではこのADBを優先し、Linux側ADBと混同しないよう専用のローカルポート5038を使います。Windows側のUSB接続を利用するため、この方法ではusbipdによるWSLへのUSB転送は不要です。端末側のUSBデバッグ許可と、Windowsがその機器を認識することは接続時に確認します。配布元は [Android公式Platform-Tools](https://developer.android.com/tools/releases/platform-tools) です。

Windows側のADBを使う場合は `python3 tool/android_devices.py --adb ADB実行ファイルのパス list` のように指定します。WSLから `adb.exe` を使う場合、APKのパスは `wslpath` でWindows形式へ変換します。実際にどちらのADBから接続できるかは、端末接続後に確認します。

## PCで二つを手動起動する

Windowsでは既存の起動スクリプトを使えます。

```powershell
.\tool\open_presentation_windows.ps1
```

公開Web版が参加者A・B専用の保存領域で開きます。手動ならChromeとEdgeなど、保存領域の異なるブラウザーで同じアプリを開きます。同じプロファイルの別タブや二つのシークレットウィンドウを、二人分の保存領域として使いません。

ソースから作ったWeb版を二つで確認する場合は、同じ公開APIを指定してビルドし、PC内で配信します。

```bash
fvm flutter build web --release --no-web-resources-cdn --no-pub --dart-define=TSUNAGUN_SERVER_URL=https://tsunagun-rooms.tsunagun-room-server.workers.dev
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

両方で `http://127.0.0.1:8080` を開きます。このURLはPC内のWeb配信用で、端末用APKの通信先とは別です。配信を終了する場合は、そのターミナルでCtrl+Cを押します。

## 二画面を実操作する自動検証

[check_two_clients.mjs](../tool/check_two_clients.mjs) は、本番Flutter Webのボタン・文字入力・ゲームへのマウス入力を使います。ルーム操作APIの直接呼び出し、確定結果の注入、アプリの時計の書き換えは行いません。通常ブラウザーのバックグラウンド制御を無効にするPlaywright既定フラグも外して検証します。

検証用のPlaywrightはアプリ本体の依存と分け、Git管理外の `build/` に準備します。ChromeのあるLinux/WSLでは次で実行できます。別ターミナルで上記Web配信を起動しておきます。

```bash
npm install --prefix build/device-validation-tools --no-audit --no-fund playwright-core@1.65.0
export TSUNAGUN_BROWSER="$(command -v google-chrome)"
node tool/check_two_clients.mjs --headed --scenario=success
node tool/check_two_clients.mjs --headed --scenario=failure
node tool/check_two_clients.mjs --headed --scenario=standard
```

Chromeがない場合は同パッケージの `cli.js install chromium` で検証用Chromiumを用意し、`TSUNAGUN_BROWSER` を指定せずに使えます。検証専用の新しい二つのブラウザーを使い、既存のユーザープロファイルを変更しません。終了後は検証用ブラウザーを閉じます。

| シナリオ | 確認内容 |
|---|---|
| success | 発表用。双方落下→骨1匹ずつ→協力3レベル・18回の交互入力→双方REBORN→綱引き→順位 |
| failure | 発表用。双方落下→協力の早い入力で失敗→双方に追加の骨→綱引き→順位 |
| standard | 通常。1人では開始不可→2人参加→異なる停止入力で勝敗→同じ相手との再戦拒否→綱引き→順位 |

各シナリオで、5桁コードの入力検証、プロフィール保持、カメラ拒否時の手入力、二画面の選択切替、未確定中の再読み込みによる無報酬中断、確定後の再読み込みによる結果保持も確認します。プロフィール入力はFlutterのフォーカス反映を待って実キーボードへ入力し、各項目の実際の値を確認してから保存します。

スクリーンショットと結果JSONは `build/device-validation/` に出力します。参加トークン・再試行キー・HAR・認証フレームは保存しません。失敗時には失敗時点の画面と読み上げ要素も残し、テストを失敗終了します。実行ごとに検証用ルームを新規作成し、他人が使用中のルームを変更しません。

## 検証結果

本作業の結果をここへ記録します。Webの結果とAndroid実機での確認は分けます。

| 項目 | 結果 |
|---|---|
| 公開APIの実HTTP・二本のWebSocket統合テスト | 成功。認証・再送・再接続・両者落下・交互協力・REBORN・共通綱引き・デモ相手・途中参加 |
| サーバー型検査・ルールテスト44件・Worker dry-run | 成功 |
| 二つの実ブラウザーで対戦→協力→REBORN→綱引き→順位 | 成功。Chrome 150、両チーム9点、ブラウザー実行時例外0件 |
| 協力失敗の二画面操作 | 成功。双方に骨2匹、両チーム8点 |
| 通常ルームの二画面操作 | 成功。1人開始不可、実入力の勝敗、確定後の再戦拒否、赤1点・青3点 |
| カメラ拒否からの手入力・選択切替・再読み込み | 全3シナリオで成功 |
| 最終のブラウザー検証 | 3シナリオ・計37確認項目が成功。実行時例外0件。記録は `build/device-validation/verified/` |
| Windows用ADBの起動・端末一覧 | 成功。37.0.1、WindowsのUSB接続を使う経路を準備。端末0台 |
| 実機用の汎用release APK | 成功。89.6MB、Android 7.0（API 24）以降、ARMv7・ARM64・x86_64。公開接続先の埋め込みと署名の有効性を確認 |
| 最終ローカルチェック | 成功。文書・Python/JavaScript構文・Dart整形・解析・Flutterテスト296件・Web release・Android debug。両ロックファイルの差分なし |
| AndroidのUSB導入・実機での操作 | 未実施。接続端末なし |

## 実機接続後に確認すること

1. `info` で機種・OS・SDK・画面サイズ・密度・文字倍率を記録し、両端末へ同じAPKを入れる。
2. 初回プロフィール入力・キーボード・ホームの主操作・長文と文字拡大・SafeAreaを確認する。Flutterの論理サイズは物理解像度から推測しない。
3. 発表用ルームに二台で参加し、アプリ内カメラで相手QRを読む。許可・拒否・手入力への切り替えを確認する。
4. 両者落下→協力3レベル→REBORN→綱引き→順位を両端末で操作し、子分数・得点・開始時刻が一致することを確認する。
5. 片方のアプリの背景化・復帰、通信切断・再接続、アプリ再起動を試し、未確定の無報酬中断と確定済み報酬の保持を確認する。
6. 音声・振動・カメラ・描画性能と、通常ルームで複数の相手と遊ぶ操作を確認する。

PCでの成功を、実機のカメラ・secure storage・音声・振動・性能の確認済み結果として扱いません。確認した端末・同じAPKのハッシュ・通信環境・各操作の結果を追記します。

導入コマンドの根拠：[Android公式ADB](https://developer.android.com/tools/adb)、ビルド形式：[Flutter公式Androidビルド](https://docs.flutter.dev/deployment/android)。
