# フォルダ構造と分担境界

これは「余白」の構成案内です。担当者と変更可能範囲の正本は[README](../README.md#このアプリの変更範囲)、接続仕様は[接続ガイド](feature_integration.md)です。開始時はこの図と実際のファイル一覧を照合します。図に合わせる目的で既存フォルダを移動・再生成しません。

## 主な構成

```text
AGENTS.md                    共通の開発ルール
README.md                    このアプリの担当・資料・起動方法
yohaku_app_design.md          初期設計（最新の決定事項も併読）
lib/
  main.dart                  起動処理：共通管理
  app/                       ルーター、テーマ、ナビ、スマホ表示枠：共通管理
  core/
    models/                  全画面で使う記録・感情・テーマなど
    providers/               共有状態と更新処理
    repositories/            記録の保存・復元
    constants/               ルート・デザイン定数
    utils/                   日付・記録の集計など
    widgets/                 共通表示・詳細・星座作成フロー
  features/
    home/pages/              ホーム
    space/                   SPACE：pages、controllers、widgets
    constellation/           星座：pages、widgets、painters
    universe/                宇宙：pages、widgets
    history/pages/           振り返り
assets/
  common/                    共通背景・フォント：共通管理
  home/ space/ star/         各担当の素材（starはSPACE担当）
  constellation/
  universe/ history/
test/
  widget_test.dart            画面をまたぐ一連の操作：共通管理
  helpers.dart                テスト共通補助
  core/                      共通データ・保存・状態のテスト
  features/                  各担当のテスト
  tool/                      環境チェックのテスト
tool/                        固定環境の定義・確認など：共通管理
.fvmrc                       Flutterの固定値：共通管理
pubspec.yaml / pubspec.lock   依存関係・素材登録：共通管理
.github/                     CI・PRテンプレート・保護設定：共通管理
docs/                        開発・設計・接続の資料
  asset_sources/             担当別の素材出典
```

プラットフォーム設定も共通管理です。空の担当フォルダや、まだテストファイルがない担当もあるため、一覧に表示されないことだけを理由に新しい構成を作りません。

ルートで `rg --files lib test assets tool docs` を実行すると関連ファイルを確認できます。隠し設定は `.fvmrc` や `.github/` など対象を指定して確認します。次に担当コードと、そのimport先・呼び出し元・テストを必要な範囲で読みます。ファイル一覧だけで接続仕様を理解した扱いにしません。

## 同じページを部品単位で分担する例

以下は宇宙画面を細分化する**分担例**です。実際の割り当ては依頼または担当表で決めます。

| 作業 | 編集するファイル例 | 接続・確認する相手 |
|---|---|---|
| 惑星の表示と横ドラッグ | `lib/features/universe/widgets/planet_carousel.dart` | 親画面が渡す記録数・選択テーマ・イベント |
| テーマ別記録のシート | `lib/features/universe/widgets/category_records_sheet.dart` | 共通記録と詳細表示、呼び出し元 |
| 部品の組み込み・今日の一覧 | `lib/features/universe/pages/universe_page.dart` | 両部品、共通Provider、日付 |

部品担当2人が同時に親画面を編集する割り当てにはしません。最初に組み込み担当が引数・イベントなどの接続を揃え、部品担当はその契約に沿って実装します。契約変更が必要なら、組み込み担当が親画面と利用箇所を調整します。

素材とテストの担当も一緒に決めます。同じ `test/features/universe/universe_test.dart` を2人が同時に変更するなら、編集担当を1人にするか、部品ごとに別のテストファイルを割り当てます。分担のために既存コードを分割する必要がある場合は、先に統合担当が分割・検証して共有します。

構造や共通APIを変更するPRでは、統合担当がこの案内・接続資料・READMEの担当範囲も更新します。通常の画面担当は、画像や部品を追加するたびに共有構成図を編集する必要はありません。
