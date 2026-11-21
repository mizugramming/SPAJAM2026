# ゲームの状態と接続

| 担当 | ファイル | 入出力と責務 |
|---|---|---|
| 共通・組み込み | `lib/main.dart` | セッション、入力モード、端末ライフサイクル。WorkshopActionsを実装し、画面からの操作をゲームと端末へ接続 |
| 共通・ルール | `lib/game/game.dart` | 素材カタログ、やすり、声の分類、研磨量、時計、振動指令、採点 |
| UI | `lib/ui/workshop.dart`, `workshop_theme.dart`, `surface_art.dart` | 段階ごとの画面・共通部品・表面描画。Workshopはgameを読み、actionsへ操作を返す |
| 端末 | `lib/device_main.dart`, `lib/device/workshop_device.dart`, `lib/device/diagnostics.dart` | 計測専用入口、実機／疑似入力、4条件・振動の比較 |
| 端末 | `android/app/src/main/kotlin/jp/spajam/polish_workshop/` | MainActivityがマイク・加速度・振動を橋渡し。VoiceAnalysisは音高、DeskMotionは作業面に沿う手の動き、DeskHapticsは質感の時間パターンを担当 |
| 共通・検証 | `test/`, `tool/native/` | 状態と時間境界、入力から再挑戦までのUI、声・接触・往復・振動パターンの回帰確認 |

## ゲームが持つ値

`GameController`（ChangeNotifier）が `phase`, `material`, `round`（1始まり）, `remainingSeconds`, `strokes`（当回）, `totalStrokes`, `value`, `progress`, `stage` を持つ。採音前の `sample` と `grit`、未採点の `verdict` はnull。3回目の期限で結果を一度確定する。ゲーム時刻は単調時計、アクティブな研磨時間は各10秒。期限後に届いた往復は無効。

素材値は残量で、初期値から1往復あたり粗目5・中目3・細目1.5を引く。初期2素材は100から0。正規化進捗は `(initialValue - value) / maxRemoval` を0〜1に制限した値。画面はこれを `stageAt / colorAt / rustAt / shineAt` に渡し、振動は同じ往復の更新後進捗を使う。停止時の自動加算はない。

`pulseFor(grit, progress)` がゲームのやすりと研磨率から振幅・長さの基準値を返す。本編ではラウンド開始と各往復の確定時にその値をAndroidへ渡す。Androidは加速度を見ながら短い接触振動を開始し、手の動きが続く間だけ振動を更新する。テンポで一擦りの長さ、やすりで刻み、研磨率で振動を出す割合が変わる。REDMIは振幅指定に非対応なので時間配分で違いを表現する。

推定周期が0.5秒以下の速い往復では、押し・引きのそれぞれで方向転換を検出すると、50〜80ミリ秒の短い波形を1回出す。往復を終えたときにだけ研磨量が増える。ゆっくりした粗目の往復では、最長1秒の長い波形が手の動きに伴って続く。

## 素材の追加と採点の交換

1. `lib/game/game.dart` の `materials` に一意なidの `WorkMaterial` を加える。名前、任意の紹介文、初期値、削れる最大量、任意の目標残量 `targetValue` を設定する。メダル形は既定、刻字板は `glyph: '漢'` のように字を渡す。
2. `stages` は0から始まる昇順の進捗境界。各 `FinishStage` に名前、色、汚れ量、光沢（各0〜1）を設定する。名前は境界に達したときに変え、色・汚れ・光沢は隣り合う境界を補間する。初期メダルの境界は0/25/55/85%、漢は0/38/80%。選択・3ラウンド・結果はカタログから共通の流れに載る。新しい形・演出はUI担当が表面描画に追加する。
3. 目標と採点が決まったら `FinishJudge`（素材と確定残量→任意の判定文）を `GameController(judge: ...)` に渡す。呼び出し元は `lib/main.dart`。目標なしはnullを返せる。削り量や段階名の関数を変えずに採点を差し替えられる。

## 端末との契約

`polish/device`（MethodChannel）の `capture` は約1.2秒で `{hz: double?, level: double}` を返す。levelはPCM全体のRMSを−60〜0 dBFSから0〜1へ正規化。ゲーム側の `classify` が実機と疑似入力に共通の境界を適用する。安定したHzがない場合はnull。採音失敗・拒否は素材値を保持し再操作できる。

本編の `capture(desk: true)` は採音中だけ机に置いた端末の静止時のデータを集める。安定した区間が得られなくても採音は有効で、研磨開始時の姿勢から判定できる。

本編は `startMotion` にやすり、現在の研磨率、パルス基準値、振動設定、残りミリ秒、開始・再開ごとの `sessionId` を渡す。`polish/strokes` の整数は2が接触開始、−1が離れた合図、1が確定した往復。ゲームは1でだけ削り量を確定し、更新後の `progress` と同じ `sessionId` を `pulse(followStroke: true)` でAndroidへ返す。机と平行な手の動きと重力方向の動きから接触・離脱を判定する。机からの絶対的な高さは測定できない。

診断の `startMotion(deskTrial: true)` は同じ運動判定で、設定した固定パルスだけを出す。中断時は `cancelCapture / stopMotion / stopPulse` で後続の入力と出力を止める。加速度と音声の生データはFlutterへ送らず、保存しない。
