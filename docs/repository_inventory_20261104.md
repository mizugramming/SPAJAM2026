# ブランチ・PR棚卸し（2026-11-04）

GitHubのブランチ・PR一覧、各ブランチのREADME、Gitの履歴を照合した記録です。[普段の運用](repository_maintenance.md)と分け、確認後の更新を現在の状態と混同しないようにします。

整理開始時点は21ブランチ・未完了PR10件。以下は整理作業用ブランチを除く一覧です。アプリコード・SDK・依存・CI設定・保護設定・共有履歴は変更対象に含めません。

PR #9・#10・#54は、説明に理由と保存先・継続先を記録してマージせずクローズ済みです。既存の未完了PRは7件になりました（整理内容を提案する新規PRを除く）。

## 統合先・保管先（5本）

| ブランチ | 内容 | 確認時の先端 |
|---|---|---|
| `main` | 共通キット | `637c514df715` |
| `test-1` | まよいクエスト。現在の開発先 | `e3bed5c14d88` |
| `honban` | つなぐん | `b26910aa3b24` |
| `rehearsal/02` | 余白 | `209275626360` |
| `rehearsal/01` | 初回練習アプリ | `0f47895dcc90` |

## 現在のアプリの作業（2本）

| ブランチ | 継続先 | 確認時の先端 |
|---|---|---|
| `nagisa` | [PR #55](https://github.com/mizugramming/SPAJAM2026/pull/55) → `test-1` | `da3bfe559f0c` |
| `matsumoto/player-flow` | [PR #56](https://github.com/mizugramming/SPAJAM2026/pull/56) → `test-1`。ドラフト、共通APIへの追従待ち | `186b1d20f59a` |

## 判断・レビューを残す作業（5本）

| ブランチ | PR先 | 保持する理由 | 確認時の先端 |
|---|---|---|---|
| `docs/harden-development-handoff` | [#37](https://github.com/mizugramming/SPAJAM2026/pull/37) → `main` | 履歴はhonbanに含まれるが、main向けの共通キット変更は未統合 | `57b6475911c0` |
| `docs/honban-device-layout` | [#38](https://github.com/mizugramming/SPAJAM2026/pull/38) → `honban` | 統合先に含まれないコミットがある | `8b79459c151c` |
| `docs/reusable-development-rulebook` | [#23](https://github.com/mizugramming/SPAJAM2026/pull/23) → `rehearsal/02` | 統合先に含まれないコミットがある | `f3d274956ef0` |
| `feature/space-constellation-nagisa` | [#35](https://github.com/mizugramming/SPAJAM2026/pull/35) → `main`（要見直し） | #36の統合後にも未統合コミット5件。mainへはアプリを入れず、余白側の差分・接続をレビューする | `3ff879ddbab0` |
| `feature/yohaku-space-relationship-icons` | [#32](https://github.com/mizugramming/SPAJAM2026/pull/32) → `rehearsal/02` | 先端はrehearsal/01に含まれるが、PR先への差分は残る。名前だけで統合済みと判断しない | `a5ba6fcd8e19` |

#37もこの運用資料を変更するため、先に統合されたPRの内容を後続側で取り込み、案内を再確認します。

## 統合先に履歴が含まれる作業（6本）

以下は削除候補です。リモートからは削除していません。継続利用の有無と最新の先端を確認してから扱います。

| ブランチ | 先端まで含む保存先 | 確認時の先端 |
|---|---|---|
| `feature/yohaku-constellation` | `rehearsal/02` | `1e7b70589052` |
| `feature/yohaku-home` | `rehearsal/02` | `3b43f884d5e4` |
| `feature/yohaku-space` | `rehearsal/01` | `a5ba6fcd8e19` |
| `feature/yohaku-space-rehearsal02` | `rehearsal/02`（#33で統合） | `2c399c00b0f3` |
| `feature/お寿司のとこ-nagisa` | `rehearsal/01` | `2c6154953279` |
| `feature/プロフィール入力-松本吏功` | `rehearsal/01`。main向け#10はクローズ済み | `a5ba6fcd8e19` |

## 未統合のコミットがある旧作業（3本）

5本の統合先・保管先すべてを対象に `git rev-list 作業ブランチ --not 統合先...` で数えています。履歴に含まれないことを示す値で、同じ内容が別コミットで反映されているかまでは断定しません。

| ブランチ | 統合先・保管先に含まれないコミット数 | 確認時の先端 |
|---|---|---|
| `feature/practice-nagisa` | 1 | `c0802825f01c` |
| `feature/screen4-mizuki` | 2 | `ec0353017880` |
| `fix/yohaku-home-analyze` | 1 | `b3d09fbb0632` |

マージ済みPRの名前に似ていても、未統合の先端を消さないため保持します。

## クローズしたPR（3件）

| PR | 整理理由 | 継続先・保存先 |
|---|---|---|
| [#54](https://github.com/mizugramming/SPAJAM2026/pull/54) | #55と同じ `nagisa` の先端をmainへ送っている重複PR | 正しい宛先 `test-1` の[#55](https://github.com/mizugramming/SPAJAM2026/pull/55)を継続 |
| [#10](https://github.com/mizugramming/SPAJAM2026/pull/10) | 旧プロフィール画面を共通キットのmainへ送っている | 先端 `a5ba6fcd8e19` は `rehearsal/01` に含まれる。作業ブランチも保持 |
| [#9](https://github.com/mizugramming/SPAJAM2026/pull/9) | 旧練習アプリ全体を共通キットのmainへ送っている | `rehearsal/01` の先端 `0f47895dcc90` をそのまま保持 |

3件ともマージせず閉じ、コード・ブランチを保持しています。未統合の変更があるPRや、正しい宛先の作業PRは保持しています。

## 以前の保存タグ

[`archive/yohaku-main-before-cleanup-20260919`](https://github.com/mizugramming/SPAJAM2026/tree/archive/yohaku-main-before-cleanup-20260919) を保持しています。今回の棚卸しでも履歴の書き換え・ブランチ先端の移動は行いません。
