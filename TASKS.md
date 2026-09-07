# TASKS.md — 4人分担タスク指示書

このファイルは、4人の担当者がそれぞれ自分のAIエージェント(Claude Code等)に**そのままコピペして渡す**ための指示文です。担当ごとにセクションが分かれているので、自分の担当箇所だけをコピーして使ってください。

前提として、`AGENTS.md`(このリポジトリの設計書)と `rehearsal/01` ブランチ上に、Phase 0の共通基盤(モデル・サービス・Provider・4つのメイン画面＋待機サブ画面の雛形)が実装済みです。ここから4人が並行して各担当を深掘りします。

この指示書に記載した「現状」と実装が別のFeature branch上にある場合は、その共通基盤変更を先に `rehearsal/01` へmergeしてから本指示を配布してください。4人は必ず同じ基準commitからbranchを作成します。

### 共通の完了判定

- 現在の `MockRoomService` / `MockAiTopicService` は、1つのアプリプロセス内だけで動く開発用実装である。
- Mockで画面遷移できる状態を「単体完了」、Firebase等を接続して複数端末で同期できる状態を「統合完了」と区別する。
- `全端末同期` をDoneとするには、Room・Participant・Topic・Round履歴が共有バックエンドへ保存され、実機複数台で確認できていること。
- `lib/main.dart`、`lib/app.dart`、`lib/core/`、`lib/models/`、`lib/services/`、`pubspec.yaml`、プラットフォーム設定は共通基盤担当だけが変更する。必要な変更はIssueまたはPRコメントで共通基盤担当へ依頼する。
- 作業開始前に対象ブランチを最新化し、`flutter analyze --no-pub` と `flutter test --no-pub` が成功する状態からブランチを作る。

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
予定人数(3/4/5/6人)を選ぶか、6文字の部屋番号を入力して `ProfileInputScreen` へ画面遷移する。Room画面は小型スマホとキーボード表示に対応済み。実際の部屋作成/参加処理(`RoomService`呼び出し)と例外表示はプロフィール入力画面側で行う。

### やること
- 部屋番号入力のUX確認(6文字、使用可能文字、大文字化、IMEの完了操作)
- Room作成/参加の入口として、初見でも迷わない説明と視覚的な優先順位を整える
- `RoomProvider` に接続状態やエラー状態を追加する必要がある場合は、共通基盤担当と契約を先に決める
- 見た目の作り込み

例外の出し分けは `profile_input_screen.dart`、Room IDのコピーは `waiting_room_screen.dart` の責務なので、担当2へ依頼すること。

### Done条件
予定人数選択または正しい6文字のRoom ID入力から、必要な `RoomArgs` を付けてプロフィール入力画面へ遷移できる。320px幅程度の小型スマホとキーボード表示時にも、主要ボタンが操作できる。

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
名前・区分(学生/社会人/その他)・趣味(候補タグ+自由入力)・持ち込みテーマを入力するフォームがあり、必須入力と文字数を検証する。送信時に部屋作成/参加とプロフィール確定を行い、待機画面へ遷移する。部屋が存在しない・満員・開始済みの場合はメッセージを出し分ける。待機画面ではRoom IDをコピーでき、⚡テスト用ショートカットはデバッグビルドのホストだけに表示する。

### やること
- 趣味タグ選択UIのデザイン改善
- 待機画面で「まだ入力中の人がいる」ことをどう見せるか検討(現状は入室=準備完了扱いになっている)
- 送信中・通信失敗時の表示と再操作を実機で確認する
- Room作成/参加処理をProfile内で実行する現構成を変更する場合は、担当1と先に画面間契約を更新する

### Done条件
名前/区分/趣味/持ち込みテーマの必須入力→部屋作成または参加→待機画面で準備完了人数表示→ホストの開始操作、が一通り動く。RoomNotFound/RoomFull/RoomAlreadyStartedを区別して表示できる。

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
回転寿司の見た目(奥/手前の二重レーン、透明カプセルの寿司、カウンター、AI大将プレースホルダー)が実装済み。指名者だけが未使用Topicを選択でき、「次へ回す」で使用済みTopicを除外してラウンドが進む。Topic生成中・失敗・全件使用済みの状態表示、再試行、終了確認、終了直前に開いていたTopicの履歴保存まで実装している。AI Topic生成は現状Mock(固定候補からランダム+各自の持ち込みテーマ)。

ただし、Topic一覧・選択中Topic・Round履歴は現在 `ConversationProvider` の端末ローカル状態であり、複数端末同期は未実装。

### やること
- 実際のAI API接続の検討(プロバイダ未定。`AiTopicService` インターフェースは変えずに実装を差し替える設計になっているので、まずはユーザーに使用するAPIを確認してから着手)
- Topic選択・Round履歴・現在Selectorを共有バックエンド上で一貫して更新する契約を、共通基盤担当と確定する
- 指名ロジックの公平性と、同時操作時の競合を複数端末で確認する
- 回転寿司UIの見た目・アニメーション速度などの調整

### Done条件
単体完了: 指名表示→指名者のみ未使用Topicを選択→Topic表示→「次へ回す」でラウンド進行、が一通り動き、AI失敗時に再試行できる。

統合完了: 同じRoomの全端末でTopic一覧・選択中Topic・Round履歴・終了状態が一致し、同時タップでも二重確定されない。

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
- `lib/features/result/widgets/**`
- (必要なら新規に `lib/providers/result_provider.dart` を作ってもよい。ただしRoomProvider/ConversationProviderの中身は変更しないこと)

### 現状
参加者ごとの和紙・寿司皿風プロフィールカード(名前/区分/趣味/持ち込みテーマ/その参加者が選んだネタ一覧)を、横スワイプ(PageView)で表示する。前後カードの見切れ、中央カードのスケール演出、ページドット、現在人数表示、空データ表示まで実装済み。データはRoomProviderとConversationProviderから直接参照し、不明なTopic IDは安全に読み飛ばす。

### やること
- 実機で文字サイズ・縦スクロール・カード切替の操作感を確認する
- Firebase接続後、全端末で同じParticipant/Topic/Round履歴が表示されることを確認する
- Result固有の非同期処理が増えた場合だけ専用Providerを検討し、表示用データ変換だけのためには追加しない

### Done条件
参加者ごとのカード(区分/趣味/持ち込みTopic/その参加者が選んだTopic一覧)が、320px幅程度の小型スマホでも崩れず、横スワイプと縦スクロールで見やすく表示される。履歴不整合があっても画面がクラッシュしない。

### 作業の始め方
```
git switch rehearsal/01
git pull origin rehearsal/01
git switch -c feature/result-自分の名前
```
作業が終わったら `rehearsal/01` に向けてPull Requestを出してください(`main` ではありません)。
