# 素材管理

| 素材 | アプリ側の配置 | 出典・用途 |
|---|---|---|
| 親分 | `assets/characters/oyabun.png` | ユーザー提供の背景透過版（1402 × 1122px）。親分は常に通常の姿。綱引き・MVPなどの静止表示用 |
| 親分の待機ループ・停止画 | `assets/characters/oyabun_idle.webp`・`oyabun_idle_poster.png` | ユーザー提供MP4から透過・短区間化。432 × 345px、2.5秒ループ |
| ベルトコンベア | `assets/home/conveyor_belt.png` | ユーザー提供Belt.pngを無加工でコピー。2172 × 724px、3:1、873,382 bytes |
| 普通の子分 | `assets/characters/kobun_normal.png` | ユーザー提供のv2原画から白背景を透過したもの |
| 骨の子分 | `assets/characters/kobun_bone.png` | ユーザー提供のv2原画から白背景を透過したもの。「ショBONE」は骨子分の表現 |
| 対戦の吊られた魚（赤・青） | `assets/characters/hikareruaka.png`・`hikareruao.png` | ユーザー提供。対戦ゲームで自分・相手のチーム色の魚として使用 |
| ゲームの背景（海と砂地） | `assets/characters/tunaumi1.png`・`tunaumi2.png` | ユーザー提供。2枚を交互に重ねて砂地をゆらす。対戦・協力で共用 |
| 協力の魂 | `assets/characters/tamashii.png` | ユーザー提供。協力ゲームで運ぶ魂 |
| 協力のツナ缶・空き缶 | `assets/characters/tunakanaka.png`・`hadakan.png` | ユーザー提供。魂を運ぶ缶と、最後に魂が入る空き缶 |
| 手書きラフ・旧生成画像 | `docs/tsunagun/references/` | 設計の参照用。アプリへ全量同梱しない |

提供資料の原本は [v2資料](tsunagun/README.md) と [出典一覧](tsunagun/references/SOURCE_INDEX.md) に保持し、変更しません。アプリは `assets/characters/` と `assets/home/` のファイルを使用します。

2026-09-27、親分はユーザー指定の `tsunagun_design_v2/assets/characters/image.png` を加工せずアプリ用の配置へコピーしました。子分2種はユーザーの許可を受け、プログラムで外側につながる白背景を透過し、周囲の余白を整理しました。元のRGB値を保ち、白い腹や骨は残しています。生成AIによるキャラクターの描き直しは行っていません。

缶は2026-09-27にユーザーが提示した缶イラストの輪郭・銀色の金属縁・曲面のラベルを参考に、コードで描画します。ラベルの文字は入力内容と文字拡大に追従するWidgetで表示し、画像へ焼き込みません。缶・見出し・吹き出し・綱はコード描画です。旧画像のメンバー・タブ・ゲーム等を、素材に描かれているという理由で機能へ戻しません。

## 比較用の日本語フォント

2026-09-27、ユーザー指定の **Kaisei Tokumin Medium 500** を既定にし、比較候補として **M PLUS Rounded 1c Medium 500** を追加しました。フォントはアプリへ同梱し、実行時のネットワーク取得やフォント用依存パッケージを使いません。

| 正式名 | アプリ側の配置・登録 | 元TTFのサイズ | 出典 |
|---|---|---:|---|
| Kaisei Tokumin Medium | `assets/fonts/KaiseiTokumin-Medium.ttf` / family `KaiseiTokumin` / weight `500` | 4,367,444 bytes（約4.17 MiB） | [Google Fontsの元TTF](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/kaiseitokumin/KaiseiTokumin-Medium.ttf)、[メタデータ](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/kaiseitokumin/METADATA.pb) |
| M PLUS Rounded 1c Medium | `assets/fonts/MPLUSRounded1c-Medium.ttf` / family `MPlusRounded1c` / weight `500` | 3,432,624 bytes（約3.27 MiB） | [Google Fontsの元TTF](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/mplusrounded1c/MPLUSRounded1c-Medium.ttf)、[メタデータ](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/mplusrounded1c/METADATA.pb) |

取得時のGoogle Fontsコミットは `23e54b51ddffbc7713c583748e3bd86f62b1fa4a` です。TTF本体は改変せず、サブセット化や別ウェイトへの変換も行っていません。元ファイルとの一致確認用SHA-256は次のとおりです。

- `KaiseiTokumin-Medium.ttf`: `fc58ac081468ca3a06c9f8b89077fbbf01c57729c1d5787cc7f33adb3e40d6f3`
- `MPLUSRounded1c-Medium.ttf`: `adfde1b6bae58719c4e0144612a94232e72fc5ca655c4722165fe88d06521a70`

両フォントは **SIL Open Font License 1.1** です。著作権表示とライセンス本文を以下のファイルへ同梱し、アプリのライセンス登録にも使用します。素材の入れ替え時はフォントだけをコピーせず、対応する著作権表示・本文を保持してください。

- `assets/fonts/OFL-KaiseiTokumin.txt`: [Google Fonts同梱のOFL本文](https://github.com/google/fonts/blob/23e54b51ddffbc7713c583748e3bd86f62b1fa4a/ofl/kaiseitokumin/OFL.txt)をそのまま保存。著作権は `Copyright 2020 The Kaisei Project Authors (https://github.com/Font-Kai/Kaisei)`。
- `assets/fonts/OFL-MPlusRounded1c.txt`: [Google Fonts公式配布マニフェスト](https://fonts.google.com/download/list?family=M%20PLUS%20Rounded%201c)の `manifest.files` 内 `OFL.txt` の本文を保存。配布本文に著作権行がないため、元TTFのnameテーブルと公式メタデータに一致する `Copyright 2016 The Rounded M+ Project Authors.` を先頭へ付記しました。ライセンス本文自体は変更していません。

比較操作は[READMEの案内](../README.md#フォントを比べる)を参照してください。通常の比較は両方のMedium 500を使い、別の太さを比較したかのように説明しません。スマホの小さい日本語、曲面ラベル、長いプロフィール、文字拡大で読みやすさを確認し、フォント変更のために共通の画面幅・高さを変えません。

## 親分の待機アニメーション

2026-09-27、ユーザー提供の `つなぐん動画.mp4`（668 × 612px、24fps、10.07秒）を受領しました。原本は上書きせず、缶上の待機に合う素材へ変換しています。

- 原本には手や尾びれが画面外に切れる場面があるため、全身の収まる **2.000〜2.667秒未満（frame 48〜63）** を採用しました。全10秒をそのまま再生する実装ではありません。
- 外周につながる白背景と床影を透過し、白い腹・目を残しました。全フレームで同じ範囲 `(0,45)-(668,578)` を切り出し、432 × 345pxへ縮小。生成AIによる描き直しは行っていません。
- `oyabun_idle.webp` は12fps・半速の往復30フレームで **2.5秒の無音ループ**、604,278 bytesです。先頭と末尾で急に別の姿勢へ飛ばないようにしています。
- `oyabun_idle_poster.png` は同じ構図の先頭フレームで124,049 bytesです。動画・停止画の寸法と足元を揃え、缶上面に配置します。アニメーション中の跳躍は原本の動きです。
- ホーム・相手確認で、缶からの登場演出が終わってから再生します。登場演出中・動作軽減設定・バックグラウンド・無効なTickerModeでは停止画へ切り替えます。読込失敗時は停止画、さらに失敗した場合は元の親分PNGを表示します。
- 原本MP4や変換用ライブラリをアプリへ追加せず、Flutter標準の画像再生を使います。綱引き・MVPには既存の静止PNGを使い、ミニゲーム素材は変更しません。

全16ポーズとブラウザーで透過境界・配置・ループを確認しました。REDMI Note 15 5G実機の再生負荷と電池消費は未確認です。[FlutterのImage公式資料](https://api.flutter.dev/flutter/widgets/Image-class.html)と[GoogleのWebP公式資料](https://developers.google.com/speed/webp)にアニメーション・透過の対応が記載されています。

## ベルトコンベア

ユーザー提供の `Belt.png` を `assets/home/conveyor_belt.png` へ無加工でコピーしました。SHA-256は `0d02e060b2b56239b1279fc2769d75f605c279602b596e55a2a0eb9ea43ed8f8` です。原本の3:1比率を保ち、缶の下端を画像内のベルト面（高さ44%）へ合わせます。脚が画面へ重ならないよう場面内へ高さを予約します。場面移動時に重ね描きする車輪線だけを短時間動かし、入力中・待機中には止めます。

## 素材の追加

画像追加時は担当フォルダへ置き、参照するソースと同じPRに含めます。`pubspec.yaml` の登録変更は共通管理です。元画像の権利・配布条件の記録が必要なら提供者に確認し、確認していないライセンスを推測で記載しません。
