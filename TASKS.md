# TASKS.md — 4人分担タスク指示書

このファイルは、4人の担当者がそれぞれ自分のAIエージェント(Claude Code等)に**そのままコピペして渡す**ための指示文です。担当ごとにセクションが分かれているので、自分の担当箇所だけをコピーして使ってください。

前提として、`AGENTS.md`(このリポジトリの設計書)と `rehearsal/01` ブランチ上に、Phase 0の共通基盤(モデル・サービス・Provider・5画面の雛形)がすでに実装済みです。ここから4人が並行して各担当を深掘りします。

---

## 担当1: Room(部屋作成・参加) 向け指示

あなたはSPAJAMハッカソンで開発中のFlutterアプリ「会輪(kaiwa)」の開発を手伝うAIエージェントです。

**これは共同開発プロジェクトです。** 4人が同時に、それぞれ別の担当領域を並行して実装しています。あなたが担当するのは「Room(部屋作成・参加)」機能だけです。他の3人は同時に「Profile」「Conversation」「Result」を触っているので、**担当外のファイル、特に `lib/main.dart` / `lib/app.dart` / `pubspec.yaml` / `lib/models/` / `lib/services/` などの共通ファイルは、勝手に変更しないでください。** 変更が必要になった場合は、まずユーザーに相談してください。

### まず読むこと
- `AGENTS.md`(プロジェクト全体の設計書)
- `lib/features/room/room_screen.dart`
- `lib/providers/room_provider.dart`
- `lib/services/room_service.dart` / `lib/services/mock_room_service.dart`(読むだけ。変更が必要なら要相談)

### 担当ファイル
- `lib/features/room/room_screen.dart`
- `lib/providers/room_provider.dart`

### 現状
予定人数(3/4/5/6人)を選ぶか部屋番号を入力し、`ProfileInputScreen` へ画面遷移する。実際の部屋作成/参加処理(`RoomService`呼び出し)はプロフィール入力画面側で行っている。

### やること
- 部屋が満員・存在しない・すでに開始済みの場合のエラー表示を分かりやすくする(`RoomNotFoundException` / `RoomFullException` / `RoomAlreadyStartedException` を判別してメッセージを出し分ける。現状は `profile_input_screen.dart` 側で汎用エラーメッセージのみ)
- 部屋番号の入力UX改善(コピー機能、文字数バリデーションなど)
- 見た目の作り込み

### Done条件
予定人数選択→Room作成→ID表示、ID入力で参加、満員/存在しない/開始済みRoomのエラーがそれぞれ分かりやすく表示される。

### 作業の始め方
```
git switch rehearsal/01
git pull origin rehearsal/01
git switch -c feature/room-自分の名前
```
作業が終わったら `rehearsal/01` に向けてPull Requestを出してください(`main` ではありません)。

---

## 担当2: Profile(プロフィール入力・待機画面) 向け指示

あなたはSPAJAMハッカソンで開発中のFlutterアプリ「会輪(kaiwa)」の開発を手伝うAIエージェントです。

**これは共同開発プロジェクトです。** 4人が同時に、それぞれ別の担当領域を並行して実装しています。あなたが担当するのは「Profile(プロフィール入力・待機画面)」機能だけです。他の3人は同時に「Room」「Conversation」「Result」を触っているので、**担当外のファイル、特に `lib/main.dart` / `lib/app.dart` / `pubspec.yaml` / `lib/models/` / `lib/services/` などの共通ファイルは、勝手に変更しないでください。** 変更が必要になった場合は、まずユーザーに相談してください。

### まず読むこと
- `AGENTS.md`(プロジェクト全体の設計書)
- `lib/features/profile/profile_input_screen.dart`
- `lib/features/profile/waiting_room_screen.dart`
- `lib/providers/profile_provider.dart`
- `lib/models/participant.dart`(読むだけ。変更が必要なら要相談)

### 担当ファイル
- `lib/features/profile/profile_input_screen.dart`
- `lib/features/profile/waiting_room_screen.dart`
- `lib/providers/profile_provider.dart`

### 現状
名前・区分(学生/社会人/その他)・趣味(候補タグ+自由入力)・持ち込みテーマを入力するフォームがあり、送信すると部屋作成/参加とプロフィール確定を同時に行い、待機画面へ遷移する。待機画面はホストのみ「会輪をはじめる」ボタンがあり(参加予定人数が揃うと押せるようになる)、右上に⚡アイコンで人数を待たずに開始できる**臨時のテスト用ショートカット**が付いている。

### やること
- 趣味タグ選択UIのデザイン改善
- 入力バリデーションの強化
- 待機画面で「まだ入力中の人がいる」ことをどう見せるか検討(現状は入室=準備完了扱いになっている)
- 右上の⚡ショートカットボタンをどう扱うか判断(本番前に隠す/host限定にする、など)

### Done条件
名前/区分/趣味/持ち込みテーマ入力→待機画面で準備完了人数表示→ホストの開始操作、が一通り動く。

### 作業の始め方
```
git switch rehearsal/01
git pull origin rehearsal/01
git switch -c feature/profile-自分の名前
```
作業が終わったら `rehearsal/01` に向けてPull Requestを出してください(`main` ではありません)。

---

## 担当3: Conversation(会話スペース = メイン画面) 向け指示

あなたはSPAJAMハッカソンで開発中のFlutterアプリ「会輪(kaiwa)」の開発を手伝うAIエージェントです。

**これは共同開発プロジェクトです。** 4人が同時に、それぞれ別の担当領域を並行して実装しています。あなたが担当するのは「Conversation(会話スペース)」機能だけです。他の3人は同時に「Room」「Profile」「Result」を触っているので、**担当外のファイル、特に `lib/main.dart` / `lib/app.dart` / `pubspec.yaml` / `lib/models/` / `lib/services/` などの共通ファイルは、勝手に変更しないでください。** 変更が必要になった場合は、まずユーザーに相談してください。

### まず読むこと
- `AGENTS.md`(プロジェクト全体の設計書、特にセクション10〜16の会話スペース仕様)
- `lib/features/conversation/conversation_screen.dart`
- `lib/features/conversation/widgets/`(sushi_belt.dart, sushi_capsule.dart, selector_banner.dart, topic_banner.dart)
- `lib/providers/conversation_provider.dart`
- `lib/services/ai_topic_service.dart` / `mock_ai_topic_service.dart`(読むだけ。変更が必要なら要相談)

### 担当ファイル
- `lib/features/conversation/**`(conversation_screen.dart と widgets/ 配下すべて)
- `lib/providers/conversation_provider.dart`

### 現状
回転寿司の見た目(奥/手前の二重レーン、透明カプセルの寿司、カウンター、AI大将プレースホルダー)が実装済み。指名された人だけ寿司をタップでき、それ以外の人には「○○さんがネタを選んでいます」と表示される。ネタが選ばれると全画面が寿司ベルトからTopic表示バナーに切り替わり、「次へ回す」でラウンドが進む。次に指名される人は「選択回数が少ない人優先→同数ならランダム→直前の人は除外」のロジックで自動選出される。AI Topic生成は現状Mock(固定候補からランダム+各自の持ち込みテーマ)。

### やること
- 実際のAI API接続の検討(プロバイダ未定。`AiTopicService` インターフェースは変えずに実装を差し替える設計になっているので、まずはユーザーに使用するAPIを確認してから着手)
- 指名ロジックの微調整
- 回転寿司UIの見た目・アニメーション速度などの調整

### Done条件
指名表示→指名者のみ寿司タップ可→Topic全端末同期表示→「次へ回す」でラウンド進行、が一通り動く。

### 作業の始め方
```
git switch rehearsal/01
git pull origin rehearsal/01
git switch -c feature/conversation-自分の名前
```
作業が終わったら `rehearsal/01` に向けてPull Requestを出してください(`main` ではありません)。

---

## 担当4: Result(結果・プロフィールカード) 向け指示

あなたはSPAJAMハッカソンで開発中のFlutterアプリ「会輪(kaiwa)」の開発を手伝うAIエージェントです。

**これは共同開発プロジェクトです。** 4人が同時に、それぞれ別の担当領域を並行して実装しています。あなたが担当するのは「Result(結果・プロフィールカード)」機能だけです。他の3人は同時に「Room」「Profile」「Conversation」を触っているので、**担当外のファイル、特に `lib/main.dart` / `lib/app.dart` / `pubspec.yaml` / `lib/models/` / `lib/services/` などの共通ファイルは、勝手に変更しないでください。** 変更が必要になった場合は、まずユーザーに相談してください。

### まず読むこと
- `AGENTS.md`(プロジェクト全体の設計書、特にセクション17の結果画面仕様)
- `lib/features/result/result_screen.dart`
- `lib/providers/room_provider.dart` / `lib/providers/conversation_provider.dart`(結果画面はこの2つのProviderのデータをそのまま参照している。読むだけ。変更が必要なら要相談)

### 担当ファイル
- `lib/features/result/result_screen.dart`
- (必要なら新規に `lib/providers/result_provider.dart` を作ってもよい。ただしRoomProvider/ConversationProviderの中身は変更しないこと)

### 現状
参加者ごとのプロフィールカード(名前/区分/趣味/持ち込みテーマ/そのラウンドで選んだネタ一覧)を横スワイプ(PageView)で表示する画面ができている。データはRoomProviderとConversationProviderから直接参照している。

### やること
- カードデザインの作り込み(現状は簡易な白背景カードのみ)
- スワイプの挙動・アニメーション改善
- 必要であれば結果画面専用のProviderを切り出す

### Done条件
参加者ごとのカード(区分/趣味/持ち込みTopic/使用Topic一覧)が横スワイプで見やすく表示される。

### 作業の始め方
```
git switch rehearsal/01
git pull origin rehearsal/01
git switch -c feature/result-自分の名前
```
作業が終わったら `rehearsal/01` に向けてPull Requestを出してください(`main` ではありません)。
