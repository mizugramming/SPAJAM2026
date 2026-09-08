# AGENTS.md — 会輪（kaiwa）開発ガイド

## 0. このファイルの目的

このリポジトリは、SPAJAM向けFlutterアプリ **「会輪（kaiwa）」** の開発用リポジトリです。

この `AGENTS.md` は、別のAIエージェントや開発者がリポジトリを開いたときに、

1. アプリの目的と確定仕様を理解する
2. 現在のリポジトリ構成を確認する
3. Flutterアプリとして適切な最終ファイル構成を設計する
4. 4人で並列開発できるよう責務境界を決める
5. 各担当者の担当ファイル・実装タスク・依存関係を決める
6. Merge Conflictを抑えた開発手順を提示する

ところまで進められるようにするための、**開発エージェント向けの上位仕様書**です。

---

# 1. 最重要ルール

このプロジェクトに参加するAI/開発者は、いきなり実装を始めないでください。

最初に必ず以下を行ってください。

```text
1. リポジトリ全体を確認
2. pubspec.yaml を確認
3. lib/ 以下の現在状態を確認
4. Firebase等の導入状況を確認
5. 本AGENTS.mdの確定仕様を確認
6. セクション26の採用済みアーキテクチャとの差分を確認
7. TASKS.mdの担当境界と対象ファイルを確認
8. 共通部分の変更が必要なら、Feature作業より先に共通担当へ集約
9. その後に各担当の作業を開始
```

**4人が同じファイルを同時編集する構成を避けること。**

特に、

```text
lib/main.dart
pubspec.yaml
共通model
route定義
Firebase初期設定
```

へ4人が同時に変更を入れる設計は禁止します。

---

# 2. プロダクト概要

## アプリ名

**会輪（kaiwa）**

「会話」の「話」を「輪」に置き換えた造語。

## コンセプト

> **ネタが回れば、会話が回る。**

初対面の複数人グループに対して、AI寿司大将が「会話のネタ」を提供し、回転寿司のように人から人へ話題を回していくリアル会話支援アプリです。

---

# 3. 解決したい課題

初対面のグループでは以下の問題が起きやすい。

- 誰から話し始めればよいか分からない
- 会話へ入るタイミングが分からない
- 一部の人だけが話してしまう
- 話題が続かない
- 相手のことを知る前に場が終わる

会輪ではAIが会話そのものの相手になるのではなく、

**人と人とのリアルな会話を始めるきっかけ**

として存在する。

---

# 4. UX上の最重要方針

> **アプリの中で会話するのではなく、アプリをきっかけに目の前の人と会話する。**

したがってMVPでは以下を基本方針とする。

- テキストチャットを作らない
- 会話を文字入力させない
- 会話中はスマホを見る時間を必要最低限にする
- AIは司会者/大将として会話開始を支援する
- 実際のコミュニケーションは対面で行う

UI/UXを設計するときは、

> **スマホを見るためのアプリではなく、人の顔を見るためのアプリ**

という思想を優先する。

---

# 5. 想定ターゲット

初対面、または関係性の浅い **3〜6人程度のグループ**。

例:

- ハッカソン
- 新しい学生チーム
- サークル
- ゼミ
- ワークショップ
- 新入社員研修
- 交流イベント

特に、

> 話したい気持ちはあるが、自分から最初の一言を出すことが苦手な人

を主要ターゲットとする。

---

# 6. 確定している画面構成

メイン画面は **4画面** とする。

```text
1. ルーム作成・参加
       ↓
2. プロフィール入力
       ↓
3. 会話スペース
       ↓
4. プロフィールカード / 終了
```

画面内部の待機状態等は追加してよいが、MVPの主導線はこの4画面を維持する。

---

# 7. 画面1 — ルーム作成・参加

## 必須仕様

### ルーム作成

ルーム作成者は予定参加人数を決定する。

MVP:

```text
3人
4人
5人
6人
```

を選択可能。

作成後に `Room ID` を発行する。

### Room ID

- 短い英数字
- 6文字程度を推奨
- 入力しやすい形式
- `0/O`, `1/I/L` 等、見間違えやすい文字は除外してよい

例:

```text
A7K3PX
```

### ルーム参加

参加者はRoom IDを入力して参加する。

### 必要な検証

- Roomが存在するか
- Roomが満員でないか
- すでに会話が始まっていないか
- 通信エラーが発生していないか

---

# 8. 画面2 — プロフィール入力

## 必須入力

### 名前

例:

```text
山田 太郎
```

### 区分

MVP:

```text
学生
社会人
その他
```

### 趣味

複数選択。

候補例:

```text
旅行
ゲーム
映画
音楽
アニメ
スポーツ
カフェ
食べ歩き
読書
写真
料理
その他
```

候補タグ + 自由入力方式を推奨。

### 自分から出したい会話テーマ

参加者1人につき1つ登録。

例:

```text
最近買ってよかったもの
行ってみたい場所
おすすめしたい作品
```

これは後でAI大将がネタを生成する材料として使用する。

---

# 9. プロフィール登録後の待機

プロフィール入力後、全員が準備完了するまで待機する。

表示例:

```text
現在 3 / 4 人

✓ 山田
✓ 鈴木
✓ 佐藤
… 高橋 入力中
```

全参加者のプロフィール登録完了後、

**ホストが「会輪をはじめる」**

操作を行う。

---

# 10. 画面3 — 会話スペース

この画面が本アプリの最重要画面。

## 世界観

- 回転寿司
- AI寿司大将
- 寿司皿 = 会話のネタ
- ネタが回る = 会話が回る

## 基本構成

```text
            会輪

         AI寿司大将

「次は○○さん！
 好きなネタを一皿どうぞ！」

       参加者       参加者

          寿司
      寿司   寿司
       回転レーン
      寿司   寿司

       参加者       参加者
```

---

# 11. 会話ネタ

1つの会話テーマを1枚の寿司皿として扱う。

例:

```text
最近ハマっているもの
行ってみたい場所
学生のうちにやりたいこと
おすすめしたい作品
もし1日だけ何でもできるなら？
```

## Topicの生成元

### User Topic

プロフィール画面で本人が入力したテーマ。

### AI Topic

参加者全員の、

- 区分
- 趣味
- 持ち込みテーマ

を材料にAIが生成するテーマ。

---

# 12. AI大将の役割

AI大将には最低限以下の役割を持たせる。

## 1. 会話ネタ生成

参加者情報から、その場に合う会話テーマを生成する。

## 2. 次にネタを選ぶ参加者を指名したように見せる

UI例:

```text
「次は山田さん！好きな一皿をどうぞ！」
```

MVPでは、参加者選択自体を必ずしもAI APIに任せなくてよい。

公平性のあるロジックで決め、

**AI大将が選んだようにUI上で演出**

してよい。

推奨ロジック:

```text
選択回数が少ない人を優先
↓
同数ならランダム
↓
直前の人は可能な限り避ける
```

---

# 13. Topic選択権

AI大将から指名された人のみ寿司ネタを選択できる。

必要な状態例:

```text
currentSelectorUid
```

現在端末のユーザーIDと一致した場合のみ寿司皿をタップ可能にする。

### 指名された端末

```text
あなたの番です
好きなネタを一皿取ってください
```

### その他の端末

```text
○○さんがネタを選んでいます
スマホを置いて少々お待ちください
```

---

# 14. Topic選択後

ネタが選択されたら、全参加者の端末へ同じTopicを同期する。

例:

```text
今回のネタ

「最近ハマっているもの」

顔を上げて、みんなで話してみよう！
```

ここからの会話はリアルで行う。

---

# 15. 次のネタへ進む方法

会話が一区切りついたら、

```text
次へ回す
```

を押す。

MVPでは現在のTopic選択者、またはホストに操作権を持たせてよい。

処理イメージ:

```text
current Topicをused
↓
round + 1
↓
次のSelector決定
↓
次のTopic選択
```

---

# 16. 会話終了

MVPではホストが

```text
会輪を終了
```

を押すことで終了する。

強制時間制限は不要。

推奨Round数は、

```text
参加人数 × 2
```

程度を目安とするが、仕様として固定しなくてよい。

---

# 17. 画面4 — プロフィールカード

会話終了後、参加者ごとのプロフィールカードを表示する。

## MVP必須表示

- 名前
- 区分
- 趣味
- 本人が持ち込んだTopic
- その参加者がSelectorとして選び、完了したTopic

Topic履歴は `RoundRecord.selectorId` と `RoundRecord.topicId` を使ってParticipantへ関連付ける。全員共通のTopic一覧ではなく、各参加者が選んだTopicをラウンド順に表示する。

例:

```text
┌────────────────────┐
│      山田 太郎       │
│                    │
│ 学生                │
│                    │
│ ゲーム              │
│ 旅行                │
│ カフェ              │
│                    │
│ 持ち込んだネタ       │
│ 最近買ってよかった物 │
│                    │
│ 今日出てきたネタ     │
│ ・旅行              │
│ ・おすすめ作品       │
└────────────────────┘
```

参加者カードを横スワイプ等で切り替える。

カードが人から人へ「回る」感覚をUIに入れてもよい。

---

# 18. 現時点ではMVP必須にしないもの

以下は完成後に余裕があれば実装する。

- 常時音声録音
- リアルタイム音声認識
- 音声文字起こし
- AIによる会話内容要約
- AIによる人物の性格推測
- AI大将の音声読み上げ
- SNS
- フレンド
- 写真アップロード
- 複雑なログイン
- 過去セッションの一覧
- テキストチャット
- 高度なミニゲーム

---

# 19. 将来拡張候補

## 会話音声の要約

将来的には会話を音声認識し、

- 今日分かったこと
- 共通点
- 次回話せそうなテーマ

をAIがプロフィールカードに追加する。

## 「みんなで一皿」モード

参加者が順番に口頭で、

```text
主人公
場所
事件
アイテム
```

等を答え、AIが最後に物語としてまとめる。

共同創作を会話のきっかけにする。

---

# 20. UIデザイン方針

既に作成したコンセプト画像の方向性を採用する。

キーワード:

```text
和風
回転寿司
暖色
親しみやすい
少しゲーム的
AI寿司大将
```

## UI原則

- 角丸中心
- 寿司皿をTopic表現として使う
- AI大将は吹き出しを利用
- 情報を詰め込みすぎない
- Conversation画面では操作を最低限にする
- 文字を読む時間よりリアル会話の時間を長くする

Room画面では寿司職人のキャラクター画像で世界観を示すが、「AI寿司大将」という説明ラベルは表示しない。部屋作成と参加は同一の操作パネル内で切り替え、現在どちらを選んでいるか常に分かるようにする。

## 画面サイズの扱い

- 横幅600px以下のスマホ画面では、端末の画面全体を使用する
- 横幅600pxを超えるWeb / Desktop / Tablet表示は、動作確認用として中央に最大390×844のスマホ枠を表示する
- 各Featureはブラウザ全体の幅ではなく、Featureへ渡された制約内でレイアウトする
- 320px程度の狭い端末でも、操作不能なはみ出しを発生させない
- ノッチやホームインジケータは `SafeArea` で考慮する

---

# 21. 技術前提

## Flutter

現在は、以下の共通基盤まで実装されている。

- `features/` 単位の画面・Widget分割
- `models/`、`providers/`、`services/`、`core/` の責務分離
- Provider / ChangeNotifierによる状態管理
- Service interfaceとMock実装の分離
- named routeによる4画面＋待機画面の遷移
- Material 3を基盤とした共通Theme
- スマホ縦向き固定と、Web / Desktop向けスマホ枠プレビュー

構成を変更する場合は、実際のリポジトリと `pubspec.yaml` を確認し、4人の担当境界を崩さないこと。

---

# 22. バックエンド方針と現在地

現在はService interfaceとMock実装のみであり、Firebaseのpackage・設定ファイル・初期化処理は未導入。

`MockRoomService` と端末内のProvider状態は同一プロセス内でしか共有されないため、これだけでは4端末同期のMVP完了とはしない。

複数端末同期にはFirebaseを採用候補とする。

想定:

```text
Firebase Authentication
Cloud Firestore
Cloud Functions
```

導入担当者は、作業前に `pubspec.yaml`・Firebase設定状態・残り開発時間を確認すること。Firebase以外を採用する場合も、Room・参加者・Conversation状態を複数端末へリアルタイム同期できることを必須条件とする。

採用する場合、Anonymous Authenticationを推奨する。

理由:

- ログイン画面不要
- 同名ユーザーを識別できる
- 端末ごとの操作権限管理がしやすい

---

# 23. AI API

AIはTopic生成に利用する。

## 入力イメージ

```json
{
  "participants": [
    {
      "category": "学生",
      "hobbies": ["ゲーム", "旅行"],
      "submittedTopic": "最近買ってよかったもの"
    }
  ]
}
```

## 出力イメージ

```json
{
  "topics": [
    "最近、人におすすめしたくなったもの",
    "一度だけどこでも旅行できるならどこ？"
  ]
}
```

## AI Topic条件

- 日本語
- 短い
- 初対面でも答えやすい
- Yes/Noだけで終わりにくい
- プロフィールとの関連性がある
- センシティブすぎる質問を避ける

---

# 24. APIキー管理

AI APIを利用する場合、

**APIキーをFlutterクライアントコードへ直接埋め込まないこと。**

例:

```text
Flutter
↓
Cloud Functions / Backend
↓
AI API
```

を推奨。

---

# 25. AI API障害への対応

AI生成に失敗してもデモを継続できるよう、固定Topicを持つ。

例:

```text
最近ハマっているもの
行ってみたい場所
最近買ってよかったもの
おすすめしたい作品
休日の過ごし方
今挑戦してみたいこと
```

SPAJAM本番ではネットワーク障害が起きても主要体験をデモできる設計を優先する。

---

# 26. 採用済み構成と残る共通基盤

ここからが重要。

以下を現在の基準とする。変更時は**実際のリポジトリを確認し、共通基盤担当と合意してから**更新すること。

## A. Flutterアーキテクチャ

採用済み:

- Feature UI: `lib/features/<feature>/`
- 共通Model: `lib/models/`
- 状態管理: `lib/providers/`
- データアクセス契約と実装: `lib/services/`
- Theme / utility: `lib/core/`
- DI: `lib/main.dart`
- named route定義: `lib/app.dart`
- Feature固有Widget: 各Featureの `widgets/`

未実装:

- Firebaseアクセス実装と初期化
- Cloud Functions等を利用するAI API実装
- ModelのFirestore serialize / deserialize

---

## B. 状態管理方式

`provider` packageの `Provider` / `ChangeNotifierProvider` を採用済み。

MVP中にRiverpodやBlocへ全面移行しない。状態の責務が増えた場合も、まず既存ProviderまたはServiceの拡張で対応する。

---

## C. Firestore Schema

以下を採用予定Schemaとする。現時点では未実装。

```text
rooms/{roomCode}
  expectedCount: number
  status: "waiting" | "inProgress" | "ended"
  hostUid: string
  currentRound: number
  currentSelectorUid: string | null
  activeTopicId: string | null
  createdAt: timestamp
  updatedAt: timestamp

rooms/{roomCode}/participants/{uid}
  name: string
  category: "student" | "worker" | "other"
  hobbies: string[]
  submittedTopic: string
  ready: boolean
  selectionCount: number
  joinedAt: timestamp

rooms/{roomCode}/topics/{topicId}
  text: string
  source: "user" | "ai"
  contributedByUid: string | null
  used: boolean
  usedInRound: number | null
  createdAt: timestamp

rooms/{roomCode}/rounds/{roundId}
  round: number
  selectorUid: string
  topicId: string
  selectedAt: timestamp
  completedAt: timestamp | null
```

- Room codeをRoom document IDにする
- Participant document IDにはAnonymous AuthenticationのUIDを使用する
- Result画面の表示履歴は `rounds` を正とし、`selectorUid` と `topicId` の対応を保存する
- Topic確定、使用済み化、Round更新、次Selector決定はtransactionで一貫して更新する
- 参加・開始・Topic選択・終了の権限をSecurity Rulesで検証する

現在のDart `Room` は `hostUid` を持たず、参加者をListとして保持している。Firestore実装時は画面側へ同じ読み取り形を提供しつつ、保存時は上記subcollectionへ分離する。Model変更とserialize / deserialize追加は共通基盤担当が行う。

---

## D. 画面間インターフェース

現在の契約:

```text
Room → Profile
  Route引数: RoomArgs(isHost, expectedCount?, roomCode?)

Profile → Waiting
  Route引数: なし
  ProfileProvider: この端末のParticipant
  RoomProvider: 作成または参加したRoom

Waiting → Conversation
  Route引数: なし
  RoomProvider: Room / Participant一覧 / status
  ProfileProvider: この端末のuid

Conversation → Result
  Route引数: なし
  RoomProvider: Participant一覧
  ConversationProvider: Topic一覧 / RoundRecord履歴
```

Firestore導入後もRouteへRoom全体を渡さず、`roomCode` と認証UIDを基準にService / Providerから購読する。アプリ再起動・deep link対応が必要になった場合は、現在Room codeを保持するSession用Providerを共通基盤として追加する。

現在のMockでは `participants.first` をホスト扱いしている暫定実装である。本番接続時は `rooms/{roomCode}.hostUid` を正として判定する。

---

# 27. 4人開発の必須条件

4人で並列開発する。

### 固定担当の大分類

```text
担当者1
→ Room作成・参加

担当者2
→ Profile

担当者3
→ Conversation

担当者4
→ Result / Profile Card
```

この大分類は維持する。

ただし実際のファイル単位の所有権は、最終ファイル構成を決定した後に割り当てる。

---

# 28. 共通基盤を変更する際の必須成果物

初回設計時、またはFirebase導入などで共通基盤・Feature間契約を変更する担当者は、実装開始前に以下を確認・更新すること。個別Feature内だけの変更で、確定済み設計を毎回作り直す必要はない。

---

## 1. 最終ディレクトリツリー

例:

```text
lib/
├── ...
```

の形式で、実際に採用する構成を提示する。

---

## 2. 各ファイルの責務

例:

| File | Responsibility |
|---|---|
| xxx.dart | Room作成 |
| xxx.dart | Firestoreアクセス |

の形式。

---

## 3. 4人の担当ファイル一覧

例:

```text
担当者1
- file A
- file B

担当者2
- file C
- file D
```

**原則として同じ実装ファイルを複数人へ割り当てないこと。**

---

## 4. 共通担当ファイル

以下のような共通部分を明示する。

```text
main.dart
routes
theme
models
Firebase initialization
pubspec.yaml
```

これらについて、

- 誰が最初に作るのか
- いつmainへmergeするのか
- 他の3人はいつからbranchを切るのか

を決める。

---

## 5. 実装順序

依存関係を考慮して、

```text
Phase 0
Phase 1
Phase 2
...
```

の形式で提示する。

---

## 6. Git Branch構成

4人のBranch名を決める。

例:

```text
feature/room
feature/profile
feature/conversation
feature/result
```

必要であれば、

```text
chore/project-setup
```

などの共通branchを追加する。

---

## 7. Merge順序

Merge Conflictを避けるための順序を提示する。

---

## 8. Feature間の契約

例:

```text
Room → Profile
何を渡すか

Profile → Conversation
何を渡すか

Conversation → Result
何を渡すか
```

を確定する。

---

## 9. データモデル

Dart classとして最終形を提示する。

最低限:

```text
Room
Participant
Topic
```

---

## 10. Firestore Schema

最終Collection / Document構造を提示する。

---

## 11. MVP優先順位

各タスクについて、

```text
Must
Should
Could
```

等で優先順位をつける。

SPAJAM開発時間内に完成することを最優先する。

---

## 12. Done条件

各担当者について、

```text
ここまで動けば担当完了
```

というAcceptance Criteriaを定義する。

---

# 29. ファイル分割の判断基準

次のAIは、単純に「1画面 = 1ファイル」としないこと。

各Featureについて少なくとも、

```text
UI
状態管理
データアクセス
Feature固有Widget
```

の責務を検討する。

ただしファイルを細分化しすぎない。

SPAJAMの短期開発であるため、

> **保守性より複雑性が高くなる設計**

は避ける。

---

# 30. Merge Conflict回避ルール

## 禁止

4人が同時に、

```text
main.dart
pubspec.yaml
routes
共通model
```

を自由に変更すること。

## 推奨

### Phase 0

1人、またはペアで共通基盤を作る。現在の進捗は以下。

```text
[完了] Folder Structure
[完了] Models（端末内Mock用）
[完了] Routes
[完了] Theme
[完了] Service interface / Mock
[完了] 4画面＋待機サブ画面
[未完] Firebase Initialize / Firebase実装
[未完] Firestore用Model変換
[未完] Authentication / Security Rules
```

未完の共通基盤はFeature branch上で個別に作らず、担当者と契約を決めた共通branchで実装して先に統合先へmergeする。

### Phase 1

共通基盤のcommitを全員pull。

### Phase 2

4人がFeature Branchを切る。

---

# 31. デモ優先設計

これはSPAJAM向けの短期開発である。

以下の優先順位を守る。

```text
1. デモが最後まで通る
2. 複数端末同期が安定する
3. 回転寿司の体験が伝わる
4. AI Topic生成が動く
5. デザインを磨く
6. 将来機能
```

AI機能が動かないことで全体が停止する設計は禁止。

---

# 32. 最低限の完成シナリオ

以下が4端末で成功すればMVP成立とする。

```text
1. 1人が4人Roomを作成
2. Room IDを共有
3. 残り3人が参加
4. 各自Profileを入力
5. 全員ready
6. Hostが開始
7. AI/ロジックがSelectorを決定
8. Selectorだけ寿司Topicを選択
9. 全端末でTopic同期
10. その場でリアル会話
11. 次の人へ回す
12. 数Round実行
13. Hostが終了
14. 全員のProfile Cardを表示
```

---

# 33. エラー系の最低確認

以下を確認する。

```text
存在しないRoom ID
Room満員
talking中Roomへの途中参加
通信失敗
AI API失敗
```

AI失敗時は固定Topicで継続すること。

## 最低限の検証

```text
flutter analyze --no-pub
flutter test --no-pub
```

- Widget testでは少なくとも320×568と390×844を確認する
- Web / Desktopの確認では、横長画面内に390×844以下のスマホ枠で表示されることを確認する
- Android / iOSの統合完了判定は、実機またはemulatorの複数台で同じRoomへ接続して行う
- Web buildや単一プロセスのMock通過だけを、複数端末同期の証明にしない

---

# 34. 現在のリポジトリ状態

2026-09-07監査時点の `lib/` は以下。

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── theme/app_theme.dart
│   └── utils/room_code.dart
├── features/
│   ├── room/room_screen.dart
│   ├── profile/
│   │   ├── profile_input_screen.dart
│   │   └── waiting_room_screen.dart
│   ├── conversation/
│   │   ├── conversation_screen.dart
│   │   └── widgets/
│   └── result/
│       ├── result_screen.dart
│       └── widgets/
├── models/
│   ├── participant.dart
│   ├── room.dart
│   ├── round_record.dart
│   └── topic.dart
├── providers/
│   ├── conversation_provider.dart
│   ├── profile_provider.dart
│   └── room_provider.dart
└── services/
    ├── ai_topic_service.dart
    ├── mock_ai_topic_service.dart
    ├── mock_room_service.dart
    └── room_service.dart
```

Feature分割・Provider・Service interface・Theme・route・Mockによる単体フローは実装済み。Firebase、複数端末同期、Authentication、Security Rulesは未実装。

現在の全ツリーは実際のリポジトリから再確認すること。

**この文書に過去のtreeをコピーしたものを最新状態だと決めつけないこと。**

---

# 35. 設計判断で迷った場合の優先順位

```text
1. 4人で衝突せず並列開発できるか
2. SPAJAM時間内に完成できるか
3. デモ時に「まわる」が一目で伝わるか
4. リアル会話を邪魔しないか
5. Firebase/AI障害時にも最低限動くか
6. 将来的に拡張できるか
```

---

# 36. 次のAIへの最終指示

この `AGENTS.md` を読んだら、ただちにコードを書き始めず、まず現在のリポジトリと `TASKS.md` を調査してください。セクション21・26・34の採用済み構成を基準に、実装との差分がある場合は文書も更新します。

共通基盤またはFeature間契約を変更する場合は、次の順番で回答・作業してください。個別Feature内で完結する作業は、担当境界と既存契約を確認したうえで該当実装・テストへ進んで構いません。

```text
STEP 1
現在のリポジトリ状態を要約

STEP 2
採用済み技術構成との差分を提案

STEP 3
必要な場合のみlib/ディレクトリ構成を更新

STEP 4
共通Model / Service / Routeを確定

STEP 5
Firestore Schemaを確定

STEP 6
4人の担当ファイルを完全に分離

STEP 7
各担当者の実装タスク・Done条件を定義

STEP 8
Git Branch / Merge順序を決定

STEP 9
全員が安全に開発を継続できる状態になったことを確認

STEP 10
必要であれば共通基盤だけ先に実装
```

---

# 37. プロダクトを一言で説明する場合

> **会輪は、AI寿司大将が初対面の人たちに合った「会話のネタ」を握り、回転寿司のように人から人へ回していく、リアル会話支援アプリです。**
