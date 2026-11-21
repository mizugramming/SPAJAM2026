# ゲームの状態と接続

| 担当 | ファイル | 入出力と責務 |
|---|---|---|
| 共通・組み込み | `lib/main.dart` | セッション、入力モード、端末ライフサイクル。WorkshopActionsを実装し、画面からの操作をゲームと端末へ接続 |
| 共通・ルール | `lib/game/game.dart` | 素材カタログ、やすり、声の分類、研磨量、時計、振動指令、採点 |
| UI | `lib/ui/workshop.dart`, `workshop_theme.dart`, `surface_art.dart` | 段階ごとの画面・共通部品・表面描画。Workshopはgameを読み、actionsへ操作を返す |
| 端末 | `lib/device_main.dart`, `lib/device/workshop_device.dart`, `lib/device/diagnostics.dart` | 計測専用入口、実機／疑似入力、4条件・振動の比較 |
| 端末 | `android/app/src/main/kotlin/jp/spajam/polish_workshop/` | MainActivityがマイク・加速度・振動を橋渡し。VoiceAnalysis、StrokeDetectorが信号を処理 |
| 共通・検証 | `test/game_test.dart`, `test/workshop_flow_test.dart`, `test/diagnostics_test.dart`, `tool/native/SignalCheck.kt` | 状態と時間境界、入力から再挑戦までのUI、合成信号の回帰確認 |

## ゲームが持つ値

`GameController`（ChangeNotifier）が `phase`, `material`, `round`（1始まり）, `remainingSeconds`, `strokes`（当回）, `totalStrokes`, `value`, `progress`, `stage` を持つ。採音前の `sample` と `grit`、未採点の `verdict` はnull。3回目の期限で結果を一度確定する。ゲーム時刻は単調時計、アクティブな研磨時間は各10秒。期限後に届いた往復は無効。

素材値は残量で、初期値から1往復あたり粗目5・中目3・細目1.5を引く。初期2素材は100から0。正規化進捗は `(initialValue - value) / maxRemoval` を0〜1に制限した値。画面はこれを `stageAt / colorAt / rustAt / shineAt` に渡し、振動は同じ往復の更新後進捗を使う。停止時の自動加算はない。

```dart
final pulse = game.stroke();
if (pulse != null && device.vibrationEnabled) {
  await device.pulse(pulse, followStroke: true);
}
```

`pulseFor(grit, progress)` は粗さと進捗から振幅・長さの基準値を作る。振幅を指定できないREDMIでは、Android側の `StrokeDetector.strokePulseDuration` が往復の周期に合わせて実際の長さを決める。手触りの基準は、遅い往復では最大1秒の連続振動、速い往復では約250 msの振動と約120 msの休止。検出した1往復につき1回出力し、細目・仕上げ・さらに速い動きではパルスを短くする。計測画面の定周期パルスは独立した固定長で比較できる。

## 素材の追加と採点の交換

1. `lib/game/game.dart` の `materials` に一意なidの `WorkMaterial` を加える。名前、任意の紹介文、初期値、削れる最大量、任意の目標残量 `targetValue` を設定する。メダル形は既定、刻字板は `glyph: '漢'` のように字を渡す。
2. `stages` は0から始まる昇順の進捗境界。各 `FinishStage` に名前、色、汚れ量、光沢（各0〜1）を設定する。名前は境界に達したときに変え、色・汚れ・光沢は隣り合う境界を補間する。初期メダルの境界は0/25/55/85%、漢は0/38/80%。選択・3ラウンド・結果はカタログから共通の流れに載る。新しい形・演出はUI担当が表面描画に追加する。
3. 目標と採点が決まったら `FinishJudge`（素材と確定残量→任意の判定文）を `GameController(judge: ...)` に渡す。呼び出し元は `lib/main.dart`。目標なしはnullを返せる。削り量や段階名の関数を変えずに採点を差し替えられる。

## 端末との契約

`polish/device`（MethodChannel）の `capture` は約1.2秒で `{hz: double?, level: double}` を返す。levelはPCM全体のRMSを−60〜0 dBFSから0〜1へ正規化。ゲーム側の `classify` が実機と疑似入力に共通の境界を適用する。安定したHzがない場合はnull。採音失敗・拒否は素材値を保持し再操作できる。

`startMotion` から `stopMotion` の間だけ検出する。`polish/strokes`（EventChannel）の整数1が完了した往復1回。振動指令は `pulse(durationMs, amplitude, followStroke?)` で、ゲームは `followStroke: true` を渡す。診断は `hasAmplitudeControl` の応答で振幅表示を切り替える。中断は `cancelCapture / stopPulse`。ゲームは権限応答・採音の非同期結果に操作番号を持たせ、終了後の古い応答を破棄する。加速度・音声の生データをFlutterへ転送・保存しない。
