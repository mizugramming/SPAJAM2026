# つなぐんの通信サーバー

Cloudflare Worker が HTTP と WebSocket を受け、ルームごとの Durable Object が進行・報酬・期限を管理します。SQLite-backed storage にルーム状態を保存してから応答・配信します。Android 2台の発表用ルームと、最大24人の通常ルームを扱います。仮想参加者や結果を注入するAPIはありません。

## ローカルで起動

Node.js 22以上を使います。依存は `package-lock.json` で固定しています。

```bash
cd server
npm ci
npm run check
npm test
npm run build
npm run dev
```

`build` は `wrangler deploy --dry-run` で、クラウドへ公開しません。`dev` は `http://127.0.0.1:8787`、WebSocketは同じホストの `/rooms/CODE/socket` です。開発データは `.wrangler/` に保存され、Git管理しません。

別ターミナルで次を実行すると、実HTTPと2本のWebSocketを使い、双方落下・再接続・交互の協力操作・REBORN・共通の綱引き開始時刻までを検証します。約45秒かかります。専用の発表用ルームを作るため、操作中のルームを変更しません。

```bash
cd server
npm run test:integration
```

検証の待機時刻はWebSocketのpingで校正したサーバー時計を使い、実行PCの壁時計には依存しません。`TSUNAGUN_TEST_CLOCK_SKEW_MS=4000` を付けると、診断用の端末壁時計を4秒ずらした状態でも同じ検証を行えます。失敗時は入力時刻と前後のゲーム状態を出力し、開始前・遅延・中断を区別します。秘密の入室キーと参加トークンは出力しません。

検証先を変える場合は `TSUNAGUN_TEST_URL` にベースURLを指定します。これはテスト用環境変数で、アプリの設定名は `TSUNAGUN_SERVER_URL` です。アプリ側の起動・ビルドでは `--dart-define=TSUNAGUN_SERVER_URL=https://公開先` を指定します。2台を別のネットワークで使う場合は公開HTTPS/WSSサーバーが必要です。`127.0.0.1` は各端末自身を指すため、Android 2台の接続先にはできません。

## 公開

この実装にはCloudflareアカウント・鍵・公開URLを同梱していません。アカウント管理者がCloudflareへログインして公開します。

```bash
cd server
npx wrangler login
npm run deploy
```

`wrangler.jsonc` の `ROOMS` バインディングと `new_sqlite_classes` migration を同時に適用します。公開されたHTTPS URLをアプリ2台に同じ値で指定してください。APIトークン・`.dev.vars`・端末の参加トークンはリポジトリに保存しません。参加トークンは本人の操作権限そのものです。QRには入れません。

ルーム作成・参加は匿名です。一般公開する場合は、Cloudflare側で想定人数に合わせた作成APIのレート制限と利用上限を設定します。このサーバーはルーム内で人数・本文サイズ・ソケット数・操作件数を制限しますが、サービス全体のアカウント単位の作成数を制限する認証サービスは持ちません。

## 接続仕様

すべてJSON。Bearerトークンは参加者本人にだけ返し、通常のsnapshotに含めません。WebプレビューのCORSを許可します。Cookieは使いません。

| リクエスト | 内容 |
|---|---|
| `POST /rooms` | `{mode:"standard"\|"presentation", durationSeconds:180, admissionKey:"64桁の秘密hex"}` → `Session` |
| `POST /rooms/CODE/join` | `{admissionKey:"64桁の秘密hex"}` → `Session`。新規参加は開始前のみ |
| `GET /rooms/CODE` | Bearer認証 → `{snapshot}` |
| `POST /rooms/CODE/actions` | Bearer認証、`{requestId,type,...payload}` → `{snapshot}` |
| `GET /rooms/CODE/socket` | WebSocket upgrade。最初に `{type:"auth",token}` |
| `GET /health` | `{ok:true}` |

`Session` は `{code,participantId,token,snapshot}`。ルームコードは作成用の秘密キーのSHA-256から導出する大文字hex12文字、相手コードはルーム内で一意の大文字hex8文字、参加トークンは暗号学的乱数256bitです。URLにトークンを入れません。ルーム参加はコード入力で行います。対戦・協力の相手を識別するQRだけを `tsunagun:pair:CODE:PAIRCODE` として表示し、URLを開く用途では使いません。

作成・参加の前に、アプリは暗号学的乱数256bitの `admissionKey` と接続先・操作種別・参加先を端末の安全な保存先へ書き込みます。応答だけが失われても、同じキーで再試行すると同じ参加者IDとトークンが返り、人数枠を再消費しません。作成の再試行は同じルームへ到達します。既存参加者の回復は開始後も可能で、新規参加の締切とは区別します。作成時と違う設定で同じキーを使うと拒否します。キーは参加トークンと同じ秘密情報として扱い、URL・QR・snapshot・ログへ含めません。参加トークン保存後に端末の未完了キーを消し、保存前に終了した場合は次回起動で同じ入室処理を再開します。

認証後のWebSocketは本人用 `{type:"snapshot",snapshot}` を受信します。ゲーム操作は `{type:"command",requestId,action:{type,...payload}}` を送信し、`ack` または `error` を受け取ります。時刻合わせは `{type:"ping",id}` に対する `{type:"pong",id,serverNow}` を使います。認証は10秒以内、未認証の操作は拒否します。本文4KiB、同時ソケット64、1ソケット毎秒30メッセージが上限です。

操作IDはルーム内の参加者ごとに保存し、同じ内容の再送では報酬を増やしません。同じIDで異なる内容を送ると拒否します。ルームは最大20,000回の新しい操作を保存します。結果確定済みの交流も追加報酬を拒否します。相手の結果画面を消さずに、本人だけホームへ戻せます。

## 操作とルール

- `profile {profile:{nickname,hobby,comment}}`：開始前に登録。ニックネーム20・趣味60・ひとこと80書記素以内。ニックネーム・趣味は必須です。
- `start`：主催者のみ。2人以上のプロフィールが揃ったら均等にチームを割り振り、共通の終了時刻を設定します。
- `pair {peerCode}`：両者が接続し、他の交流に入っていないときに両画面へ相手確認を提示します。通常ルームは同じ相手と合計1回。発表用ルームは2人までで、同じ相手と対戦→協力を各1回遊べます。中断・引分けは回数を消費しません。
- `ready {encounterId,round}`：両者が押すと共通の3秒カウントダウン。引分けは報酬なしで次のroundへ進みます。
- `duelInput {encounterId,round,at,fell}`：共通開始時刻からの経過時間でサーバーが深さを計算。水面は1800ms。両者落下は双方に骨を1匹ずつ付与して終了。双方が安全かつ同一ミリ秒なら引分けです。
- `coopInput {encounterId,round,level,hop,at,miss}`：playerIdsの先頭が奇数hop、2人目が偶数hopを担当。1レベル6hop、3レベルを成功させます。判定窓は230/190/150ms。通信到着時刻ではなく、サーバー時刻へ補正した入力時刻で判定します。
- `cancel {encounterId}`：未確定の交流を報酬なしで中断。片方の通信切断も中断します。既に確定した結果は維持します。同一人物の古いソケットが閉じても、新しい接続があれば中断しません。
- `return {encounterId}`：本人だけホームへ戻ります。相手は結果を引き続き確認できます。
- `finish`：主催者が交流受付を終了。未確定ゲームは最大30秒待ってから中断し、報酬を変更せず集計を固定します。
- `finale`：主催者が共通の綱引き開始時刻を一度だけ設定します。
- `leave`：開始前だけ退出。参加者が残っている間、主催者は退出できません。

入力には交流ID・round・level・hopを付け、古い交流の通知を次のゲームへ使いません。推定時刻の未来許容は250ms、受信遅延は1800msまでです。間に合わない・入力が届かないことを自動敗北にはせず、未確定交流を中断します。これは公平な同期のための整合確認であり、改変クライアントへの競技用アンチチート機構ではありません。

協力成功時は、各参加者の最古の骨を個別に1匹復活させます。骨がない参加者は協力相手の普通の子分を1匹迎えます。失敗時は両者が相手の骨を1匹迎えます。普通の子分は3pt、骨は1pt。復活では元の相手と今回の協力相手を保持します。最終順位は同点同順位で、全員0ptならMVPはありません。

## 保存・期限

作成から24時間でプロフィール・参加トークン・報酬・操作履歴を削除します。イベント中の結果を永続的なアカウント履歴として残す機能はありません。削除後の再接続は新しいルームへ参加してください。端末側セッションだけを消しても、ルームの他の参加者や結果は削除しません。

Durable Objectのalarmが開始・ゲームの入力待ち・レベル移動・締切・ルーム削除を進めます。端末を閉じたままでも期限が働きます。全状態を書き込んでからsnapshotを送信するため、再接続時には確定結果と報酬を復元します。

参考：Cloudflareの [WebSocket Hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/)・[SQLite storage](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/)・[Durable Object State](https://developers.cloudflare.com/durable-objects/api/state/)。
