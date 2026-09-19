# 「余白」アプリ 共同開発手順

## 1. 初回準備

```bash
cd SPAJAM2026
git fetch origin
git switch rehearsal/02
git pull --ff-only origin rehearsal/02
flutter pub get
```

### ホーム担当

```bash
git switch -c feature/yohaku-home
git push -u origin feature/yohaku-home
```

### SPACE担当

```bash
git switch -c feature/yohaku-space
git push -u origin feature/yohaku-space
```

### 今日の星座担当

```bash
git switch -c feature/yohaku-constellation
git push -u origin feature/yohaku-constellation
```

### 宇宙・振り返り担当

```bash
git switch -c feature/yohaku-universe-history
git push -u origin feature/yohaku-universe-history
```

ここから担当機能の実装を開始してください。

```bash
flutter run
```

---

## 2. 2回目以降の作業開始

```bash
cd SPAJAM2026
git switch 自分のブランチ名
git pull --ff-only
git fetch origin
git merge origin/rehearsal/02
flutter pub get
flutter run
```

ブランチ名は次のとおりです。

| 担当 | ブランチ |
|---|---|
| ホーム | `feature/yohaku-home` |
| SPACE | `feature/yohaku-space` |
| 今日の星座 | `feature/yohaku-constellation` |
| 宇宙・振り返り | `feature/yohaku-universe-history` |

---

## 3. 作業終了後

```bash
flutter analyze
flutter test
git status
```

### ホーム担当

```bash
dart format lib/features/home
git add lib/features/home
git add assets/home test/features/home
git diff --staged
git commit -m "feat(home): implement home screen"
git push
gh pr create --base rehearsal/02 --head feature/yohaku-home --fill
gh pr view --web
gh pr merge feature/yohaku-home --merge
```

### SPACE担当

```bash
dart format lib/features/space
git add lib/features/space
git add assets/space test/features/space
git diff --staged
git commit -m "feat(space): implement space recording flow"
git push
gh pr create --base rehearsal/02 --head feature/yohaku-space --fill
gh pr view --web
gh pr merge feature/yohaku-space --merge
```

### 今日の星座担当

```bash
dart format lib/features/constellation
git add lib/features/constellation
git add assets/constellation test/features/constellation
git diff --staged
git commit -m "feat(constellation): implement daily constellation"
git push
gh pr create --base rehearsal/02 --head feature/yohaku-constellation --fill
gh pr view --web
gh pr merge feature/yohaku-constellation --merge
```

### 宇宙・振り返り担当

```bash
dart format lib/features/universe lib/features/history
git add lib/features/universe lib/features/history
git add assets/universe assets/history
git add test/features/universe test/features/history
git diff --staged
git commit -m "feat(universe-history): implement universe and history"
git push
gh pr create --base rehearsal/02 --head feature/yohaku-universe-history --fill
gh pr view --web
gh pr merge feature/yohaku-universe-history --merge
```

---

## 4. マージ後

```bash
git switch rehearsal/02
git pull --ff-only origin rehearsal/02
flutter pub get
flutter analyze
flutter test
flutter run
```

---

## 注意

- `main`と`rehearsal/02`では直接作業しない
- `git add .`は使用しない
- コンフリクトやエラーがある場合はマージしない
- `lib/app/`、`lib/core/`、`pubspec.yaml`を変更する場合は事前に共有する
