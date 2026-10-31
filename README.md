# まよいクエスト（仮称）開発仕様書

作成日：2026-10-31／会話で決定した仕様の初版。実装済みを意味しない。

館内案内図を見ながら実際に歩き、QRと撮影ミッションでチェックポイントを巡る個人対戦ゲーム。テーマは「まよい」。自由ミッションを続けるか、早くゴールするかの選択も楽しむ。

## 開発体制

| 担当 | 範囲 |
|---|---|
| 松本 | プレイヤー画面、QR読取、撮影、マップ・判定結果・順位表示 |
| 嶋本 | オーナー画面、共通モデル、状態・保存・同期、得点計算、AI接続、統合 |

Android専用、Flutter、Android Studio。オーナーも同じアプリを使用。対戦には常時インターネット接続が必要。開発者は2人。Claude/Codexのどちらを誰が使うかは未指定。

## 最初に読む資料

1. [AGENTS.md](AGENTS.md)：プロジェクト共通の共同開発ルール。
2. [要件](docs/requirements.md)：決定済み仕様と初版の範囲。
3. [画面設計](docs/screen_design.md)：画面と遷移。
4. [システム設計](docs/system_design.md)：接続・データ・状態・未確定事項。
5. [担当と進め方](docs/development_roles.md)：担当フォルダ案と統合手順。
6. [進捗の記録](docs/progress/README.md)：担当者ごとの進捗と依頼・質問。作業を始める前に他の担当者のファイルを読む。

## 実装の優先順位

最初は固定コースで、ルーム作成→参加→共通スタートQR→一斉開始→チェックポイントQR→写真のAI判定→加点→全指定クリア→ゴールQR→結果集計を実際に動かす。自由ミッション・順位共有・時間切れ・復帰も同じ対戦モデルに接続する。

案内図のAI解析、通路の高度な編集、自作コース保存、PDF取込、NFCは後続。正式な要件から削除したわけではない。初版では実装できていない機能を使えるように表示しない。

## 決定事項（2026-10-31）

| 項目 | 決定 |
|---|---|
| リポジトリ | https://github.com/mizugramming/SPAJAM2026 |
| 統合ブランチ（PR先） | `test-1`。作業ブランチ（例：`nagisa`）から `test-1` へPR。`main` は共通キット用なのでアプリを入れない |
| Flutter | 3.44.5 stable（Dart 3.12.2）。`.fvmrc` で固定 |
| バックエンド | Supabase（東京リージョン）。アプリ側の接続は実装済み、サーバー側（`supabase/`）は作成中 |
| AI判定 | OpenAI。Supabase Edge Function から呼び、鍵はアプリに入れない（サーバー側は作成中） |
| 状態管理 | flutter_riverpod 3 |
| 対象端末 | Android。`web/` は開発中に Chrome で画面を確認するためだけに置く（カメラ・QRは実機で確認） |

## 開発環境・起動・検証

```bash
fvm flutter pub get --enforce-lockfile   # fvm がなければ 3.44.5 の flutter を直接使う
fvm flutter run -d chrome                # 開発中の確認用：Chrome で表示（本番の対象は Android）
fvm flutter run                          # モックで起動（Supabase に接続しない）
fvm flutter run --dart-define-from-file=config/supabase.json   # Supabase に接続
fvm flutter analyze
fvm flutter test
dart format lib test                     # 行幅120（analysis_options.yaml）
```

`config/supabase.json` は `config/supabase.example.json` をコピーして、Project URL と publishable（anon）キーを入れる。Git には入れない。`service_role` / secret キーはアプリに入れない。

CI（`.github/workflows/check.yml` の `check`）は、依存取得・整形・analyze・test・空白チェックを実行する。実機での起動・カメラ・QR・複数端末の同期は未検証。

## 構成

```text
lib/main.dart                 起動（ProviderScope）
lib/app/                      ルート・入口・共通レイアウト（嶋本）
lib/app/dev/                  開発用モック参加者パネル（嶋本）
lib/core/models/              共通モデル・エラー（嶋本）
lib/core/repository/          MatchRepository 契約（嶋本）
lib/core/rules/               得点・ゴール・順位の判定（嶋本）
lib/core/mock/                モックのサーバー・AI判定・仮コース（嶋本）
lib/core/supabase/            Supabase 版 MatchRepository（嶋本）
lib/core/session/             再起動後に戻るルームの保存（嶋本）
lib/core/providers.dart       画面が使う Provider（嶋本）
supabase/                     テーブル・RLS・関数・Edge Function（サーバー側の担当）
lib/features/owner/           オーナー画面（嶋本）
lib/features/player/          プレイヤー画面（松本）
test/core/, test/features/owner/   嶋本のテスト
test/features/player/         松本のテスト
```

接続方法と使用例は [担当と進め方](docs/development_roles.md)、データと規則は [システム設計](docs/system_design.md)。

## 初版着手前の最小確認

- Supabase プロジェクトの作成者と URL・匿名キーの共有方法、OpenAI の費用上限と鍵の管理者。
- 使用する固定コースの案内図、フロア、通路、撮影対象、正解写真、設置可能なQR。今は仮コース（`lib/core/mock/sample_course.dart`）。
- 松本の Flutter 環境が 3.44.5 であること。

細かな推奨設計はsystem_design.mdに明示し、決定済み要件と混同しない。
