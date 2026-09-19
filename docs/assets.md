# 素材と生成記録

## 夜空の背景

- 保存先：`assets/common/night_sky.png`
- 生成：内蔵 `image_gen`（imagegenスキル、CLI / 外部APIキー不使用）
- 用途：アプリ共通背景、SPACEの停止・星生成画面
- 日付：2026-09-19
- 参考：ユーザーから提供された「余白」の画面イメージ。UIそのものはFlutterで実装。

最終プロンプト：

```text
Use case: illustration-story. Asset type: portrait background artwork for a Japanese reflective journaling Flutter app called Yohaku. Generate a polished vertical 1024x1536 atmospheric digital painting, no text, no UI, no device frame. Deep midnight navy starry sky taking upper 80 percent of image, faint Milky Way dust with restrained blue violet nebula, small scattered soft stars, lower 20 percent dusky lavender and peach clouds at distant horizon with dark mountain silhouettes. At bottom right a very small back-view silhouette of a seated young adult and a cat watching the sky, serene and quiet, not dominant. Upper and central areas must be dark clean negative space for readable app UI overlay. Dreamy storybook realism, fine painterly texture, soft starlight, cinematic restrained glow. Colors navy #080f24, dusty purple, pale warm gold. Avoid large bright stars in center, avoid lettering, logos, grids, planets, buttons, cards and any text. Output is a reusable standalone art background.
```

## フォント

- [Noto Sans JP（Google Fonts公式）](https://github.com/google/fonts/tree/main/ofl/notosansjp) — SIL Open Font License 1.1。原版のvariable TTFを同梱。
- [Roboto（Google Fonts公式）](https://github.com/google/fonts/tree/main/ofl/roboto) — SIL Open Font License 1.1。Flutter Webの既定フォントをローカルで解決するため同梱。

フォントや背景の表示に外部CDNは必要ありません。Web版は `--no-web-resources-cdn` でビルドしてください。
