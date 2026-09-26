# 構成・担当範囲と共通接続

実装の正本は実ファイルです。本書と差がある場合は双方を調べ、古い構成へ戻しません。旧アプリのデータモデル・ルートを本番アプリへ流用しません。

## 現在の構成

```text
lib/main.dart                       起動
lib/app/tsunagun_app.dart            アプリ設定・共通PhoneViewport
lib/app/tsunagun_theme.dart          イラストに合わせた共通色・入力・ボタン
lib/features/demo/demo_page.dart    一台デモの場面・操作UI
lib/features/demo/game_scene.dart   安全領域全体を使うゲーム表示枠
lib/features/demo/can_stage.dart    缶・親分・子分と演出
lib/features/demo/illustrated_details.dart  見出し・吹き出し・綱の描画
lib/features/duel/duel_game.dart     対戦ゲームの差込口
lib/features/cooperative/cooperative_game.dart  協力ゲームの差込口
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

## ゲームを追加するとき

同チームは協力、別チームは対戦です。現在のゲーム枠は空で、結果注入はデモ用です。正式なゲーム内容は未決定です。

`game_scene.dart` は共通 `PhoneViewport` 内の安全領域全体をゲームに渡す表示枠です。缶・親分を右下へ小さく重ね、ゲーム中の結果選択・時刻早送りは右上の `DEMO` メニューからのみ使います。メニューの開閉と結果適用は `demo_page.dart` が担当します。通常のページ見出し・操作パネルをゲームの前後へ追加して領域を狭めたり、共通の画面幅・高さを変更したりしません。

対戦担当は `DuelGame`、協力担当は `CooperativeGame` を実装します。どちらも確定済みの参加者 `self`・`peer` と、完了通知 `onCompleted` を受け取ります。現在は準備中表示のみで、自動で結果を作りません。

| 差込口 | 通知する結果 | 共通処理への変換 |
|---|---|---|
| `DuelGame` | `DuelGameResult.win` / `.loss` | `Outcome.win` / `.loss` |
| `CooperativeGame` | `CooperativeGameResult.success` / `.failure` | `Outcome.coopSuccess` / `.coopFailure` |

`game_scene.dart` が相手チームで差込口を選び、型付き結果を共通の `Outcome` へ変換します。`demo_page.dart` が現在のゲーム場面・相手ID・交流開始ごとの識別番号を照合して `DemoController` へ渡し、重複・古い通知を拒否します。ゲーム側の完了通知も一交流につき一度にします。ゲーム内で報酬計算・チーム分岐・再戦禁止・期限処理を複製したり、子分や戦力を直接変更したりしません。

各担当者は自分のゲームWidgetの `build` の中身を置き換え、確定時に `onCompleted(DuelGameResult.win)` などを一度呼びます。`Navigator` で結果画面へ直接移動せず、共通の結果処理へ戻します。毎秒の残り時間更新で親は再描画するため、タイマーやゲーム状態は `State` に保持して `build` で再初期化せず、終了時に `dispose` で解放します。上部の状態表示・右下の缶は共通側が重ねるので、重要なゲーム操作をその直下へ配置しません。

対戦と協力は別ファイルで並行開発できます。共通の親画面へ両担当が直接手を入れず、差込口の変更が必要なら統合担当へ調整します。引き分け、離脱、エラー、制限時間と結果の正当性は未決定です。正式ゲームを実装する前に扱いを決め、必要な公開APIとテストを統合担当と更新します。

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
- 一台デモの確認と実通信・実機・正式ゲームの確認を区別する。
