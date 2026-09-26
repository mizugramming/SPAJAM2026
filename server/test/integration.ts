/** Run against `npm run dev`; exercises real HTTP + two WebSocket clients. */
import assert from "node:assert/strict";
const endpoint = process.env.TSUNAGUN_TEST_URL ?? "http://127.0.0.1:8787";
type Json = Record<string, any>;
type Session = {
  code: string;
  participantId: string;
  token: string;
  snapshot: Json;
};
const wallNow = () => Date.now() + Number(process.env.TSUNAGUN_TEST_CLOCK_SKEW_MS ?? 0);
const pause = (ms: number) => new Promise((r) => setTimeout(r, ms));
async function post(
  path: string,
  data: Json,
  session?: Session,
  status = 200,
): Promise<Json> {
  const response = await fetch(endpoint + path, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(session ? { authorization: `Bearer ${session.token}` } : {}),
    },
    body: JSON.stringify(data),
  });
  const result = (await response.json()) as Json;
  assert.equal(response.status, status, typeof result.error === "string" ? result.error : "Unexpected HTTP status");
  return result;
}
async function act(s: Session, type: string, values: Json = {}, status = 200) {
  return post(
    `/rooms/${s.code}/actions`,
    { requestId: crypto.randomUUID(), type, ...values },
    s,
    status,
  );
}
class Client {
  ws: WebSocket;
  latest: Json | undefined;
  messages: Json[] = [];
  private readonly pings = new Map<string, number>();
  private clockBase: number | null = null;
  private clockTimer: ReturnType<typeof setInterval> | undefined;
  constructor(public session: Session) {
    this.ws = new WebSocket(
      `${endpoint.replace(/^http/, "ws")}/rooms/${session.code}/socket`,
    );
    this.ws.addEventListener("open", () => {
      this.ws.send(JSON.stringify({ type: "auth", token: session.token }));
      this.ping();
      this.clockTimer = setInterval(() => this.ping(), 2000);
    });
    this.ws.addEventListener('close', () => clearInterval(this.clockTimer));
    this.ws.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data)) as Json;
      this.messages.push(message);
      if (message.snapshot) this.latest = message.snapshot;
      if (message.type === 'pong') {
        const sent = this.pings.get(message.id);
        this.pings.delete(message.id);
        const received = performance.now();
        if (sent !== undefined && received - sent < 1000) {
          this.clockBase = message.serverNow + (received - sent) / 2 - received;
        }
      }
    });
  }
  private ping() {
    if (this.ws.readyState !== WebSocket.OPEN) return;
    const id = crypto.randomUUID();
    this.pings.set(id, performance.now());
    this.ws.send(JSON.stringify({ type: 'ping', id }));
  }
  get serverNow() {
    return this.clockBase === null ? null : this.clockBase + performance.now();
  }
  async until(serverAt: number) {
    const deadline = performance.now() + 5000;
    while (this.serverNow === null) {
      assert.ok(performance.now() < deadline, 'Missing server clock calibration');
      await pause(10);
    }
    // Use the same midpoint-corrected server clock as the app. The Node host's
    // wall clock may differ from Cloudflare or jump while a WSL VM is loaded.
    while (this.serverNow! < serverAt) {
      await pause(Math.min(50, serverAt - this.serverNow!));
    }
  }
  async wait(
    predicate: (snapshot: Json) => boolean,
    timeout = 7000,
  ): Promise<Json> {
    const end = performance.now() + timeout;
    while (performance.now() < end) {
      if (this.latest && predicate(this.latest)) return this.latest;
      await pause(10);
    }
    throw new Error(
      `WS timeout: ${JSON.stringify(this.latest)} / ${JSON.stringify(this.messages.slice(-3))}`,
    );
  }
  async input(type: string, values: Json, requestId = crypto.randomUUID()) {
    const sentAt = wallNow();
    const before = this.latest;
    const estimatedServerAtSend = this.serverNow;
    this.ws.send(
      JSON.stringify({
        type: "command",
        requestId,
        action: { type, ...values },
      }),
    );
    const end = performance.now() + 5000;
    while (performance.now() < end) {
      const reply = this.messages.find(
        (m) =>
          (m.type === "ack" || m.type === "error") && m.requestId === requestId,
      );
      if (reply) {
        if (reply.type !== 'ack') {
          const response = await fetch(`${endpoint}/rooms/${this.session.code}`, {
            headers: { authorization: `Bearer ${this.session.token}` },
          });
          const current = (await response.json()) as Json;
          const diagnostic = (value: Json | undefined) => ({
            serverNow: value?.serverNow,
            roomStatus: value?.status,
            encounter: value?.encounter && {
              status: value.encounter.status, round: value.encounter.round,
              startAt: value.encounter.startAt, fallMs: value.encounter.fallMs,
              coop: value.encounter.coop, message: value.encounter.message,
            },
          });
          throw new Error(JSON.stringify({ error: reply.error, type, values,
            sentAt, estimatedServerAtSend, receivedAt: wallNow(), before: diagnostic(before),
            after: diagnostic(current.snapshot) }));
        }
        return reply;
      }
      await pause(10);
    }
    throw new Error("Missing command acknowledgement");
  }
  close() {
    clearInterval(this.clockTimer);
    this.ws.close();
  }
}
const clients: Client[] = [];
const admission = () => [...crypto.getRandomValues(new Uint8Array(32))]
  .map(value => value.toString(16).padStart(2, '0')).join('');
try {
  const hostKey = admission(), guestKey = admission();
  const a = (await post(
    "/rooms",
    { mode: "presentation", durationSeconds: 180, admissionKey: hostKey },
    undefined,
    201,
  )) as Session;
  const b = (await post(
    `/rooms/${a.code}/join`,
    { admissionKey: guestKey },
    undefined,
    201,
  )) as Session;
  // Simulate losing both initial responses: retries recover the same secrets
  // instead of making another room or consuming a third guest slot.
  const recoveredHost = await post('/rooms', { mode: 'presentation', durationSeconds: 180, admissionKey: hostKey }, undefined, 201);
  const recoveredGuest = await post(`/rooms/${a.code}/join`, { admissionKey: guestKey }, undefined, 201);
  assert.equal(recoveredHost.code, a.code);
  assert.ok(recoveredHost.token === a.token, "Host retry must preserve credentials");
  assert.equal(recoveredGuest.participantId, b.participantId);
  assert.ok(recoveredGuest.token === b.token, "Guest retry must preserve credentials");
  assert.equal(recoveredGuest.snapshot.participants.length, 2);
  assert.equal(JSON.stringify(recoveredGuest.snapshot).includes(guestKey), false);
  await post(`/rooms/${a.code}/join`, { admissionKey: admission() }, undefined, 409);
  assert.match(a.code, /^[A-F0-9]{12}$/);
  assert.equal((await fetch(`${endpoint}/rooms/${a.code}`)).status, 401);
  await post(
    `/rooms/${a.code}/actions`,
    { requestId: "forged", type: "finish" },
    { ...a, token: "0".repeat(64) },
    401,
  );
  let ca = new Client(a);
  let cb = new Client(b);
  clients.push(ca, cb);
  await ca.wait((s) => s.participants.every((p: Json) => p.connected));
  await cb.wait((s) => s.participants.every((p: Json) => p.connected));
  for (const [s, name] of [
    [a, "あか"],
    [b, "あお"],
  ] as const)
    await act(s, "profile", {
      profile: { nickname: name, hobby: "音楽", comment: "よろしく！" },
    });
  await act(b, "start", {}, 403);
  await act(a, "start");
  await act(a, "pair", { peerCode: b.snapshot.pairCode });
  const offered = await cb.wait((s) => s.encounter?.status === "offered");
  let e = offered.encounter;
  // Replacing a socket must not let its later close cancel the newer connection.
  const previous = ca;
  ca = new Client(a);
  clients.push(ca);
  await ca.wait((s) => s.encounter?.id === e.id);
  previous.close();
  await pause(200);
  assert.equal(ca.latest!.encounter.status, "offered");
  for (const s of [a, b])
    await act(s, "ready", { encounterId: e.id, round: e.round });
  e = (await ca.wait((s) => s.encounter?.status === "countdown")).encounter;
  await ca.until(e.startAt + e.fallMs);
  const input = {
    encounterId: e.id,
    round: e.round,
    at: e.startAt + e.fallMs,
    fell: true,
  };
  const id = crypto.randomUUID();
  await Promise.all([
    ca.input("duelInput", input, id),
    cb.input("duelInput", input),
  ]);
  await ca.wait((s) => s.encounter?.status === "finished");
  await cb.wait((s) => s.encounter?.status === "finished");
  for (const c of [ca, cb]) {
    assert.equal(c.latest!.followers.length, 1);
    assert.equal(c.latest!.encounter.result.outcome, "loss");
    assert.equal(c.latest!.followers[0].kind, "bone");
  }
  await ca.input("duelInput", input, id);
  assert.equal(ca.latest!.followers.length, 1);
  cb.close();
  cb = new Client(b);
  clients.push(cb);
  await cb.wait((s) => s.encounter?.status === "finished");
  assert.equal(cb.latest!.encounter.result.delta, 1);
  for (const s of [a, b]) await act(s, "return", { encounterId: e.id });
  await act(a, "pair", { peerCode: b.snapshot.pairCode });
  e = (await ca.wait((s) => s.encounter?.kind === "coop")).encounter;
  for (const s of [a, b])
    await act(s, "ready", { encounterId: e.id, round: e.round });
  e = (await ca.wait((s) => s.encounter?.status === "countdown")).encounter;
  for (let level = 0; level < 3; level++) {
    const snap = await ca.wait(
      (s) => s.encounter?.coop.level === level && s.encounter?.startAt !== null,
    );
    e = snap.encounter;
    const flight = [1000, 800, 650][level]!;
    for (let hop = 1; hop <= 6; hop++) {
      const at = e.coop.levelStartAt + flight * 1.3 + (hop - 1) * flight;
      const sender = e.playerIds[(hop - 1) % 2] === a.participantId ? ca : cb;
      await sender.until(at);
      await sender.input("coopInput", {
        encounterId: e.id,
        round: e.round,
        level,
        hop,
        at,
        miss: false,
      });
    }
    if (level < 2)
      await ca.wait((s) => s.encounter?.coop.level === level + 1, 6000);
  }
  await ca.wait((s) => s.encounter?.status === "finished");
  await cb.wait((s) => s.encounter?.status === "finished");
  for (const c of [ca, cb]) {
    assert.equal(c.latest!.followers.length, 1);
    assert.equal(c.latest!.encounter.result.outcome, "coopSuccess");
    assert.equal(c.latest!.encounter.result.delta, 2);
    assert.equal(c.latest!.followers[0].kind, "normal");
  }
  await act(a, "finish");
  await Promise.all([
    ca.wait((s) => s.status === "finale" && s.finalSnapshot !== null),
    cb.wait((s) => s.status === "finale" && s.finalSnapshot !== null),
  ]);
  assert.equal(ca.latest!.finalSnapshot.redPower, 3);
  assert.equal(cb.latest!.finalSnapshot.bluePower, 3);
  await act(a, "finale");
  await ca.wait((s) => s.finaleStartsAt !== null);
  await cb.wait((s) => s.finaleStartsAt !== null);
  assert.equal(ca.latest!.finaleStartsAt, cb.latest!.finaleStartsAt);
  console.log(
    "PASS: HTTP authorization, authenticated personalized WS, stale-socket close, both-fall bones, idempotent retry, reconnect, real alternating co-op inputs across 3 alarm-driven levels, REBORN for both, immutable synchronized finale.",
  );
} finally {
  for (const c of clients) c.close();
}
