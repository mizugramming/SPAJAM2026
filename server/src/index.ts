import { DurableObject } from "cloudflare:workers";
import {
  admissionKey,
  resolveCreation,
  creationCodeDigits,
  creationOwner,
  recoveredMember,
} from "./admission";
import {
  advance,
  authenticate,
  command,
  connectionChanged,
  reconcileConnections,
  joinRoom,
  newMember,
  newRoom,
  nextAlarm,
  record,
  RuleError,
  snapshot,
  type RoomState,
} from "./room";

export interface Env {
  ROOMS: DurableObjectNamespace<RoomObject>;
}
const CODE = /^(?:[0-9]{5}|[A-F0-9]{12})$/;
const MAX_BODY = 4096;
const MAX_SOCKETS = 64;
const hex = (bytes: number) =>
  [...crypto.getRandomValues(new Uint8Array(bytes))]
    .map((v) => v.toString(16).padStart(2, "0"))
    .join("");
const json = (data: unknown, status = 200) =>
  Response.json(data, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
const errorResponse = (e: unknown) => {
  if (!(e instanceof RuleError))
    console.error(
      "Room processing failed",
      e instanceof Error ? e.stack : "unknown error",
    );
  return json(
    {
      ...(e instanceof RuleError && e.code ? { code: e.code } : {}),
      error:
        e instanceof RuleError
          ? e.message
          : "接続処理に失敗しました。もう一度お試しください。",
    },
    e instanceof RuleError ? e.status : 500,
  );
};
function bearer(request: Request) {
  return request.headers
    .get("authorization")
    ?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
}
async function body(request: Request): Promise<Record<string, unknown>> {
  if (
    !request.headers
      .get("content-type")
      ?.toLowerCase()
      .startsWith("application/json")
  )
    throw new RuleError("JSON形式で送信してください。", 415);
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY)
    throw new RuleError("送信内容が大きすぎます。", 413);
  const reader = request.body?.getReader();
  if (!reader) throw new RuleError("送信内容がありません。", 400);
  let size = 0;
  const chunks: Uint8Array[] = [];
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.length;
    if (size > MAX_BODY) {
      await reader.cancel();
      throw new RuleError("送信内容が大きすぎます。", 413);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  try {
    return record(JSON.parse(new TextDecoder().decode(bytes)));
  } catch (e) {
    if (e instanceof RuleError) throw e;
    throw new RuleError("送信内容を確認してください。", 400);
  }
}
function allowKeys(value: Record<string, unknown>, keys: string[]) {
  if (Object.keys(value).some((k) => !keys.includes(k)))
    throw new RuleError("未対応の送信項目があります。", 400);
}
function cors(original: Response): Response {
  const response = new Response(original.body, {
    status: original.status,
    statusText: original.statusText,
    headers: original.headers,
    webSocket: original.webSocket,
  });
  response.headers.set("access-control-allow-origin", "*");
  response.headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  response.headers.set(
    "access-control-allow-headers",
    "authorization, content-type",
  );
  response.headers.set("access-control-max-age", "86400");
  return response;
}
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      if (request.method === "OPTIONS")
        return cors(new Response(null, { status: 204 }));
      const url = new URL(request.url);
      if (url.pathname === "/health" && request.method === "GET")
        return cors(json({ ok: true }));
      if (url.pathname === "/rooms" && request.method === "POST") {
        const input = await body(request);
        allowKeys(input, [
          "mode",
          "durationSeconds",
          "admissionKey",
          "roomCodeDigits",
        ]);
        const key = admissionKey(input.admissionKey);
        const digits = creationCodeDigits(input.roomCodeDigits);
        const result = await resolveCreation(
          key,
          (code, operation) => {
            const target = env.ROOMS.get(env.ROOMS.idFromName(code));
            return target.fetch(
              new Request(`https://room.internal/${code}/${operation}`, {
                method: "POST",
                headers: { "content-type": "application/json" },
                body: JSON.stringify(input),
              }),
            );
          },
          digits === 5 ? "short" : "legacy",
        );
        return cors(result);
      }
      const match =
        /^\/rooms\/([0-9]{5}|[A-F0-9]{12})(?:\/(join|actions|socket))?$/.exec(
          url.pathname,
        );
      if (!match || url.search)
        throw new RuleError("ルームが見つかりません。", 404);
      const target = env.ROOMS.get(env.ROOMS.idFromName(match[1]!));
      const internal = new URL(request.url);
      internal.pathname = `/${match[1]}/${match[2] ?? "snapshot"}`;
      // Buffer bounded JSON before crossing the DO boundary. An early 401 from
      // the object must not leave the original incoming body streaming.
      const forwarded =
        request.method === "POST"
          ? new Request(internal, {
              method: "POST",
              headers: request.headers,
              body: JSON.stringify(await body(request)),
            })
          : new Request(internal, request);
      return cors(await target.fetch(forwarded));
    } catch (e) {
      return cors(errorResponse(e));
    }
  },
} satisfies ExportedHandler<Env>;

type SocketSession = {
  participantId: string | null;
  openedAt: number;
  count: number;
  windowAt: number;
};
/** One SQLite-backed object owns all players, encounters and rewards in a room. */
export class RoomObject extends DurableObject<Env> {
  private room: RoomState | null = null;
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.room = (await ctx.storage.get<RoomState>("room")) ?? null;
      if (this.room) {
        const connected = new Set(
          ctx
            .getWebSockets()
            .map((ws) => this.attachment(ws)?.participantId)
            .filter(Boolean),
        );
        const draft = structuredClone(this.room);
        reconcileConnections(
          draft,
          new Set(
            [...connected].filter((id): id is string => typeof id === "string"),
          ),
          Date.now(),
        );
        if (draft.revision !== this.room.revision) await this.save(draft);
      }
    });
  }
  private attachment(ws: WebSocket): SocketSession | null {
    try {
      return ws.deserializeAttachment() as SocketSession | null;
    } catch {
      return null;
    }
  }
  private async save(draft: RoomState) {
    await this.ctx.storage.put("room", draft);
    this.room = draft;
    await this.schedule();
  }
  private async schedule() {
    const now = Date.now();
    const deadlines = this.room ? [nextAlarm(this.room, now)] : [now + 10_000];
    for (const ws of this.ctx.getWebSockets()) {
      const a = this.attachment(ws);
      if (a && !a.participantId) deadlines.push(a.openedAt + 10_000);
    }
    await this.ctx.storage.setAlarm(Math.max(now + 1, Math.min(...deadlines)));
  }
  private live() {
    if (!this.room) throw new RuleError("ルームが見つかりません。", 404);
    if (Date.now() >= this.room.expiresAt)
      throw new RuleError(
        "このルームの保存期間が終了しました。新しいルームを作成してください。",
        410,
      );
    return this.room;
  }
  private async update(action: (draft: RoomState, now: number) => void) {
    const draft = structuredClone(this.live());
    const now = Date.now();
    advance(draft, now);
    action(draft, now);
    await this.save(draft);
    this.broadcast();
  }
  private broadcast() {
    if (!this.room) return;
    for (const ws of this.ctx.getWebSockets()) {
      const id = this.attachment(ws)?.participantId;
      if (!id) continue;
      if (!this.room.members[id]) {
        ws.close(1008, "参加情報が終了しました");
        continue;
      }
      try {
        ws.send(
          JSON.stringify({
            type: "snapshot",
            snapshot: snapshot(this.room, id, Date.now()),
          }),
        );
      } catch {
        /* close event owns connection cleanup */
      }
    }
  }
  async fetch(request: Request): Promise<Response> {
    return this.ctx.blockConcurrencyWhile(async () => {
      try {
        const [, code, route] = new URL(request.url).pathname.split("/");
        if (!code || !CODE.test(code))
          throw new RuleError("ルームが見つかりません。", 404);
        // Internal-only lookup used during the 12-character -> 5-digit rollout.
        // It never allocates a room and never exposes another owner's session.
        if (route === "recover" && request.method === "POST") {
          const input = await body(request);
          allowKeys(input, [
            "mode",
            "durationSeconds",
            "admissionKey",
            "roomCodeDigits",
          ]);
          const key = admissionKey(input.admissionKey);
          creationCodeDigits(input.roomCodeDigits);
          const prior =
            this.room &&
            creationOwner(this.room, key, input.mode, input.durationSeconds);
          if (!prior) throw new RuleError("ルームが見つかりません。", 404);
          const room = this.live();
          return json(
            {
              code,
              participantId: prior.participant.id,
              token: prior.token,
              snapshot: snapshot(room, prior.participant.id, Date.now()),
            },
            201,
          );
        }
        if (route === "create" && request.method === "POST") {
          const input = await body(request);
          allowKeys(input, [
            "mode",
            "durationSeconds",
            "admissionKey",
            "roomCodeDigits",
          ]);
          const key = admissionKey(input.admissionKey);
          creationCodeDigits(input.roomCodeDigits);
          if (this.room) {
            const prior = creationOwner(
              this.room,
              key,
              input.mode,
              input.durationSeconds,
            );
            if (!prior) {
              throw new RuleError(
                "ルームコードが重なりました。新しいコードで再試行します。",
                409,
                "ROOM_CODE_COLLISION",
              );
            }
            const room = this.live();
            return json(
              {
                code,
                participantId: prior.participant.id,
                token: prior.token,
                snapshot: snapshot(room, prior.participant.id, Date.now()),
              },
              201,
            );
          }
          const host = newMember(
            crypto.randomUUID(),
            hex(32),
            hex(4).toUpperCase(),
            "red",
            key,
          );
          await this.save(
            newRoom(code, input.mode, input.durationSeconds, host, Date.now()),
          );
          return json(
            {
              code,
              participantId: host.participant.id,
              token: host.token,
              snapshot: snapshot(this.room!, host.participant.id, Date.now()),
            },
            201,
          );
        }
        this.live();
        if (route === "join" && request.method === "POST") {
          const input = await body(request);
          allowKeys(input, ["admissionKey"]);
          const key = admissionKey(input.admissionKey);
          const prior = recoveredMember(this.room!, key, "join");
          if (prior) {
            return json(
              {
                code,
                participantId: prior.participant.id,
                token: prior.token,
                snapshot: snapshot(
                  this.room!,
                  prior.participant.id,
                  Date.now(),
                ),
              },
              201,
            );
          }
          let pairCode: string;
          do {
            pairCode = hex(4).toUpperCase();
          } while (
            Object.values(this.room!.members).some(
              (m) => m.pairCode === pairCode,
            )
          );
          const member = newMember(
            crypto.randomUUID(),
            hex(32),
            pairCode,
            "blue",
            key,
          );
          await this.update((draft, now) => joinRoom(draft, member, now));
          return json(
            {
              code,
              participantId: member.participant.id,
              token: member.token,
              snapshot: snapshot(this.room!, member.participant.id, Date.now()),
            },
            201,
          );
        }
        if (route === "socket" && request.method === "GET") {
          if (request.headers.get("upgrade")?.toLowerCase() !== "websocket")
            throw new RuleError("WebSocket接続が必要です。", 426);
          if (this.ctx.getWebSockets().length >= MAX_SOCKETS)
            throw new RuleError(
              "接続数が上限に達しました。少し待ってください。",
              429,
            );
          const pair = new WebSocketPair();
          const client = pair[0],
            server = pair[1];
          server.serializeAttachment({
            participantId: null,
            openedAt: Date.now(),
            count: 0,
            windowAt: Date.now(),
          } satisfies SocketSession);
          this.ctx.acceptWebSocket(server);
          await this.schedule();
          return new Response(null, { status: 101, webSocket: client });
        }
        const id = authenticate(this.room!, bearer(request));
        if (route === "snapshot" && request.method === "GET") {
          const draft = structuredClone(this.room!);
          if (advance(draft, Date.now())) {
            await this.save(draft);
            this.broadcast();
          }
          return json({ snapshot: snapshot(this.room!, id, Date.now()) });
        }
        if (route === "actions" && request.method === "POST") {
          const input = await body(request);
          const { requestId, ...action } = input;
          await this.update((draft, now) =>
            command(draft, id, requestId, action, now),
          );
          return json({
            snapshot: this.room!.members[id]
              ? snapshot(this.room!, id, Date.now())
              : null,
          });
        }
        throw new RuleError("未対応の接続先です。", 404);
      } catch (e) {
        return errorResponse(e);
      }
    });
  }
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer) {
    await this.ctx.blockConcurrencyWhile(async () => {
      let requestId: unknown;
      try {
        const a = this.attachment(ws);
        if (
          !a ||
          typeof message !== "string" ||
          new TextEncoder().encode(message).length > MAX_BODY
        ) {
          ws.close(1009, "送信内容を確認してください");
          return;
        }
        const now = Date.now();
        if (now - a.windowAt >= 1000) {
          a.count = 0;
          a.windowAt = now;
        }
        a.count++;
        ws.serializeAttachment(a);
        if (a.count > 30)
          throw new RuleError("操作が続いています。少し待ってください。", 429);
        let data: Record<string, unknown>;
        try {
          data = record(JSON.parse(message));
        } catch {
          throw new RuleError("送信内容を確認してください。", 400);
        }
        requestId = data.requestId;
        const room = this.live();
        if (!a.participantId) {
          allowKeys(data, ["type", "token"]);
          if (data.type !== "auth")
            throw new RuleError("参加情報の確認が必要です。", 401);
          const id = authenticate(room, data.token);
          a.participantId = id;
          ws.serializeAttachment(a);
          await this.update((draft, t) =>
            connectionChanged(draft, id, true, t),
          );
          return; // broadcast sends the personalized initial snapshot after persistence.
        }
        const id = a.participantId;
        if (!room.members[id])
          throw new RuleError("参加情報が終了しました。", 401);
        if (data.type === "ping") {
          allowKeys(data, ["type", "id"]);
          if (typeof data.id !== "string" || data.id.length > 96)
            throw new RuleError("時刻の確認情報が不正です。", 400);
          ws.send(
            JSON.stringify({
              type: "pong",
              id: data.id,
              serverNow: Date.now(),
            }),
          );
          return;
        }
        allowKeys(data, ["type", "requestId", "action"]);
        if (data.type !== "command")
          throw new RuleError("未対応の操作です。", 400);
        await this.update((draft, t) =>
          command(draft, id, data.requestId, data.action, t),
        );
        ws.send(
          JSON.stringify({
            type: "ack",
            requestId: data.requestId,
            snapshot: this.room!.members[id]
              ? snapshot(this.room!, id, Date.now())
              : null,
          }),
        );
      } catch (e) {
        try {
          ws.send(
            JSON.stringify({
              type: "error",
              requestId: typeof requestId === "string" ? requestId : undefined,
              error:
                e instanceof RuleError ? e.message : "接続処理に失敗しました。",
            }),
          );
        } catch {
          /* closed socket */
        }
        if (e instanceof RuleError && (e.status === 401 || e.status === 410))
          ws.close(1008, "接続を確認してください");
      }
    });
  }
  async webSocketClose(
    ws: WebSocket,
    code: number,
    reason: string,
    wasClean: boolean,
  ) {
    await this.disconnected(ws);
    try {
      ws.close(code === 1005 ? 1000 : code, reason);
    } catch {
      /* already closed */
    }
  }
  async webSocketError(ws: WebSocket) {
    await this.disconnected(ws);
    try {
      ws.close(1011, "再接続してください");
    } catch {
      /* already closed */
    }
  }
  private async disconnected(ws: WebSocket) {
    await this.ctx.blockConcurrencyWhile(async () => {
      const id = this.attachment(ws)?.participantId;
      // A stale tab/socket closing must not cancel a game on a newer connection.
      if (
        !id ||
        !this.room ||
        Date.now() >= this.room.expiresAt ||
        this.ctx
          .getWebSockets()
          .some(
            (other) =>
              other !== ws &&
              other.readyState === 1 &&
              this.attachment(other)?.participantId === id,
          )
      )
        return;
      await this.update((draft, now) =>
        connectionChanged(draft, id, false, now),
      );
    });
  }
  async alarm() {
    await this.ctx.blockConcurrencyWhile(async () => {
      const now = Date.now();
      for (const ws of this.ctx.getWebSockets()) {
        const a = this.attachment(ws);
        if (a && !a.participantId && now >= a.openedAt + 10_000)
          ws.close(1008, "接続確認の時間が終了しました");
      }
      if (!this.room) {
        await this.ctx.storage.deleteAll();
        return;
      }
      if (now >= this.room.expiresAt) {
        for (const ws of this.ctx.getWebSockets())
          ws.close(1001, "ルームの保存期間が終了しました");
        await this.ctx.storage.deleteAll();
        this.room = null;
        return;
      }
      await this.update((draft, t) => advance(draft, t));
    });
  }
}
