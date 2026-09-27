/** Run against `npm run dev`; exercises real HTTP + two WebSocket clients. */
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
const endpoint = process.env.TSUNAGUN_TEST_URL ?? "http://127.0.0.1:8787";
type Json = Record<string, any>;
type Session = {
  code: string;
  participantId: string;
  token: string;
  snapshot: Json;
};
const wallNow = () =>
  Date.now() + Number(process.env.TSUNAGUN_TEST_CLOCK_SKEW_MS ?? 0);
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
  assert.equal(
    response.status,
    status,
    typeof result.error === "string" ? result.error : "Unexpected HTTP status",
  );
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
  closed: { code: number; reason: string } | undefined;
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
    this.ws.addEventListener("close", (event) => {
      clearInterval(this.clockTimer);
      this.closed = { code: event.code, reason: event.reason };
    });
    this.ws.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data)) as Json;
      this.messages.push(message);
      if (message.snapshot) this.latest = message.snapshot;
      if (message.type === "pong") {
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
    this.ws.send(JSON.stringify({ type: "ping", id }));
  }
  get serverNow() {
    return this.clockBase === null ? null : this.clockBase + performance.now();
  }
  async until(serverAt: number) {
    const deadline = performance.now() + 5000;
    while (this.serverNow === null) {
      assert.ok(
        performance.now() < deadline,
        "Missing server clock calibration",
      );
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
        if (reply.type !== "ack") {
          const response = await fetch(
            `${endpoint}/rooms/${this.session.code}`,
            {
              headers: { authorization: `Bearer ${this.session.token}` },
            },
          );
          const current = (await response.json()) as Json;
          const diagnostic = (value: Json | undefined) => ({
            serverNow: value?.serverNow,
            roomStatus: value?.status,
            encounter: value?.encounter && {
              status: value.encounter.status,
              round: value.encounter.round,
              startAt: value.encounter.startAt,
              fallMs: value.encounter.fallMs,
              coop: value.encounter.coop,
              message: value.encounter.message,
            },
          });
          throw new Error(
            JSON.stringify({
              error: reply.error,
              type,
              values,
              sentAt,
              estimatedServerAtSend,
              receivedAt: wallNow(),
              before: diagnostic(before),
              after: diagnostic(current.snapshot),
            }),
          );
        }
        return reply;
      }
      await pause(10);
    }
    throw new Error(
      JSON.stringify({
        error: "Missing command acknowledgement",
        type,
        values,
        socketState: this.ws.readyState,
        closed: this.closed,
        estimatedServerAtSend,
        serverNow: this.serverNow,
        encounter: this.latest?.encounter,
        recent: this.messages.slice(-3).map((m) => ({
          type: m.type,
          error: m.error,
          serverNow: m.serverNow,
        })),
      }),
    );
  }
  close() {
    clearInterval(this.clockTimer);
    this.ws.close();
  }
}
const clients: Client[] = [];
const admission = () =>
  [...crypto.getRandomValues(new Uint8Array(32))]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
try {
  // Older Android releases omit the capability and must still receive a code
  // their twelve-hex-digit validator accepts. A newer retry recovers that room.
  const legacyKey = admission();
  const legacy = await post(
    "/rooms",
    { mode: "presentation", durationSeconds: 180, admissionKey: legacyKey },
    undefined,
    201,
  );
  assert.match(legacy.code, /^[A-F0-9]{12}$/);
  const legacyRetry = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: legacyKey,
    },
    undefined,
    201,
  );
  assert.equal(legacyRetry.code, legacy.code);
  assert.ok(
    legacyRetry.token === legacy.token,
    "Capability change must recover the same room",
  );
  const legacyGuest = await post(
    `/rooms/${legacy.code}/join`,
    { admissionKey: admission() },
    undefined,
    201,
  );
  assert.equal(legacyGuest.code, legacy.code);
  const legacyConflict = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 120,
      admissionKey: legacyKey,
    },
    undefined,
    409,
  );
  assert.equal(legacyConflict.code, undefined);
  console.log(
    "PASS: old Android creates twelve-digit rooms; new clients recover and join them without rotating credentials.",
  );

  // Find the collision locally; secrets are never logged or put in URLs.
  const seenCodes = new Map<string, string>();
  let colliding: [string, string, string] | undefined;
  for (let i = 0; i < 20_000 && !colliding; i++) {
    const key = admission();
    const hash = createHash("sha256")
      .update(`tsunagun-room-v1:${key}`)
      .digest("hex");
    const code = (Number.parseInt(hash.slice(0, 12), 16) % 100_000)
      .toString()
      .padStart(5, "0");
    const prior = seenCodes.get(code);
    if (prior && prior !== key) colliding = [prior, key, code];
    else seenCodes.set(code, key);
  }
  assert.ok(colliding, "Failed to find local birthday collision");
  const [firstKey, secondKey, shortCode] = colliding;
  const collisionOwner = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: firstKey,
    },
    undefined,
    201,
  );
  assert.equal(collisionOwner.code, shortCode);
  const occupied = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: secondKey,
    },
    undefined,
    409,
  );
  assert.equal(occupied.code, "ROOM_CODE_COLLISION");
  assert.equal(occupied.token, undefined);
  const ownerRetry = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: firstKey,
    },
    undefined,
    201,
  );
  assert.equal(ownerRetry.code, shortCode);
  assert.equal(ownerRetry.participantId, collisionOwner.participantId);
  assert.ok(
    ownerRetry.token === collisionOwner.token,
    "Collision owner retry must preserve credentials",
  );
  console.log(
    "PASS: real HTTP five-digit collision returns the explicit error code, hides credentials, and preserves the original owner's retry.",
  );

  const hostKey = admission(),
    guestKey = admission();
  const a = (await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: hostKey,
    },
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
  const recoveredHost = await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: hostKey,
    },
    undefined,
    201,
  );
  const recoveredGuest = await post(
    `/rooms/${a.code}/join`,
    { admissionKey: guestKey },
    undefined,
    201,
  );
  assert.equal(recoveredHost.code, a.code);
  assert.ok(
    recoveredHost.token === a.token,
    "Host retry must preserve credentials",
  );
  assert.equal(recoveredGuest.participantId, b.participantId);
  assert.ok(
    recoveredGuest.token === b.token,
    "Guest retry must preserve credentials",
  );
  assert.equal(recoveredGuest.snapshot.participants.length, 2);
  assert.equal(
    JSON.stringify(recoveredGuest.snapshot).includes(guestKey),
    false,
  );
  await post(
    `/rooms/${a.code}/join`,
    { admissionKey: admission() },
    undefined,
    409,
  );
  assert.match(a.code, /^\d{5}$/);
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
  assert.equal(ca.latest!.finalSnapshot.redPower, 9);
  assert.equal(cb.latest!.finalSnapshot.bluePower, 9);
  await act(a, "finale");
  await ca.wait((s) => s.finaleStartsAt !== null);
  await cb.wait((s) => s.finaleStartsAt !== null);
  assert.equal(ca.latest!.finaleStartsAt, cb.latest!.finaleStartsAt);
  console.log(
    "PASS: HTTP authorization, authenticated personalized WS, stale-socket close, both-fall bones, idempotent retry, reconnect, real alternating co-op inputs across 3 alarm-driven levels, REBORN for both, immutable synchronized finale.",
  );

  // A single real device can play a persistent bot, while the second real slot
  // stays available. Bots never own sockets or participant credentials.
  const soloSession = (await post(
    "/rooms",
    {
      mode: "presentation",
      roomCodeDigits: 5,
      durationSeconds: 180,
      admissionKey: admission(),
    },
    undefined,
    201,
  )) as Session;
  let human = new Client(soloSession);
  clients.push(human);
  await human.wait((s) => s.participants[0].connected);
  await act(soloSession, "profile", {
    profile: { nickname: "ひとり発表", hobby: "音楽", comment: "" },
  });
  await act(soloSession, "start");
  await human.wait((s) => s.status === "active");
  assert.equal(human.latest!.participants.length, 1);
  assert.equal(human.latest!.demoParticipants.length, 5);
  const originalBots = human.latest!.demoParticipants.filter(
    (p: Json) => p.playable,
  );
  const emptySeat = human.latest!.demoParticipants.find(
    (p: Json) => !p.playable,
  );
  const bot = originalBots[0];
  await act(soloSession, "pairBot", { botId: emptySeat.id }, 409);
  await act(soloSession, "pairBot", { botId: bot.id });
  let botEncounter = (
    await human.wait((s) => s.encounter?.status === "offered")
  ).encounter;
  assert.deepEqual(botEncounter.readyIds, [bot.id]);
  await act(soloSession, "ready", {
    encounterId: botEncounter.id,
    round: botEncounter.round,
  });
  botEncounter = (await human.wait((s) => s.encounter?.status === "countdown"))
    .encounter;
  await human.until(botEncounter.startAt + botEncounter.fallMs);
  const ownFall = {
    encounterId: botEncounter.id,
    round: botEncounter.round,
    at: botEncounter.startAt + botEncounter.fallMs,
    fell: true,
  };
  const fallRequest = crypto.randomUUID();
  await human.input("duelInput", ownFall, fallRequest);
  await human.wait((s) => s.encounter?.status === "finished");
  assert.equal(human.latest!.encounter.result.outcome, "loss");
  assert.equal(human.latest!.followers[0].kind, "bone");
  const beforeRetry = human.latest!.demoParticipants.find(
    (p: Json) => p.id === bot.id,
  ).power;
  await human.input("duelInput", ownFall, fallRequest);
  assert.equal(
    human.latest!.demoParticipants.find((p: Json) => p.id === bot.id).power,
    beforeRetry,
  );
  await act(soloSession, "return", { encounterId: botEncounter.id });
  await act(soloSession, "pairBot", { botId: bot.id });
  botEncounter = (await human.wait((s) => s.encounter?.kind === "coop"))
    .encounter;
  await act(soloSession, "ready", {
    encounterId: botEncounter.id,
    round: botEncounter.round,
  });
  botEncounter = (await human.wait((s) => s.encounter?.status === "countdown"))
    .encounter;
  for (let level = 0; level < 3; level++) {
    const current = await human.wait(
      (s) => s.encounter?.coop.level === level && s.encounter?.startAt !== null,
    );
    botEncounter = current.encounter;
    const flight = [1000, 800, 650][level]!;
    for (let hop = 1; hop <= 5; hop += 2) {
      const at =
        botEncounter.coop.levelStartAt + flight * 1.3 + (hop - 1) * flight;
      await human.until(at);
      await human.input("coopInput", {
        encounterId: botEncounter.id,
        round: botEncounter.round,
        level,
        hop,
        at,
        miss: false,
      });
      // The real app cannot move on until the server publishes the bot's
      // even turn. Observe that alarm-driven input before sending our next tap.
      await human.wait(
        (s) =>
          s.encounter?.id === botEncounter.id &&
          s.encounter.coop.level === level &&
          s.encounter.coop.hop >= hop + 2,
        flight + 1500,
      );
    }
    if (level < 2)
      await human.wait((s) => s.encounter?.coop.level === level + 1, 6000);
  }
  await human.wait((s) => s.encounter?.status === "finished");
  assert.equal(human.latest!.encounter.result.outcome, "coopSuccess");
  assert.equal(human.latest!.encounter.result.delta, 2);
  assert.equal(human.latest!.followers.length, 1);
  assert.equal(human.latest!.followers[0].kind, "normal");
  assert.equal(
    human.latest!.demoParticipants.find((p: Json) => p.id === bot.id).power,
    beforeRetry + 2,
  );
  await act(soloSession, "return", { encounterId: botEncounter.id });
  await act(soloSession, "pairBot", { botId: bot.id }, 409);

  // Two simultaneous fresh admissions compete for exactly one real slot.
  // The response-loss retry of the winner still recovers that same player.
  const beforeJoin = human.latest!.demoParticipants.filter(
    (p: Json) => p.playable,
  );
  const races = await Promise.all(
    [admission(), admission()].map(async (key) => {
      const response = await fetch(
        `${endpoint}/rooms/${soloSession.code}/join`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ admissionKey: key }),
        },
      );
      return {
        status: response.status,
        key,
        data: (await response.json()) as Json,
      };
    }),
  );
  assert.deepEqual(races.map((r) => r.status).sort(), [201, 409]);
  const winner = races.find((r) => r.status === 201)!;
  const lateSession = winner.data as Session;
  const recoveredLate = await post(
    `/rooms/${soloSession.code}/join`,
    { admissionKey: winner.key },
    undefined,
    201,
  );
  assert.equal(recoveredLate.participantId, lateSession.participantId);
  assert.ok(
    recoveredLate.token === lateSession.token,
    "Late admission retry preserves credentials",
  );
  assert.deepEqual(
    recoveredLate.snapshot.demoParticipants.map((p: Json) => ({
      id: p.id,
      power: p.power,
    })),
    beforeJoin.map((p: Json) => ({ id: p.id, power: p.power })),
  );
  assert.equal(recoveredLate.snapshot.demoParticipants.length, 4);
  const late = new Client(lateSession);
  clients.push(late);
  await late.wait((s) => s.participants.every((p: Json) => p.connected));
  await act(
    soloSession,
    "pair",
    { peerCode: lateSession.snapshot.pairCode },
    409,
  );
  await act(lateSession, "pairBot", { botId: originalBots[1].id }, 409);
  const lateProfileId = crypto.randomUUID();
  const lateProfile = {
    requestId: lateProfileId,
    type: "profile",
    profile: { nickname: "途中参加", hobby: "映画", comment: "" },
  };
  await post(`/rooms/${soloSession.code}/actions`, lateProfile, lateSession);
  await post(`/rooms/${soloSession.code}/actions`, lateProfile, lateSession);
  await act(
    lateSession,
    "profile",
    { profile: { nickname: "上書き", hobby: "映画", comment: "" } },
    409,
  );

  // A disconnected owner's unresolved bot is released. Returning from that
  // old encounter must not release the next player's newer reservation.
  const secondBotId = originalBots[1].id;
  await act(soloSession, "pairBot", { botId: secondBotId });
  const oldEncounter = (
    await human.wait((s) => s.encounter?.status === "offered")
  ).encounter;
  await act(lateSession, "pairBot", { botId: secondBotId }, 409);
  human.close();
  await late.wait(
    (s) =>
      !s.participants.find((p: Json) => p.id === soloSession.participantId)
        .connected,
  );
  await act(lateSession, "pairBot", { botId: secondBotId });
  const lateEncounter = (
    await late.wait((s) => s.encounter?.status === "offered")
  ).encounter;
  human = new Client(soloSession);
  clients.push(human);
  await human.wait((s) => s.encounter?.status === "cancelled");
  await act(soloSession, "return", { encounterId: oldEncounter.id });
  await human.wait((s) => s.encounter === null);
  assert.equal(
    human.latest!.demoParticipants.find((p: Json) => p.id === secondBotId).busy,
    true,
  );
  await act(lateSession, "cancel", { encounterId: lateEncounter.id });
  await act(lateSession, "return", { encounterId: lateEncounter.id });
  await act(soloSession, "finish");
  await human.wait((s) => s.status === "finale");
  const final = human.latest!.finalSnapshot;
  assert.equal(final.rankings.length, 6);
  assert.equal(
    final.rankings.filter((r: Json) => r.participant.isDemo).length,
    4,
  );
  const demos = human.latest!.demoParticipants;
  const powerFor = (team: string) =>
    demos
      .filter((p: Json) => p.team === team)
      .reduce((n: number, p: Json) => n + p.power, 0);
  assert.equal(final.redPower, powerFor("red") + 3);
  assert.equal(final.bluePower, powerFor("blue"));
  await post(
    `/rooms/${soloSession.code}/join`,
    { admissionKey: admission() },
    undefined,
    409,
  );
  console.log(
    "PASS: solo start, server-owned bot duel and all cooperative turns, human REBORN, changing bot inventory, concurrent late admission, admission recovery, profile gating, bot reservation release, six-person final rankings.",
  );
} finally {
  for (const c of clients) c.close();
}
