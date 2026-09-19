# 画像・素材を追加する

各担当が自分の素材フォルダへ追加します。登録済みフォルダの直下なら `pubspec.yaml` を編集せずに使えるため、画像追加のたびに共通ファイルで競合することを避けられます。

| 担当 | 追加先 | 出典記録 |
|---|---|---|
| ホーム | `assets/home/` | `docs/asset_sources/home.md` |
| SPACE・星の演出 | `assets/space/`, `assets/star/` | `docs/asset_sources/space.md` |
| 今日の星座 | `assets/constellation/` | `docs/asset_sources/constellation.md` |
| 宇宙 | `assets/universe/` | `docs/asset_sources/universe.md` |
| 振り返り | `assets/history/` | `docs/asset_sources/history.md` |
| 全画面共通 | `assets/common/`（統合担当） | [既存素材の記録](assets.md) |

出典ファイルは最初の素材追加時に作成します。[記載例](asset_sources/README.md)を使ってください。

## 例：宇宙に惑星を追加する

1. `assets/universe/planet_challenge.png` に保存する。小文字の英数字とアンダースコアを使い、既存ファイルと同名にしない。
2. 宇宙の担当ソースから相対的なアセットキーで参照する。

   ```dart
   Image.asset(
     'assets/universe/planet_challenge.png',
     fit: BoxFit.contain,
   )
   ```

3. `docs/asset_sources/universe.md` に出典・利用条件・加工内容を記録する。AI生成ならツール、日付、参考素材、再生成に必要なプロンプトも記録する。
4. アプリを停止して再実行し、画像が表示されることと縦横比・透明背景・文字との重なりを確認する。ホットリロードだけでは追加が反映されない場合がある。
5. 素材本体・参照するソース・出典記録を同じPRへ含め、通常の共有前チェックを実行する。

たとえば `git add assets/universe/planet_challenge.png docs/asset_sources/universe.md` に加え、変更したソースを個別に指定してステージします。`git status --short` で画像の入れ忘れも確認してください。

## 共通設定の変更が必要な場合

- `assets/universe/planets/` のような新しいサブフォルダは、親を登録済みでも自動では含まれません。統合担当が `pubspec.yaml` にそのフォルダを追加します。通常の画像は既存フォルダ直下で足ります。
- `2.0x/`、`3.0x/` の解像度別画像は例外です。基準画像と同名で配置し、基準画像のキーで参照します。
- PNG・JPEG・WebPなど、既存の画像表示で扱える形式を使います。SVGはそのまま `Image.asset` で表示できません。対応ライブラリ追加が必要なら統合担当へ相談します。
- フォント・アプリアイコン・スプラッシュ画面は通常画像と設定方法が異なります。プラットフォーム設定も関係するため統合担当が扱います。

登録と対応形式の根拠は[Flutter公式のアセットガイド](https://docs.flutter.dev/ui/assets/assets-and-images)を参照してください。

## 差し替えと競合

別担当の画像や `assets/common/` は勝手に置き換えません。同じ画像を2人で差し替えた場合は、双方を確認して採用するものを決めるか、別名で残して用途を分けます。削除・移動の前には `rg` で旧パスやファイル名の利用箇所を確認します。動的に組み立てているパスも確認してください。

端末で必要な解像度と容量に合わせて書き出します。PSDなどの編集用原本や巨大な連番画像を無条件にGitへ入れません。大きな素材を継続管理する必要があれば、保存方法を統合担当と決めます。

CIのビルド成功だけでは、文字列で指定した全画像パスの存在や表示崩れまでは保証できません。PRには表示を確認した画面・実行環境を記載してください。未確認の実機は確認済みとしません。
