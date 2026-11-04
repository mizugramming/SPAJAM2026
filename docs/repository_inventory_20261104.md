# ブランチ・PR整理結果（2026-11-04）

GitHubのブランチ・PR一覧とGitの履歴を照合した記録です。[普段の運用](repository_maintenance.md)とは分けて管理します。

最初の棚卸しは21ブランチ・未完了PR10件。整理用ブランチとPR #57の追加後は22ブランチ・11件となり、旧ブランチ14本・旧PR8件を整理しました。現在は **8ブランチ・未完了PR3件** です。

所有者の「test-1側の開発と、rehearsal/01・rehearsal/02・honbanを残して旧作業を削除する」方針に従っています。main、test-1、rehearsal/01、rehearsal/02、honbanの先端は変更していません。

## 保持しているブランチ（8本）

| ブランチ | 用途 | 開いているPR |
|---|---|---|
| `main` | 共通キット | — |
| `test-1` | まよいクエストの統合先 | — |
| `rehearsal/01` | 初回練習アプリの保管先 | — |
| `rehearsal/02` | 余白の統合先 | — |
| `honban` | つなぐんの統合先 | — |
| `nagisa` | 現在のアプリの開発中作業 | [#55](https://github.com/mizugramming/SPAJAM2026/pull/55) |
| `matsumoto/player-flow` | 現在のアプリの開発中作業・ドラフト | [#56](https://github.com/mizugramming/SPAJAM2026/pull/56) |
| `chore/repository-cleanup-20261104` | このリポジトリ整理の作業 | [#57](https://github.com/mizugramming/SPAJAM2026/pull/57) |

`nagisa`・`matsumoto/player-flow` はtest-1側の進行中作業です。整理用の `chore/repository-cleanup-20261104` はPR #57が残っているため保持しています。

## 削除した旧ブランチ（14本）

削除直前に先端がバックアップ時点から変わっていないことを確認しました。未統合のコミットを含むものも、削除前の履歴を復元用ファイルへ保存・検証したうえで整理しています。

| ブランチ | 削除前の先端コミット | 今回クローズしたPR |
|---|---|---|
| `docs/harden-development-handoff` | `57b6475911c0493a5711994f2a3049ca3cb144ed` | [#37](https://github.com/mizugramming/SPAJAM2026/pull/37) |
| `docs/honban-device-layout` | `8b79459c151cbce9fc70d7fa44d322eaa45f048d` | [#38](https://github.com/mizugramming/SPAJAM2026/pull/38) |
| `docs/reusable-development-rulebook` | `f3d274956ef0a6f267d7ab44411e8dab08d43070` | [#23](https://github.com/mizugramming/SPAJAM2026/pull/23) |
| `feature/practice-nagisa` | `c0802825f01c1b46ae70569a593d85990d6faab5` | — |
| `feature/screen4-mizuki` | `ec0353017880c58e6337aabb77c0015ce8de9abe` | — |
| `feature/space-constellation-nagisa` | `3ff879ddbab0e4484567f11c13912cfbd58a58e2` | [#35](https://github.com/mizugramming/SPAJAM2026/pull/35) |
| `feature/yohaku-constellation` | `1e7b705890526fab0c66196f0354eaeb9bca1305` | — |
| `feature/yohaku-home` | `3b43f884d5e4df4beb85bcb1600efe3ab0fc286a` | — |
| `feature/yohaku-space` | `a5ba6fcd8e1964b157a415b9c5a5e384cb34780b` | — |
| `feature/yohaku-space-rehearsal02` | `2c399c00b0f3825763c9ef626412be997316a214` | — |
| `feature/yohaku-space-relationship-icons` | `a5ba6fcd8e1964b157a415b9c5a5e384cb34780b` | [#32](https://github.com/mizugramming/SPAJAM2026/pull/32) |
| `feature/お寿司のとこ-nagisa` | `2c615495327953e1a2ac12e3017e3e6d986f8ff0` | — |
| `feature/プロフィール入力-松本吏功` | `a5ba6fcd8e1964b157a415b9c5a5e384cb34780b` | — |
| `fix/yohaku-home-analyze` | `b3d09fbb0632e2855d290062d6d9b86e7fb85d60` | — |

## PRの整理

- #9・#10・#54：main向けの旧アプリ・重複PRとして、理由と保存先・継続先を説明に記録してクローズ。
- #23・#32・#35・#37・#38：今回削除する旧作業に対応するため、説明に理由と削除前の先端を記録してクローズ。
- #55・#56・#57：進行中の作業として保持。

旧PRはマージせず閉じています。アプリコード、SDK、依存、CI、ブランチ保護、保持するブランチの履歴は変更していません。

## 復元用バックアップ

削除前の全履歴を `SPAJAM2026-before-branch-cleanup-20261104.bundle` に保存しました。`branch-cleanup-manifest-20261104.json` には保持・削除の対象と先端を記録しています。どちらも今回の作業で提供する復元用ファイルで、リポジトリのソースには追加していません。

- bundleの容量：77,480,006 bytes。
- SHA-256：`aabec523e2167dba3a857706478ea27bb05eea4f23dd11581ea78e6d023e4cb4`。
- `git bundle verify`：完全な履歴であることを確認。
- bundleからミラーを複製し、`git fsck --full` が成功。
- 削除直後のGitHub画面で、14本とも復元操作（Restore）が表示されることを確認。

bundleから復元する場合は、別の空の場所でミラーを作成します。対象名と上表のSHAを確認し、必要な1本だけを戻します。

```bash
git clone --mirror SPAJAM2026-before-branch-cleanup-20261104.bundle restore.git
git --git-dir=restore.git show-ref
# 対象名を元のブランチ名に置き換え、対象1本だけを復元する
git --git-dir=restore.git push https://github.com/mizugramming/SPAJAM2026.git refs/remotes/origin/対象名:refs/heads/対象名
```

整理前のリモート先端はbundleの `refs/remotes/origin/` 以下にあります。復元先に同名ブランチが存在する場合は、上書きせず現在の作業を確認してください。

## 以前の保存タグ

[`archive/yohaku-main-before-cleanup-20260919`](https://github.com/mizugramming/SPAJAM2026/tree/archive/yohaku-main-before-cleanup-20260919) も保持しています。
