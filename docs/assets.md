# 素材・日本語フォント

漢の研磨には、くすんだ銀文字と磨いた銀文字の透過画像を使う。

## Androidの起動アイコン

タイトル用のヤンスを参照して、2026-11-22に本アプリ用の顔の絵をImageGenで制作した。磨かれ屋の藍色（#414F59）に、磨いた金属を表す金の光を右のこめかみに添えた。[アイコンのPNG（512×512）](images/yansu-launcher-icon.png)

Androidのリソースは `android/app/src/main/res/` にある。Android 8以降は `drawable-xxxhdpi/yansu_icon_foreground.png` と背景色を端末のマスクで表示する。Android 13以降の対応ランチャーでテーマアイコンを選ぶと `drawable/yansu_icon_monochrome.xml` を使う。Android 7では `mipmap-*/ic_launcher.png` を画面密度に合わせて使う。

## 画像

使用する画像は `pubspec.yaml` に1枚ずつ登録している。チームが自作（手描き・編集）したメダル4枚はファイル名の末尾が `.jpg` で、中身は透過PNG。研磨中はこの絵にゲームの研磨率に応じたサビと光沢、往復に応じた反射を重ねる。

| ファイル | 使う場所 |
|---|---|
| `assets/images/yansu_title.png` | ユーザー提供の全身画をもとに、内蔵ImageGenでヤンスの紙背景を透過。髪先、墨の輪郭、顔、黒い短パン、素足を残し、足の間も透明にした。工房に直接重ねるタイトル用PNG（576 × 888）。 |
| `assets/fonts/daou.jpg` | サビた銅メダル。素材選択カード、研磨のサビた銅・銅の段階 |
| `assets/fonts/gin.jpg` | 銀メダルの段階 |
| `assets/fonts/kin.jpg` | 旧・金メダルの絵（今は画面から参照していない） |
| `assets/images/medal-gold.png` | 金メダルの段階（つや消し・文字なし）。2026-11-22にチームが用意した「金ピカ.png」を英字名に変更 |
| `assets/images/medal-gold-polishing.png` | 金ピカの段階（上の方が曇った磨き途中）。同日に用意した「途中の金ピカ.png」を英字名に変更。金からは研磨量に応じてこの絵を重ねる |
| `assets/fonts/kinpika.jpg` | 仕上げたメダル上部の箔をスクラッチした跡から見える「最優秀賞」入りの絵 |
| `assets/images/kanji-silver.png` | 漢磨きの素材選択・採音・研磨で出す銀の立体文字「漢」（くすんだ絵、透過PNG）。2026-11-22にチームが用意した「透明背景の銀色立体漢字「漢」-1.png」を英字名に変更 |
| `assets/images/kanji-silver-polished.png` | 同じ文字の磨き上がった絵。同日の「透明背景の銀色立体漢字 漢-2.png」を英字名に変更。元の絵（未登録）。文字の位置と大きさが `kanji-silver.png` と少しずれていたため、そろえた `kanji-silver-polished-aligned.png` を研磨の割合だけ上に重ねて、磨くほどこの絵になる |
| `assets/images/character-02/04/05.png`、`gyansu.jpg`、`kyushu-danji.png`、`overpolished-01〜05.png` | 動きを減らす設定で成功時に使う静止キャラクター（合計点と対応は app_design.md）。overpolished系は以前の失敗用素材。2026-11-22にチームから受け取った。`kyushu-danji.png` は「九州男児.png」を英字名に変更 |
| `assets/images/kanji-rank-1〜5.png` | 漢磨きの結果画面の段位の「漢」（1漢は赤、2漢は金など段位ごとの色）。2026-11-22にチームから受け取った「１漢.jpg」〜「５漢.jpg」の白背景を透明にしたもの |
| `assets/images/kanji-break.webp` | 削りすぎた時点のやすりの合計が9点なら、この5コマで割れる。チーム提供の「漢-黄色-割れ.png」の赤い破片と既存の1漢を使った透過5コマ（1コマ384×384）。上限を超えるとひびが伸び、破片が離れて止まる。[同じ5コマの動画](media/kanji-break.mp4) |
| `assets/images/kanji-crack-2〜5-before.webp`、`kanji-crack-2〜5-after.webp`、`kanji-crack-2〜5-left/right.webp` | 削りすぎ（失敗）のときに段位の「漢」が割れるコマ送り。2026-11-22にチームから受け取った「N漢割れ前.jpg」「N漢割.jpg」の白背景を透明にし、割れる前の絵をひびの左右に切り分けた。配信用の4コマは透過と原寸を保った可逆WebP。1漢は上記の5コマを使用 |
| `assets/images/character-success-1〜5.webp` | 漢磨きの成功時のキャラクター（動くWebP、12コマ/秒のループ）。2026-11-22にチームから受け取った「１.mp4」〜「５.mp4」から、枠につながる明るい背景を透明にして変換。動画再生のパッケージは追加していない |
| `assets/images/workshop-title-01〜05.png` | 漢磨きの結果画面の称号（01 九州男児、02 醤油顔、03 ムキムキ、04 塩顔、05 韓国系、透過PNG）。2026-11-22にチームから受け取った |
| `assets/images/character-under.webp` | 漢磨きの磨き不足のキャラクター（動くWebP）。動きを減らす設定では、先頭フレームを同じ大きさで保存した `character-under-still.webp` を表示する。2026-11-22にチームから受け取った「キャラクター_毛先補完_背景透過.mp4」から、枠につながる黒い背景を透明にして変換 |
| `assets/images/kanji-rock.png` | 灰色の岩（透過PNG）。素材選択の漢の絵に一時使ったが、今は未使用・未登録 |
| `assets/images/copper_medal_spin.webp` | 素材選択から採音画面へ移る緑青付き銅メダル。2026-11-22に提供された「緑青の銅メダル_立体回転_高精細_透過.mov」の正面から1回転（1.75秒）を24コマに抜き出した。各コマ320 px四方、6列×4行の透過WebP（1920×1280 px、約529 KiB）。 |
| `assets/images/workshop_room.webp` | 「磨かれ屋」の奥の店内（852 × 1846）。灰褐色の漆喰壁、左の二段棚、右の木柱、足元の床を描いた。本とダンベルは別素材で棚板に載せる。 |
| `assets/images/workshop_counter.webp` | ヤンスの手前に重ねる接客カウンター（852 × 542）。天板の奥縁を画面いっぱいに通し、短パンの上端だけを見せる。上端だけを透過し、前板を画面下まで描いた。 |
| `assets/images/workshop_curtain.webp` | 「磨かれ屋」と染め抜いた柿朱・藍の波柄のれん（1080 × 322）。吊り輪の周囲と裾の隙間を透過。 |
| `assets/images/workshop_brush.webp` | 天板に横たえた磨き刷毛（512 × 187、透過）。毛先を手前に向け、革ひもが天板の上でたるむ。 |
| `assets/images/workshop_jacket.webp` | 参考画の右端の人物と同じ、袖を折った藍色のデニムジャケット。ハンガーのフックを右柱に掛ける。 |
| `assets/images/workshop_cloth.webp` | ワックスの下に敷く藍布。折り返しと生成りの縫い目がある。 |
| `assets/images/workshop_books.webp` | 赤茶と苔色の布張りの本を2冊重ね、朱のしおりを挟んだ。 |
| `assets/images/workshop_dumbbell.webp` | 天板に横置きする鉄製ダンベル。くすんだ青灰色の面で重さを表現した。 |
| `assets/images/workshop_wax.webp` | 赤茶のヘアワックス容器と藍色の蓋。生成りのワックスに指ですくった跡を入れた。 |
| `assets/images/shavings.png` | メダル・漢の研磨中の削りかす（透過PNG）。2026-11-22にチームから受け取った1536×1024を512×341へ縮小。出典の詳細は未記録。押し引きの途中に出る粉の軌跡として使う |
| `assets/images/shards/` | 同じ削りかす画像の元サイズから切り出した赤茶4枚・青緑3枚の破片（周囲の薄い粉は透明化）。1往復が確定すると、やすりの目に応じた大きさ・数の破片を飛ばす。素材とその時点の仕上がりに合わせて削り粉・破片を着色する |

2026-11-22にチームから受け取った未使用の画像も同じ場所に置いている（出典の詳細は未記録）。`assets/fonts/kagami.jpg`（磨きすぎ用）、`assets/images/yansu.jpg` と `assets/images/shards/yansu.jpg` は未使用。アプリには使用中の画像だけを個別に登録する。

店と小物の9枚は2026-11-22にユーザー提供のキャラクター画を参照して、本アプリ用に内蔵ImageGenで制作した。今回の生成指定は「中央が空いた昭和の商店、左の小さな二段棚」「画面の端まで続く木の接客台」「二枚目の朱の布に『磨かれ屋』」「天板に毛先を手前にして寝かせた刷毛」。各素材はヤンスの墨の輪郭、紙の粒、つやを抑えた色面に合わせた。位置と表示寸法は `lib/ui/workshop_layout.dart` に画面ごとに保存する。[最初の背景案](images/workshop-concept.webp)

`assets/images/kanji_bronze.png` は「漢磨き」用の画像案（透過PNG、1254 × 1254）。2026-11-22にユーザーが提供した岩肌の「漢」をもとに、同梱のYuji Syukuの字形と銅メダルの質感を参照し、ImageGenで古銅色の地金と磨かれた稜線を表現した。ゲーム画面への組み込みは未実施。

`assets/images/kanji_stone.png` は同じ「漢」を石彫りにした画像案（透過PNG、1254 × 1254）。2026-11-22に上記の銅版とYuji Syukuの字形を参照し、ImageGenで灰色の安山岩の細かな粒、浅いノミ跡、つや消しの字面を表現した。ゲーム画面への組み込みは未実施。

`assets/images/kanji_rough_stone.png` は、上記の石彫りとYuji Syukuの「漢」を参照し、2026-11-22にImageGenで編集した透過PNG（1254 × 1254）。元絵のごつごつした岩肌に合わせ、画に厚みを持たせて大きな割れ面と深い起伏を付けた。岩肌を用いた初期案の研磨前の姿。

岩肌から銀に移る初期案は、以下の透過WebP（各896 × 896）として保管している。[3段階の比較画像](images/kanji-polish.webp)

| 研磨率 | 使用画像 | 制作時の指定 |
|---|---|---|
| 0%以上38%未満 | `assets/images/kanji_polish_rough.webp` | 指定の岩肌の原画を使用。大きな割れ面と凹凸を残す |
| 38%以上80%未満 | `assets/images/kanji_polish_satin.webp` | 岩肌と完成形を参照し、凸部にやすり目と鈍い銀色の反射を出す。側面と穴の内側には荒れを残す |
| 80%以上 | `assets/images/kanji_polish_gloss.webp` | 最初に提供された角張った「漢」の字形と厚みを保ち、滑らかな銀色の面に明暗が映り込む鏡面にする |

中間・仕上げの絵は2026-11-22に本アプリ向けに内蔵のImageGenで生成。3枚とも背景と字の穴を透過し、表示時の高さと中心をそろえた。

紙やすりの質感には、2026-11-22にユーザーが本アプリ用に提供した無地の紙の画像を使用。透明な余白を詰めた `assets/images/sandpaper_plain.webp`（1320 × 785、約114 KiB）を同梱した。紙の端の繊維と右上の折れは原画のもの。2枚目の画像にある斜めの印字を参考に、`lib/ui/sandpaper.dart` で各ラウンドの測定値を重ねる。紙色を調整する入口は `sandpaperColorFor`、印字は `sandpaperStampFor`。

メダル画像は1枚2MB前後あり、表示時は `cacheWidth` で縮小して読み込む。容量を減らす場合は縮小した画像に差し替える。磨きすぎ用の `kagami.jpg` は、磨きすぎの判定がゲームに入るまで未使用・未登録。UI担当は `lib/ui/surface_art.dart` で形状・明暗・反射を、共通担当は `lib/game/game.dart` の素材定義で段階ごとの色・汚れ・光沢を調整する。

## 筆の明朝（画面の文字）

画面の文字はすべて Yuji Syuku（筆の明朝）。`assets/fonts/yuji-syuku.ttf` は、2026-11-22に [Google Fonts の配布元](https://github.com/google/fonts/tree/main/ofl/yujisyuku) から取得した `YujiSyuku-Regular.ttf`（8.4MB）を、下の日本語ゴシックと同じ文字範囲（ASCII・かな・全角記号・`lib/` の全文字）へ固定SDKの `font-subset` でサブセット化したもの（約370KB）。Flutterの登録名は `YujiSyuku`、テーマの `appFont`。入っていない文字は日本語ゴシックで表示する。SIL Open Font License 1.1の本文と著作権表示を `assets/fonts/OFL-YujiSyuku.txt` に同梱し、アプリ内のライセンス一覧にも出す。文言を増やした場合は同じ方法で作り直す。太字はフォントにないため描画時に合成される。

## 日本語ゴシック

`assets/fonts/workshop-sans.ttf` はNoto Sans JPの可変フォントを2026-11-21にUI表示文字へサブセット化したもの。Flutterの登録名は `WorkshopSans`。画面・Canvasの字面に共用し、アプリ内に同梱する。SIL Open Font License 1.1の本文と著作権表示を `assets/fonts/OFL.txt` に同梱した。[配布元](https://github.com/google/fonts/tree/main/ofl/notosansjp)・[ライセンス](../assets/fonts/OFL.txt)

文言や題材の漢字を増やす場合は、配布元の `NotoSansJP[wght].ttf` と固定Flutter SDKの `font-subset` を使い、次で字形を再生成する。元TTFの初期版SHA-256は `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`。

```bash
python3 tool/subset_font.py /path/to/flutter/bin/cache/artifacts/engine/linux-x64/font-subset '/path/to/NotoSansJP[wght].ttf'
```

ホストが異なればバイナリのパスを変更する。新しい素材で初期・途中・確定画面を同じ進捗で確認する。新規画像や書体を加える際はUI担当が参照と出典・利用条件を用意し、共通担当が `pubspec.yaml` の登録を確認する。
