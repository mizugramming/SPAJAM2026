# 構成・担当範囲と共通接続

実装の正本は実ファイルです。本書と差がある場合は双方を調べ、古い構成へ戻しません。旧アプリのデータモデル・ルートを本番アプリへ流用しません。

## 現在の構成

```text
lib/main.dart                       起動
lib/app/tsunagun_app.dart            アプリ設定・共通PhoneViewport
lib/app/tsunagun_theme.dart          イラストに合わせた共通色・入力・ボタン
lib/app/tsunagun_typography.dart     同梱Medium 500フォントと選択共有
lib/app/conveyor_settings_scope.dart  保存済み配置の共有
lib/features/online/online_page.dart 通常のルーム・入力・QR・報酬・順位UI
lib/features/online/qr_panel.dart    ゲーム相手QR・カメラ読取・入室コード入力
lib/features/online/online_game.dart 共有時刻と両者の実入力を使うゲーム
lib/data/online_controller.dart     通信版の単一状態・再接続・操作受付
lib/data/online_transport.dart      HTTP/WebSocket・接続先検証
lib/data/online_session_store.dart  参加資格のsecure storage保存
lib/domain/online_room.dart         サーバー状態のモデル・QRコード形式
server/src/index.ts                Worker/DOの認証・接続・保存・配信
server/src/room.ts                 ルーム進行・判定・報酬・集計
lib/features/demo/demo_page.dart    旧一台デモの場面・操作UI
lib/features/demo/game_scene.dart   共通ヘッダーと残り領域を使うゲーム表示枠
lib/features/demo/can_stage.dart    缶・親分・子分・ショBONEの煙・帰還演出
lib/features/demo/parent_character.dart  待機動画・静止画と停止条件
lib/features/demo/font_comparison_controls.dart  DEMO内の書体切替
lib/features/demo/result_sound_player.dart  結果音声の読み込み・再生・停止
lib/features/demo/wavy_title_image.dart  画像見出しの有限の揺れ・読み上げ
lib/features/demo/factory_backdrop.dart  工場背景と場面移動時のコンベア
lib/features/demo/conveyor_editor.dart  配置プレビュー・調整・保存
lib/features/demo/curved_label.dart  実テキストを保った曲面ラベル描画
lib/features/demo/tug_of_war_finale.dart  確定結果を使う最終綱引きの演出
lib/features/demo/illustrated_details.dart  見出し・吹き出し・綱の描画
lib/features/duel/duel_game.dart     吊魚チキンレース・完了通知
lib/features/duel/race_course.dart   落下・停止・勝敗の判定
lib/features/duel/race_field.dart    魚・綱・海のゲーム表示
lib/features/duel/sea_background.dart  缶の内側の背景描画
lib/features/duel/win_dance.dart     対戦勝利の親方ダンス・静止画
lib/features/cooperative/cooperative_game.dart  魂を運ぶ3レベル・完了通知
lib/features/cooperative/soul_course.dart  魂の進行・タイミング判定・仮想相手
lib/features/cooperative/soul_stage.dart   魂・缶・海のゲーム表示
lib/features/cooperative/soul_placement.dart  ゲーム内素材の配置
lib/domain/models.dart              プロフィール・参加者・子分・結果・状態
lib/domain/reward_rules.dart        報酬・成長・戦力・最終集計
lib/data/demo_controller.dart       デモの単一状態・進行管理
lib/domain/conveyor_layout.dart     拡大率・位置の形式と値検証
lib/data/conveyor_settings.dart     配置の端末保存・復元・失敗処理
assets/characters/                  アプリが読むユーザー提供キャラクター
assets/home/                        ユーザー提供のコンベア
assets/fonts/                       比較フォントとOFLライセンス
test/                              モデル・ルール・進行とUIの検証
docs/ui_copy.md                    承認済み画面文言と適用場面
docs/tsunagun/                     v2受領原本（画像・手書きPDFを含む）
```

画面の場面切替とキャラクターの状態を混同しません。`PhoneViewport` が共通枠を管理し、各画面・ダイアログは与えられた制約を使います。端末条件は [app_design.md](app_design.md) に従います。

## 通信版の共通接続

通常の `main` は `OnlineController` をAppへ渡します。Appが参加情報の復元とController破棄を管理し、`OnlinePage` は画面・ローカル入力・結果の見せ方を担当します。`TSUNAGUN_DEMO=true` のビルドだけは `DemoController` へ切り替えます。接続先と実演手順は [online.md](online.md)、APIは [server/README.md](../server/README.md) を参照してください。

- `OnlineRoom` / `OnlineEncounter` はサーバーから受け取った状態です。`OnlineController` の同じ参加者・子分・結果を全画面で使い、画面で報酬・チーム・締切を確定しません。
- HTTP操作は操作IDを付け、ゲーム入力は認証後のWebSocketへ交流ID・round・level・hop・補正した入力時刻を送ります。サーバーは結果を一度保存してから本人向けsnapshotを返します。秘密の参加トークンは通常snapshot・QR・URLに含めません。
- `OnlineGame(controller, onPresentationComplete)` は双方の準備・同期カウント・実ゲーム・同点/中断・結果演出を表示します。`onPresentationComplete` は確定済み結果の演出終了通知で、報酬を決めるコールバックではありません。親は交流ID/roundを照合して結果画面へ移ります。
- 対戦は双方落下なら両者敗北報酬、双方安全の同一ミリ秒なら報酬なし再勝負です。協力は左右を実参加者が交互に操作します。既存の `RaceField` / `SoulStage` などを再利用し、旧デモの仮想相手や自動入力を呼びません。
- 更新版が作るルームの入室は数字5桁のコード入力です。既存の12桁コードも保存期間内は受け付けます。作成APIは新版が `roomCodeDigits: 5` を送り、未指定の旧アプリへは12桁を返すため、未更新のAndroidによる従来の作成・参加を維持します。QRの表示・読取はホームの「ツナがる」以降のゲーム相手との接続に使い、相手コード8桁を読取失敗時の代替にします。通常ルームは同チーム協力・異チーム対戦・同じ相手1回です。発表用だけ同じ2人の対戦→協力各1回を許可します。途中中断・同点は完了に数えません。発表用だけ主催者1人で開始でき、交流時間内の2人目の途中参加・初回プロフィール登録を受け付けます。通常ルームの2人以上開始・途中参加不可は維持します。
- snapshotの `demoParticipants` は発表用のデモ相手と表示補充枠です。実参加者と合わせて6人・赤青各3人を補います。`participants` / サーバーの `members` へ混ぜず、認証や実2台の定員は実参加者だけで扱います。固定4人の初期得点は各チーム4点＋2点で、その後はサーバーが通常のゲーム判定・報酬で更新します。最終集計には同じ子分・骨の内訳を加えます。1人時の追加0点枠は選択不可で、2人目の参加に置き換えます。旧snapshotでこの項目がなければ空リストとして読みます。
- `pairBot` はデモ相手のIDを指定する発表用操作です。QR用の `pair` と分け、ダミーに認証トークンや相手QRを持たせません。ゲーム画面は同じサーバー状態から相手を描画し、実参加者側の入力は自動化しません。占有中のデモ相手・完了済みの交流・切断・期限もサーバーで判定します。
- Webの表示中ウィンドウが選択を失った `inactive` では通信とゲームを継続し、`hidden`・停止ではControllerへ通知して未確定ゲームを通信切断として中断します。ネイティブは `inactive` も中断します。音声は停止し、復帰だけでは再生しません。確定結果はサーバーから復元し、前の通信応答・重複通知で報酬を増やしません。
- ルームは作成から24時間で削除します。端末には `SecureOnlineSessionStore` で参加情報を保存し、ゲーム進行自体の画面専用コピーは保存しません。コンベアの端末設定は既存ストアを使います。

## 共通データと旧デモの処理

- `Profile` は本人・相手のニックネーム、趣味、ひとことです。入力と缶ラベルは同じ編集値を使い、サンプルプロフィールで本人入力を上書きしません。
- `Participant` は参加者とチーム、`Follower` は所持者に残る相手由来の子分です。子分の普通・骨と親分の画像を同じ状態にしません。復活は `promote(helpedBy: Participant)` を使い、ID・取得順・`peerId`・元プロフィールを保持して `revivedWith` に協力相手を記録します。詳細画面では元の相手と復活を手伝った相手を区別して参照します。
- 旧デモは `EncounterResult` と `RewardRules` で双方の報酬を一括計算します。通信版は同じ表示モデルを使い、計算は `server/src/room.ts` で行います。協力成功は骨がある側だけ最古の1匹を復活し、骨がない側は相手の普通子分1匹を迎えます。失敗は両者に骨1匹です。ゲームUIが直接子分数や戦力を書き換えません。
- `EncounterResult.newFollower` はnullableです。復活は `newFollower == null`・`promoted != null`、新規の仲間入りはその逆です。表示する1匹は `rewardFollower` を使います。復活の `delta` は2、骨なし成功は3で、報酬の前後差から計算します。「協力成功なら必ずREBORN」「必ず骨追加」と判定しません。
- 旧一台デモの `DemoController` は単一の `ChangeNotifier` で、ルーム進行・相手・結果・所持状態を管理します。画面専用の子分リストや二つ目の保存先を作りません。`completedPeerIds` により失敗後も同じ相手との再戦を拒否します。純粋な `RewardRules` でも双方の `peerId` と `revivedWith.id` を調べ、復活だけで新規子分を追加しなかった交流を含めて二重決済を拒否します。
- `FinalSnapshot` は終了時の集計です。画面演出やホームへの帰還で結果を作り直したり、期限後に新規交流を再開したりしません。
- 旧一台デモの進行だけはメモリ内です。通常通信版の再接続・永続化は前節のControllerとサーバーが担当します。

公開メソッドの引数と戻り値は現在のソース・関連テストを確認して使用します。変更が必要な場合は、呼び出し側とテストを含めて統合担当へ影響を示します。

## ゲーム以外の表示と最終演出

- 工場の壁・窓・配管と缶下のコンベアは `factory_backdrop.dart` が担当します。場面移動時だけ短時間動かし、入力・待機中は静止します。ゲーム本体には背景を重ねず、`PhoneViewport` やゲームへ渡す制約を変更しません。
- `ConveyorPlatform` は提供画像を3:1で表示します。既定は缶底をベルト面に合わせ、`CanStage.conveyorLayout` でベルトだけ拡縮・XY移動します。横の余剰はベルト専用ClipRectで隠し、下の余剰はステージ内へ予約します。缶・親分・帰還演出の元の座標系と共通スマホ枠は維持します。
- `ConveyorEditor` は保存済み配置のコピーを編集し、保存成功までは本画面へ適用しません。閉じると取り消し、初期化も明示保存で確定します。コピーはその時点のプレビュー値です。イベント時計は止めませんが、期限到達でこの編集画面は閉じず、編集終了後に最終場面を表示します。
- `ConveyorSettings` と `ConveyorLayoutStore` が配置を保存します。起動時は `main` がSharedPreferences版を読み込んでAppへ注入し、テストや直接Appを作るプレビューはMemory版を使います。JSONを単一キーへ保存し、成功後だけ公開値を更新します。破損・読み書き失敗は既定または前回値を維持して画面へ伝えます。独自の画面用保存先を追加しません。
- 保存形式は `schemaVersion:1`、`scale`（0.6〜3.0）、`offsetX`・`offsetY`（-100〜100）です。位置は缶幅286論理pxを基準に実表示の缶幅に比例させます。正のXは右、正のYは下。公開型は `ConveyorLayout`、保存キーは `tsunagun.conveyor.layout.v1`。読み込みでは形式・バージョン・有限値・範囲を検証します。
- 親分の待機は `ParentCharacter` の透過WebPで、ホーム・相手確認かつ缶の登場演出後だけ再生します。動作軽減・バックグラウンド・無効な `TickerMode` では同寸法のPNGへ切り替えます。UIテストは `TsunagunApp(animateCharacters: false)` で無限ループだけを止め、缶やゲームの一度で終わる演出は検証します。
- 書体の既定はKaisei Tokumin Medium 500です。`TypographyScope` でM PLUS Rounded 1c Medium 500へ切り替え、画面とControllerの状態を保持します。曲面ラベルは選択中の実フォントとOSの文字拡大・太字で計測します。
- `CanStage` のショBONEは提供された画像見出しを使い、有限の揺れと一度で消える煙を伴います。見出しの実際の描画幅から高さを確保し、読み上げは「ショBONE」を維持します。REBORNは復活した普通の子分1匹だけを表示します。帰還時の缶底を越えない位置制約を維持します。
- `OnlinePage` / `DemoPage` が結果への遷移を監視し、敗北・協力失敗の初回描画後に `ResultSoundPlayer.playShobone` を呼びます。`CanStage` や `build` から再生せず、コンベア編集のプレビューと二重に鳴らしません。`main` は素材再生版を注入し、直接 `TsunagunApp` を作るテスト・プレビューは既定で無音です。Pageが停止・破棄を管理し、音声エラーを報酬処理へ伝播させません。詳しい条件は [素材管理](assets.md#ショboneの音声) を参照してください。
- `TugOfWarFinale` は通信版では `serverStartAt` / `serverNow` へ同期し、`onStartRequested` / `canStart` で主催者だけが共有開始を要求します。途中表示・復帰は経過位置へ追いつき、動作軽減でも11秒後まで結果を伏せます。通信版に片側だけのスキップはありません。旧デモの手動開始後は、構え3秒・引き合い6.5秒・決着1.5秒で確定結果を開示します。紙吹雪は開示から2秒で消えます。動作軽減設定・両チーム0ptの場合も開始を待ち、押した後は決着を直接表示します。背景の観客は12匹固定で、所持子分数や得点を表しません。開始後の引き合い・決着中は席ごとに位相をずらして小さく跳ね、開始前・演出終了後・スキップ・動作軽減では静止します。既存の有限アニメーションを使い、追加の常時ループは作りません。
- チーム・個人の内訳は確定した `FinalSnapshot.rankings` の普通子分数・骨数から表示します。演出用の観客や親分を集計へ加えず、開始・スキップ・再描画でも結果を再計算しません。
- MVPに親分と子分のイラストを置き、内訳を読みやすく表示します。同点の説明文を省いても、共同MVPと同順位の規則は維持します。順位一覧は `rank <= 3` を全て表示し、本人が4位以下の場合だけ「あなたの順位」に追加します。先頭3人で切ったり、表示用に順位を振り直したりしません。
- 文言の正本は [ui_copy.md](ui_copy.md) です。詳しい仕様・未実装範囲は [decisions.md](decisions.md) に従います。

## 旧一台デモのゲーム接続

同チームは魂を缶へ運ぶ3レベルの協力ゲーム、別チームは吊られた魚を海の手前で止めるチキンレースです。どちらも最初のタップで開始し、相手は一台デモの仮想参加者です。ゲームの実結果から報酬へ進めます。手動の結果注入は確認用に残します。

`game_scene.dart` の `game-surface` は共通 `PhoneViewport` 内の安全領域全体を使う表示枠です。上部に相手・残り時間・`DEMO` の共通ヘッダーを実レイアウトし、必要な高さを確保した残りを `Expanded` でゲームへ渡します。ゲーム中は共通画面の缶・親分を重ねません。ゲーム自身が使う缶・キャラクターなどの素材とは区別します。ゲーム中の結果選択・時刻早送りは右上の `DEMO` メニューからのみ使います。メニューの開閉と結果適用は `demo_page.dart` が担当します。ゲームは装飾枠なしで渡された残り領域いっぱいを使います。通常のページ見出し・操作パネルを追加したり、共通の画面幅・高さを変更したりしません。

対戦は `DuelGame`、協力は `CooperativeGame` がゲームの進行・描画・完了通知を担当します。どちらも確定済みの参加者 `self`・`peer` と、完了通知 `onCompleted` を受け取ります。判定や配置は各担当フォルダの補助ファイルへ分けています。

| 差込口 | 通知する結果 | 共通処理への変換 |
|---|---|---|
| `DuelGame` | `DuelGameResult.win` / `.loss` | `Outcome.win` / `.loss` |
| `CooperativeGame` | `CooperativeGameResult.success` / `.failure` | `Outcome.coopSuccess` / `.coopFailure` |

`game_scene.dart` が相手チームで差込口を選び、型付き結果を共通の `Outcome` へ変換します。`demo_page.dart` が現在のゲーム場面・相手ID・交流開始ごとの識別番号を照合して `DemoController` へ渡し、重複・古い通知を拒否します。ゲーム側の完了通知も一交流につき一度にします。ゲーム内で報酬計算・チーム分岐・再戦禁止・期限処理を複製したり、子分や戦力を直接変更したりしません。

対戦は判定が揃った時点で任意の `onResolved` へ一度通知し、既存の `onCompleted` は演出終了時に一度通知します。どちらも `GameScene` で `Outcome` へ変換し、`DemoPage` の交流識別番号・相手ID・場面のガードを通します。`DemoController.reserveOutcome` は受付可能な対戦結果を1件だけ保持し、通常完了または終了猶予の打切り時に共通の報酬処理で一度だけ適用します。確定後のDEMO操作で別の結果へ上書きせず、未確定のゲームには報酬を付けません。リセット・新しい交流・決済で予約を消します。協力ゲームの既存 `onCompleted` 契約は維持します。`Navigator` で結果画面へ直接移動せず、共通の結果処理へ戻します。毎秒の残り時間更新で親は再描画するため、タイマーやゲーム状態は `State` に保持して `build` で再初期化せず、終了時に `dispose` で解放します。対戦勝利は判定表示の後に親方が7秒踊り、1秒後からタップで省略できます。背景は缶の内側の画像を上部ヘッダーにも敷き、文字の後ろに薄い板を置きます。落下時の強い振動・協力で魂を運べた時の軽い振動は対応端末の設定に従います。共通ヘッダーはゲームの外で高さを確保するため、ゲーム側でヘッダー用の固定余白を二重に引きません。協力ゲームのレベル・魂ポイント表示もゲーム内で実高さを確保し、文字拡大時に残り時間や操作領域へ重ねません。

PR #46のゲーム背景・振動・勝利ダンスを統合し、対戦の確定通知だけ任意APIとして追加しています。対戦と協力は別フォルダで並行開発できます。共通の親画面へ両担当が直接手を入れず、差込口の変更が必要なら統合担当へ調整します。対戦で両者落下・完全同点となる場合は現状 `loss` が返り、共通報酬では相手に普通の子分が付きます。協力の魂ポイントはゲーム内表示のみで、保存や10pt蓄積による復活へ接続されていません。これは旧デモ固有の制限です。通常通信版は本書の「通信版の共通接続」と[最新の決定](decisions.md)に従います。

## 担当表

実際の担当者はまだ割り当てていません。以下は責務の分け方です。複数人で作業する前に担当者と作業ブランチを記入します。

| 責務 | ソース・素材・関連テスト | 担当・ブランチ |
|---|---|---|
| 通常アプリの画面・QR | `lib/features/online/online_page.dart`、`qr_panel.dart`、関連テスト | 統合担当と調整 |
| 通信版ゲーム | `lib/features/online/online_game.dart`、関連テスト | 統合担当と調整 |
| 通信・サーバー・保存 | `lib/data/online_*.dart`、`lib/domain/online_room.dart`、`server/` | 基盤作成者 |
| 旧デモの画面の流れと入力・接続パネル | `lib/features/demo/demo_page.dart`、`lib/features/demo/game_scene.dart`、関連するwidgetテスト | 未割当 |
| 缶・キャラクター・工場背景と演出 | `lib/features/demo/can_stage.dart`、`lib/features/demo/factory_backdrop.dart`、`assets/characters/`、関連するwidgetテスト | 未割当 |
| 対戦ゲーム | `lib/features/duel/`、`test/features/duel/` | 未割当 |
| 協力ゲーム | `lib/features/cooperative/`、`test/features/cooperative/` | 未割当 |
| 共通基盤・ルール・データ・接続・統合 | `lib/app/`、`lib/domain/`、`lib/data/`、`lib/main.dart`、共有テスト | 基盤作成者 |
| SDK・依存・プラットフォーム・CI・資料 | `pubspec.*`、`.fvmrc`、`tool/`、`android/`、`web/`、`.github/`、`docs/`等 | 基盤作成者 |

一つのファイルに複数の担当が必要なら、先に部品へ分割して境界を共有します。番号ブランチは未割当です。ブランチ名から担当者を推測したり、他人のブランチを再利用したりしません。

## 統合前に確認すること

- 新規プロフィールが空欄で、入力中のラベルと保存値が一致する。
- 相手・チームが確定する前に結果を適用せず、同じ結果を連打しても二重報酬にならない。
- 双方の骨有無を別々に判定し、復活だけの場合に新しい骨を追加しない。復活時の元プロフィールと協力相手を保持し、二重決済を拒否する。
- 成功・失敗の子分表示と内訳が実報酬に一致し、REBORNで骨を併置しない。
- 期限直前・ゲーム中・結果表示中・帰還中でも確定報酬と最終集計が整合する。
- 骨は子分だけに適用され、親分は通常の姿を保つ。
- 綱引きが開始待ちから一度だけ進み、決着まで得点を隠し、有限の紙吹雪後に確定結果と内訳を保つ。観客数で集計を変更しない。
- 小さい画面・キーボード・文字拡大でも入力と操作に到達できる。
- 両ゲームの実操作から結果・報酬・帰還・最終集計へつながり、デモ用の結果注入だけで確認を済ませない。
- 魂ポイントを保存済みの報酬と表示せず、通信版の両者落下は双方骨・完全同点は無報酬再勝負を確認する。
- 入室コード→ゲーム相手のQR読取→双方準備完了から2台のゲーム・結果へつながり、切断・再送・再接続で未確定結果の自動敗北や報酬の二重適用を起こさない。
- 仮想相手との一台デモの確認と、実通信・実機・参加者同士のプレイ確認を区別する。
