# 構成・担当範囲と共通接続

実装の正本は実ファイルです。本書と差がある場合は双方を調べ、古い構成へ戻しません。旧アプリのデータモデル・ルートを本番アプリへ流用しません。

## 現在の構成

```text
lib/main.dart                       起動
lib/app/tsunagun_app.dart            アプリ設定・共通PhoneViewport
lib/app/tsunagun_theme.dart          イラストに合わせた共通色・入力・ボタン
lib/features/demo/demo_page.dart    一台デモの場面・操作UI
lib/features/demo/game_scene.dart   共通ヘッダーと残り領域を使うゲーム表示枠
lib/features/demo/can_stage.dart    缶・親分・子分と演出
lib/features/demo/curved_label.dart  実テキストを保った曲面ラベル描画
lib/features/demo/tug_of_war_finale.dart  確定結果を使う最終綱引きの演出
lib/features/demo/illustrated_details.dart  見出し・吹き出し・綱の描画
lib/features/duel/duel_game.dart     吊魚チキンレース・完了通知
lib/features/duel/race_course.dart   落下・停止・勝敗の判定
lib/features/duel/race_field.dart    魚・綱・海のゲーム表示
lib/features/duel/sea_background.dart  海の背景描画
lib/features/cooperative/cooperative_game.dart  魂を運ぶ3レベル・完了通知
lib/features/cooperative/soul_course.dart  魂の進行・タイミング判定・仮想相手
lib/features/cooperative/soul_stage.dart   魂・缶・海のゲーム表示
lib/features/cooperative/soul_placement.dart  ゲーム内素材の配置
lib/domain/models.dart              プロフィール・参加者・子分・結果・状態
lib/domain/reward_rules.dart        報酬・成長・戦力・最終集計
lib/data/demo_controller.dart       デモの単一状態・進行管理
assets/characters/                  アプリが読むユーザー提供キャラクター
test/                              モデル・ルール・進行とUIの検証
docs/tsunagun/                     v2受領原本（画像・手書きPDFを含む）
```

画面の場面切替とキャラクターの状態を混同しません。`PhoneViewport` が共通枠を管理し、各画面・ダイアログは与えられた制約を使います。端末条件は [app_design.md](app_design.md) に従います。

## 共通データと処理

- `Profile` は本人・相手のニックネーム、趣味、ひとことです。入力と缶ラベルは同じ編集値を使い、サンプルプロフィールで本人入力を上書きしません。
- `Participant` は参加者とチーム、`Follower` は所持者に残る相手由来の子分です。子分の普通・骨と親分の画像を同じ状態にしません。
- `EncounterResult` と報酬規則で双方の付与を行います。ゲームUIが直接子分数や戦力を書き換えません。
- `DemoController` は単一の `ChangeNotifier` で、ルーム進行・相手・結果・所持状態を管理します。画面専用の子分リストや二つ目の保存先を作りません。
- `FinalSnapshot` は終了時の集計です。画面演出やホームへの帰還で結果を作り直したり、期限後に新規交流を再開したりしません。
- 現在はメモリだけで、再起動後の復帰は未実装です。永続化や通信を追加する場合は、結果IDによる二重適用防止・双方の確定・時刻・失敗復帰を共通管理へ追加します。

公開メソッドの引数と戻り値は現在のソース・関連テストを確認して使用します。変更が必要な場合は、呼び出し側とテストを含めて統合担当へ影響を示します。

## ゲームの実装と共通接続

同チームは魂を缶へ運ぶ3レベルの協力ゲーム、別チームは吊られた魚を海の手前で止めるチキンレースです。どちらも最初のタップで開始し、相手は一台デモの仮想参加者です。ゲームの実結果から報酬へ進めます。手動の結果注入は確認用に残します。

`game_scene.dart` の `game-surface` は共通 `PhoneViewport` 内の安全領域全体を使う表示枠です。上部に相手・残り時間・`DEMO` の共通ヘッダーを実レイアウトし、必要な高さを確保した残りを `Expanded` でゲームへ渡します。ゲーム中は共通画面の缶・親分を重ねません。ゲーム自身が使う缶・キャラクターなどの素材とは区別します。ゲーム中の結果選択・時刻早送りは右上の `DEMO` メニューからのみ使います。メニューの開閉と結果適用は `demo_page.dart` が担当します。ゲームは装飾枠なしで渡された残り領域いっぱいを使います。通常のページ見出し・操作パネルを追加したり、共通の画面幅・高さを変更したりしません。

対戦は `DuelGame`、協力は `CooperativeGame` がゲームの進行・描画・完了通知を担当します。どちらも確定済みの参加者 `self`・`peer` と、完了通知 `onCompleted` を受け取ります。判定や配置は各担当フォルダの補助ファイルへ分けています。

| 差込口 | 通知する結果 | 共通処理への変換 |
|---|---|---|
| `DuelGame` | `DuelGameResult.win` / `.loss` | `Outcome.win` / `.loss` |
| `CooperativeGame` | `CooperativeGameResult.success` / `.failure` | `Outcome.coopSuccess` / `.coopFailure` |

`game_scene.dart` が相手チームで差込口を選び、型付き結果を共通の `Outcome` へ変換します。`demo_page.dart` が現在のゲーム場面・相手ID・交流開始ごとの識別番号を照合して `DemoController` へ渡し、重複・古い通知を拒否します。ゲーム側の完了通知も一交流につき一度にします。ゲーム内で報酬計算・チーム分岐・再戦禁止・期限処理を複製したり、子分や戦力を直接変更したりしません。

ゲームを修正・追加する際も、確定時に `onCompleted(DuelGameResult.win)` などを一度だけ呼ぶ契約を維持します。`Navigator` で結果画面へ直接移動せず、共通の結果処理へ戻します。毎秒の残り時間更新で親は再描画するため、タイマーやゲーム状態は `State` に保持して `build` で再初期化せず、終了時に `dispose` で解放します。共通ヘッダーはゲームの外で高さを確保するため、ゲーム側でヘッダー用の固定余白を二重に引きません。協力ゲームのレベル・魂ポイント表示もゲーム内で実高さを確保し、文字拡大時に残り時間や操作領域へ重ねません。

対戦と協力は別フォルダで並行開発できます。共通の親画面へ両担当が直接手を入れず、差込口の変更が必要なら統合担当へ調整します。対戦で両者落下・完全同点となる場合は現状 `loss` が返り、共通報酬では相手に普通の子分が付きます。協力の魂ポイントはゲーム内表示のみで、保存や10pt蓄積による復活へ接続されていません。これらの扱いと通信時の離脱・エラー・結果確定は、[残課題](decisions.md)に従って公開API・報酬・テストを合わせて決めます。

## 担当表

実際の担当者はまだ割り当てていません。以下は責務の分け方です。複数人で作業する前に担当者と作業ブランチを記入します。

| 責務 | ソース・素材・関連テスト | 担当・ブランチ |
|---|---|---|
| 画面の流れと入力・接続パネル | `lib/features/demo/demo_page.dart`、`lib/features/demo/game_scene.dart`、関連するwidgetテスト | 未割当 |
| 缶・キャラクターの表示と演出 | `lib/features/demo/can_stage.dart`、`assets/characters/`、関連するwidgetテスト | 未割当 |
| 対戦ゲーム | `lib/features/duel/`、`test/features/duel/` | 未割当 |
| 協力ゲーム | `lib/features/cooperative/`、`test/features/cooperative/` | 未割当 |
| 共通基盤・ルール・データ・接続・統合 | `lib/app/`、`lib/domain/`、`lib/data/`、`lib/main.dart`、共有テスト | 基盤作成者 |
| SDK・依存・プラットフォーム・CI・資料 | `pubspec.*`、`.fvmrc`、`tool/`、`android/`、`web/`、`.github/`、`docs/`等 | 基盤作成者 |

一つのファイルに複数の担当が必要なら、先に部品へ分割して境界を共有します。番号ブランチは未割当です。ブランチ名から担当者を推測したり、他人のブランチを再利用したりしません。

## 統合前に確認すること

- 新規プロフィールが空欄で、入力中のラベルと保存値が一致する。
- 相手・チームが確定する前に結果を適用せず、同じ結果を連打しても二重報酬にならない。
- 普通・骨が双方に正しく追加され、成長しても元の相手プロフィールを保持する。
- 期限直前・ゲーム中・結果表示中・帰還中でも確定報酬と最終集計が整合する。
- 骨は子分だけに適用され、親分は通常の姿を保つ。
- 小さい画面・キーボード・文字拡大でも入力と操作に到達できる。
- 両ゲームの実操作から結果・報酬・帰還・最終集計へつながり、デモ用の結果注入だけで確認を済ませない。
- 魂ポイントを保存済みの報酬と表示せず、両者落下時の暫定動作を認識する。
- 仮想相手との一台デモの確認と、実通信・実機・参加者同士のプレイ確認を区別する。
