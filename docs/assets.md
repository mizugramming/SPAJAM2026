# 素材・日本語フォント

漢の銘板、汚れ・粒子・反射光は本選用の自作描画。

## 画像

チームが自作（手描き・編集）した画像。2026-11-22に追加。`pubspec.yaml` に1枚ずつ登録している。

| ファイル | 使う場所 |
|---|---|
| `assets/fonts/daou.jpg` | サビた銅メダル。タイトル、素材選択カード、研磨のサビた銅・銅の段階 |
| `assets/fonts/gin.jpg` | 銀メダルの段階 |
| `assets/fonts/kin.jpg` | 金メダルの段階 |
| `assets/fonts/kinpika.jpg` | 研磨95%以上の金メダル |
| `assets/images/background.jpg` | タイトル・素材選択・研磨などの全画面の背景 |

メダル画像は1枚2MB前後あり、表示時は `cacheWidth` で縮小して読み込む。容量を減らす場合は縮小した画像に差し替える。磨きすぎ用の `kagami.jpg` は、磨きすぎの判定がゲームに入るまで未使用・未登録。UI担当は `lib/ui/surface_art.dart` で形状・明暗・反射を、共通担当は `lib/game/game.dart` の素材定義で段階ごとの色・汚れ・光沢を調整する。Androidの起動アイコンは `res/drawable/workshop_icon.xml` に同じ方位星を描いた。

## 日本語ゴシック

`assets/fonts/workshop-sans.ttf` はNoto Sans JPの可変フォントを2026-11-21にUI表示文字へサブセット化したもの。Flutterの登録名は `WorkshopSans`。画面・Canvasの字面に共用し、アプリ内に同梱する。SIL Open Font License 1.1の本文と著作権表示を `assets/fonts/OFL.txt` に同梱した。[配布元](https://github.com/google/fonts/tree/main/ofl/notosansjp)・[ライセンス](../assets/fonts/OFL.txt)

文言や題材の漢字を増やす場合は、配布元の `NotoSansJP[wght].ttf` と固定Flutter SDKの `font-subset` を使い、次で字形を再生成する。元TTFの初期版SHA-256は `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`。

```bash
python3 tool/subset_font.py /path/to/flutter/bin/cache/artifacts/engine/linux-x64/font-subset '/path/to/NotoSansJP[wght].ttf'
```

ホストが異なればバイナリのパスを変更する。新しい素材で初期・途中・確定画面を同じ進捗で確認する。新規画像や書体を加える際はUI担当が参照と出典・利用条件を用意し、共通担当が `pubspec.yaml` の登録を確認する。
