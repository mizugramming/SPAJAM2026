# 素材・日本語フォント

漢の研磨には3枚の透過画像を使い、往復時の削りかすと反射光を画面で重ねる。

## 画像

使用する画像は `pubspec.yaml` に1枚ずつ登録している。チームが自作（手描き・編集）したメダル4枚はファイル名の末尾が `.jpg` で、中身は透過PNG。研磨中はこの絵にゲームの研磨率に応じたサビと光沢、往復に応じた反射を重ねる。

| ファイル | 使う場所 |
|---|---|
| `assets/images/yansu_title.png` | ユーザー提供の全身画をもとに、内蔵ImageGenでヤンスの紙背景を透過。髪先、墨の輪郭、顔、黒い短パン、素足を残し、足の間も透明にした。工房に直接重ねるタイトル用PNG（576 × 888）。 |
| `assets/fonts/daou.jpg` | サビた銅メダル。素材選択カード、研磨のサビた銅・銅の段階 |
| `assets/fonts/gin.jpg` | 銀メダルの段階 |
| `assets/fonts/kin.jpg` | 金メダルの段階 |
| `assets/fonts/kinpika.jpg` | 研磨95%以上の金メダル |
| `assets/images/copper_medal_spin.webp` | 素材選択から採音画面へ移る緑青付き銅メダル。2026-11-22に提供された「緑青の銅メダル_立体回転_高精細_透過.mov」の正面から1回転（1.75秒）を24コマに抜き出した。各コマ320 px四方、6列×4行の透過WebP（1920×1280 px、約529 KiB）。 |
| `assets/images/workshop_room.webp` | 磨き屋の下地（852 × 1846）。奥に暗い壁、手前に奥行きのある木の天板を描いた。 |
| `assets/images/workshop_curtain.webp` | 朱と藍の波柄のれん。吊り輪の周囲と裾の隙間を透過。 |
| `assets/images/workshop_brush.webp` | 右柱の鋲から革ひもで吊るした磨き刷毛（249 × 512、透過）。鋲を支点に、毛先の影を画面描画で右へ落とす。 |
| `assets/images/workshop_tin.webp` | 天板に置く磨き粉の缶（512 × 337、透過）。蓋を浅い角度から描き、底から右へ続く影に木目が透ける。 |
| `assets/images/shavings.png` | メダル・漢の研磨中の削りかす（透過PNG）。2026-11-22にチームから受け取った1536×1024を512×341へ縮小。出典の詳細は未記録。押し引きの途中に出る粉の軌跡として使う |
| `assets/images/shards/` | 同じ削りかす画像の元サイズから切り出した赤茶4枚・青緑3枚の破片（周囲の薄い粉は透明化）。1往復が確定すると、やすりの目に応じた大きさ・数の破片を飛ばす。素材とその時点の仕上がりに合わせて削り粉・破片を着色する |

工房の4点は2026-11-22にユーザー提供のキャラクター画2点を参考に、本アプリ用に内蔵のImageGenで制作した。太い墨線、紙のかすれ、法被の波柄を取り入れた[最初の背景案](images/workshop-concept.webp)を見本に、下地は小物を除いて生成し、のれん・刷毛・缶はそれぞれ単体で生成した。

2026-11-22にチームから受け取った未使用の画像も同じ場所に置いている（出典の詳細は未記録）。`assets/fonts/kagami.jpg`（磨きすぎ用）、`assets/images/gyansu.jpg`、`assets/images/yansu.jpg` と `assets/images/shards/yansu.jpg` は未使用。アプリには使用中の画像だけを個別に登録する。

`assets/images/kanji_bronze.png` は「漢磨き」用の画像案（透過PNG、1254 × 1254）。2026-11-22にユーザーが提供した岩肌の「漢」をもとに、同梱のYuji Syukuの字形と銅メダルの質感を参照し、ImageGenで古銅色の地金と磨かれた稜線を表現した。ゲーム画面への組み込みは未実施。

`assets/images/kanji_stone.png` は同じ「漢」を石彫りにした画像案（透過PNG、1254 × 1254）。2026-11-22に上記の銅版とYuji Syukuの字形を参照し、ImageGenで灰色の安山岩の細かな粒、浅いノミ跡、つや消しの字面を表現した。ゲーム画面への組み込みは未実施。

`assets/images/kanji_rough_stone.png` は、上記の石彫りとYuji Syukuの「漢」を参照し、2026-11-22にImageGenで編集した透過PNG（1254 × 1254）。元絵のごつごつした岩肌に合わせ、画に厚みを持たせて大きな割れ面と深い起伏を付けた。ユーザー指定により、この絵を研磨前の姿に採用した。

「漢磨き」では以下の透過WebP（各896 × 896）を使用する。素材選択は荒面、研磨中と結果画面はゲームの研磨率に対応した画像を表示する。[3段階の比較画像](images/kanji-polish.webp)

| 研磨率 | 使用画像 | 制作時の指定 |
|---|---|---|
| 0%以上38%未満 | `assets/images/kanji_polish_rough.webp` | 指定の岩肌の原画を使用。大きな割れ面と凹凸を残す |
| 38%以上80%未満 | `assets/images/kanji_polish_satin.webp` | 岩肌と完成形を参照し、凸部にやすり目と鈍い銀色の反射を出す。側面と穴の内側には荒れを残す |
| 80%以上 | `assets/images/kanji_polish_gloss.webp` | 最初に提供された角張った「漢」の字形と厚みを保ち、滑らかな銀色の面に明暗が映り込む鏡面にする |

中間・仕上げの絵は2026-11-22に本アプリ向けに内蔵のImageGenで生成。3枚とも背景と字の穴を透過し、表示時の高さと中心をそろえた。

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
