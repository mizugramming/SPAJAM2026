# 余白 — Yohaku

> 余白が、わたしの宇宙をつくる。

[開発設計書](../yohaku_app_design.md)に沿ったFlutter / Android向けMVPです。感情とテーマを自分で選び、短い記録を星として残します。参考画像の紺色の宇宙、淡い金色・紫色の光を取り入れています。

**現在の画面・ボタンは分担開発のための仮UIです。** 各担当はFeature内のUIを差し替えてください。画面間のデータ・保存・削除・日付指定は接続済みです。[画面担当向けの接続ガイド](feature_integration.md)に、共通変数とProviderの使い方をまとめています。

## 起動

Flutter **3.41.5 / Dart 3.11.3**で検証しています。

```sh
flutter pub get
flutter devices
flutter run -d <AndroidのデバイスID>
```

Android SDK・ライセンス承認済みの開発環境と、USBデバッグを有効にした実機またはエミュレーターが必要です。環境の確認は `flutter doctor -v` で行えます。

ブラウザで試す場合：

```sh
flutter run -d chrome
```

フォント・描画エンジンを同梱したWebビルド：

```sh
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

ブラウザで `http://127.0.0.1:8765` を開きます。Web版の記録は利用したブラウザとオリジンごとのローカルストレージに保存されます。

## 実装済みの機能

- ホーム：今日の星のプレビュー、SPACEへの入口。
- SPACE：スキップ可能な停止時間 → 感情 → テーマ → 任意メモ → 星の誕生。
- 今日の星座：記録時刻順の接続、感情別の色、星タップで詳細。
- 宇宙：6テーマの惑星、0 / 1–4 / 5–14 / 15件以上の成長段階、テーマ別記録一覧。
- 振り返り：月カレンダー、記録日の星印、日別記録、過去の星座への遷移。
- 記録詳細と確認つき削除。追加・削除は全画面に反映。
- 200文字制限（絵文字を含む文字単位）、二重送信防止、保存失敗時の入力保持と再試行、入力破棄の確認。
- 日付変更とアプリ復帰時の「今日」の更新。OSのアニメーション抑制設定にも対応。

記録データは `shared_preferences` の `space_records_v1` キーへJSONとして保存します。UUID・感情ID・テーマIDは固定で、星座・惑星・カレンダーは同じ記録一覧から計算します。書き込みは直列化し、再試行時も同じIDを使用します。読み込めない保存データは上書きしません。

アカウント、API、解析ログ、外部へのメモ送信はありません。Androidの自動バックアップ対象から記録を除外しています。AIによる判定、ランキング、連続記録の催促もありません。

## 画面と分担

| 担当 | 主な編集箇所 | 役割 |
|---|---|---|
| A | `lib/app/`, `lib/core/`, `lib/features/home/` | 共通基盤・ホーム |
| B | `lib/features/space/` | 記録フロー |
| C | `lib/features/constellation/` | 星座の描画・日別表示 |
| D | `lib/features/universe/`, `lib/features/history/` | 惑星・振り返り |

Feature間の直接importはありません。共通の詳細表示・一覧・描画部品は `core/widgets/`、保存と状態管理は `core/repositories/` と `core/providers/` にあります。依存やルートの変更はAが管理します。素材も `assets/<feature>/` に分離しています。

ルートは `/home`, `/space`, `/constellation?date=YYYY-MM-DD`, `/universe`, `/history`。`/` はホームへ移動し、不正な日付は今日として扱います。

## 確認コマンド

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

GitHub Actionsにも同じチェックを用意しています。単体テストと画面操作テストは、JSON変換、保存・再読込・削除、日付抽出、惑星の成長、入力条件、保存失敗・再試行、削除の反映、過去日付、小画面・文字拡大を検証します。

実機での最終確認は設計書16.3節の順に、記録 → 星座 → 惑星 → カレンダー → アプリを終了して再起動 → 削除を実施してください。この作業環境にはAndroid SDK・実機がないため、Androidのビルドと実機操作は未確認です。

## 素材

背景は内蔵imagegenで生成し、`assets/common/night_sky.png` に同梱しています。[生成プロンプトと素材の出典](assets.md)を参照してください。惑星、星座、UIはFlutterで描画しています。

日本語フォントはNoto Sans JP、標準フォントの補完はRobotoを同梱しています。ライセンスは `assets/common/fonts/` 内のOFL文書にあります。

## 画面プレビュー

[ホーム](screenshots/home.png) / [SPACE](screenshots/space.png) / [星座](screenshots/constellation.png) / [宇宙](screenshots/universe.png) / [振り返り](screenshots/history.png)

Flutterの描画で撮影した画像です。記録入り画面にはテスト用のデータを使用しています。再生成は `flutter test tool/capture_screenshots.dart` で行えます。実際の保存データは変更しません。

この環境のヘッドレスブラウザではGPUが利用できず、CPU描画で背景画像が省略されました。背景素材はFlutterのネイティブ描画で読み込み・表示を確認しています。
