# 素材管理

| 素材 | アプリ側の配置 | 出典・用途 |
|---|---|---|
| 親分 | `assets/characters/oyabun.png` | ユーザー提供のv2原画。親分は常にこの通常の姿 |
| 普通の子分 | `assets/characters/kobun_normal.png` | ユーザー提供のv2原画 |
| 骨の子分 | `assets/characters/kobun_bone.png` | ユーザー提供のv2原画。「ショBONE」は骨子分の表現 |
| 対戦の吊られた魚（赤・青） | `assets/characters/hikareruaka.png`・`hikareruao.png` | ユーザー提供。対戦ゲームで自分・相手のチーム色の魚として使用 |
| ゲームの背景（海と砂地） | `assets/characters/tunaumi1.png`・`tunaumi2.png` | ユーザー提供。2枚を交互に重ねて砂地をゆらす。対戦・協力で共用 |
| 協力の魂 | `assets/characters/tamashii.png` | ユーザー提供。協力ゲームで運ぶ魂 |
| 協力のツナ缶・空き缶 | `assets/characters/tunakanaka.png`・`hadakan.png` | ユーザー提供。魂を運ぶ缶と、最後に魂が入る空き缶 |
| 手書きラフ・旧生成画像 | `docs/tsunagun/references/` | 設計の参照用。アプリへ全量同梱しない |

提供資料の原本は [v2資料](tsunagun/README.md) と [出典一覧](tsunagun/references/SOURCE_INDEX.md) に保持します。原画は白背景のままで、透過処理や再生成はしていません。アプリは `assets/characters/` のファイルを使用します。

缶はコードで描画する暫定表現です。最終イラスト・配色は未確定です。旧画像のメンバー・タブ・ゲーム等を、素材に描かれているという理由で機能へ戻しません。

画像追加時は担当フォルダへ置き、参照するソースと同じPRに含めます。`pubspec.yaml` の登録変更は共通管理です。元画像の権利・配布条件の記録が必要なら提供者に確認し、確認していないライセンスを推測で記載しません。
