# 素材・日本語フォント

漢の銘板、汚れ・粒子・反射光は本選用の自作描画。

## 画像

チームが自作（手描き・編集）した画像。2026-11-22に追加。`pubspec.yaml` に1枚ずつ登録している。メダル4枚はファイル名の末尾が `.jpg` で、中身は透過PNG。研磨中はこの絵にゲームの研磨率に応じたサビと光沢、往復に応じた反射を重ねる。

| ファイル | 使う場所 |
|---|---|
| `assets/fonts/daou.jpg` | サビた銅メダル。タイトル、素材選択カード、研磨のサビた銅・銅の段階 |
| `assets/fonts/gin.jpg` | 銀メダルの段階 |
| `assets/fonts/kin.jpg` | 金メダルの段階 |
| `assets/fonts/kinpika.jpg` | 研磨95%以上の金メダル |
| `assets/images/background.jpg` | タイトル・素材選択・研磨などの全画面の背景 |
| `assets/images/shavings.png` | メダル・漢の研磨中の削りかす（透過PNG）。2026-11-22にチームから受け取った1536×1024を512×341へ縮小。出典の詳細は未記録。押し引きの途中に出る粉の軌跡として使う |
| `assets/images/shards/` | 同じ削りかす画像の元サイズから切り出した赤茶4枚・青緑3枚の破片（周囲の薄い粉は透明化）。1往復が確定すると、やすりの目に応じた大きさ・数の破片を飛ばす。素材とその時点の仕上がりに合わせて削り粉・破片を着色する |

2026-11-22にチームから受け取った未使用の画像も同じ場所に置いている（出典の詳細は未記録）。`assets/fonts/kagami.jpg`（磨きすぎ用）、`assets/images/gyansu.jpg`、`assets/images/yansu.jpg` と `assets/images/shards/yansu.jpg` は未使用。アプリには使用中の画像だけを個別に登録する。

紙やすりの質感には、2026-11-22にユーザーが本アプリ用に提供した無地の紙の画像を使用。透明な余白を詰めた `assets/images/sandpaper_plain.webp`（1320 × 785、約114 KiB）を同梱した。紙の端の繊維と右上の折れは原画のもの。2枚目の画像にある斜めの印字を参考に、`lib/ui/sandpaper.dart` で各ラウンドの測定値を重ねる。紙色を調整する入口は `sandpaperColorFor`、印字は `sandpaperStampFor`。

メダル画像は1枚2MB前後あり、表示時は `cacheWidth` で縮小して読み込む。容量を減らす場合は縮小した画像に差し替える。磨きすぎ用の `kagami.jpg` は、磨きすぎの判定がゲームに入るまで未使用・未登録。UI担当は `lib/ui/surface_art.dart` で形状・明暗・反射を、共通担当は `lib/game/game.dart` の素材定義で段階ごとの色・汚れ・光沢を調整する。Androidの起動アイコンは `res/drawable/workshop_icon.xml` に同じ方位星を描いた。

## 筆の明朝（画面の文字）

画面の文字はすべて Yuji Syuku（筆の明朝）。`assets/fonts/yuji-syuku.ttf` は、2026-11-22に [Google Fonts の配布元](https://github.com/google/fonts/tree/main/ofl/yujisyuku) から取得した `YujiSyuku-Regular.ttf`（8.4MB）を、下の日本語ゴシックと同じ文字範囲（ASCII・かな・全角記号・`lib/` の全文字）へ固定SDKの `font-subset` でサブセット化したもの（約370KB）。Flutterの登録名は `YujiSyuku`、テーマの `appFont`。入っていない文字は日本語ゴシックで表示する。SIL Open Font License 1.1の本文と著作権表示を `assets/fonts/OFL-YujiSyuku.txt` に同梱し、アプリ内のライセンス一覧にも出す。文言を増やした場合は同じ方法で作り直す。太字はフォントにないため描画時に合成される。

## 日本語ゴシック

`assets/fonts/workshop-sans.ttf` はNoto Sans JPの可変フォントを2026-11-21にUI表示文字へサブセット化したもの。Flutterの登録名は `WorkshopSans`。画面・Canvasの字面に共用し、アプリ内に同梱する。SIL Open Font License 1.1の本文と著作権表示を `assets/fonts/OFL.txt` に同梱した。[配布元](https://github.com/google/fonts/tree/main/ofl/notosansjp)・[ライセンス](../assets/fonts/OFL.txt)

文言や題材の漢字を増やす場合は、配布元の `NotoSansJP[wght].ttf` と固定Flutter SDKの `font-subset` を使い、次で字形を再生成する。元TTFの初期版SHA-256は `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`。

```bash
python3 tool/subset_font.py /path/to/flutter/bin/cache/artifacts/engine/linux-x64/font-subset '/path/to/NotoSansJP[wght].ttf'
```

ホストが異なればバイナリのパスを変更する。新しい素材で初期・途中・確定画面を同じ進捗で確認する。新規画像や書体を加える際はUI担当が参照と出典・利用条件を用意し、共通担当が `pubspec.yaml` の登録を確認する。
