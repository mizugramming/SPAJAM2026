import test from "node:test";
import assert from "node:assert/strict";
import {
  advance,
  authenticate,
  command,
  connectionChanged,
  joinRoom,
  newMember,
  newRoom,
  nextAlarm,
  snapshot,
  validateProfile,
  INPUT_LAG,
  ROOM_TTL,
  type RoomState,
  type Action,
  type Encounter,
} from "../src/room";
const base = 1_000_000;
let sequence = 0;
function action(
  s: RoomState,
  id: string,
  type: string,
  values: Record<string, unknown> = {},
  now = base,
  requestId = `req${++sequence}`,
) {
  advance(s, now);
  return command(s, id, requestId, { type, ...values }, now);
}
function fixture(
  mode: "standard" | "presentation" = "presentation",
  count = 2,
) {
  const s = newRoom(
    "123456ABCDEF",
    mode,
    180,
    newMember("a", "a".repeat(64), "AAAAAAAA", "red"),
    base,
  );
  for (let i = 1; i < count; i++)
    joinRoom(
      s,
      newMember(
        String.fromCharCode(97 + i),
        String.fromCharCode(97 + i).repeat(64),
        String(i).repeat(8),
        "blue",
      ),
      base,
    );
  for (const id of Object.keys(s.members)) {
    action(s, id, "profile", {
      profile: { nickname: id, hobby: "音楽", comment: "" },
    });
    connectionChanged(s, id, true, base);
  }
  action(s, "a", "start");
  return s;
}
function pair(s: RoomState, a = "a", b = "b", now = base): Encounter {
  action(s, a, "pair", { peerCode: s.members[b]!.pairCode }, now);
  return s.encounters[s.members[a]!.encounterId!]!;
}
function start(s: RoomState, e: Encounter, now = base) {
  for (const id of e.playerIds)
    action(s, id, "ready", { encounterId: e.id, round: e.round }, now);
  advance(s, e.startAt!);
  return e.startAt!;
}
function duel(
  s: RoomState,
  e: Encounter,
  left: number | null,
  right: number | null,
) {
  const startAt = start(s, e);
  const inputs = e.playerIds
    .map((id, i) => ({ id, time: i === 0 ? left : right }))
    .sort((a, b) => (a.time ?? 1800) - (b.time ?? 1800));
  for (const input of inputs)
    action(
      s,
      input.id,
      "duelInput",
      {
        encounterId: e.id,
        round: e.round,
        at: startAt + (input.time ?? 1800),
        fell: input.time === null,
      },
      startAt + (input.time ?? 1800),
    );
}
function home(s: RoomState, e: Encounter, now = base + 10_000) {
  for (const id of e.playerIds)
    action(s, id, "return", { encounterId: e.id }, now);
}
function winCoop(s: RoomState, e: Encounter, now = base + 10_000) {
  start(s, e, now);
  for (let level = 0; level < 3; level++) {
    const flight = [1000, 800, 650][level]!;
    for (let hop = 1; hop <= 6; hop++) {
      const at = e.coop.levelStartAt + flight * 1.3 + (hop - 1) * flight;
      action(
        s,
        e.playerIds[(hop - 1) % 2]!,
        "coopInput",
        { encounterId: e.id, round: e.round, level, hop, at, miss: false },
        at,
      );
    }
    advance(s, e.coop.clearedAt!);
  }
}

test("create validates mode/duration and initial profile is empty", () => {
  const host = newMember("a", "a".repeat(64), "AAAAAAAA", "red");
  assert.throws(() => newRoom("123456ABCDEF", "fake", 180, host, base));
  assert.throws(() => newRoom("123456ABCDEF", "standard", 1, host, base));
  assert.equal(host.participant.profile.nickname, "");
  const s = newRoom("123456ABCDEF", "standard", 180, host, base);
  assert.equal(s.expiresAt, base + ROOM_TTL);
});
test("profiles validate graphemes, required fields and control characters", () => {
  assert.equal(
    validateProfile({ nickname: "👩‍👩‍👧‍👧".repeat(20), hobby: " 雑貨 ", comment: "" })
      .hobby,
    "雑貨",
  );
  for (const profile of [
    { nickname: "a".repeat(21), hobby: "x", comment: "" },
    { nickname: "a", hobby: "", comment: "" },
    { nickname: "a", hobby: "x", comment: "\n" },
    { nickname: "a", hobby: "x", comment: "x\u0000" },
  ]) {
    // Leading/trailing whitespace is trimmed; embedded controls remain forbidden.
    if (profile.comment === "\n") continue;
    assert.throws(() => validateProfile(profile));
  }
});
test("unauthorized token rejected and snapshots do not leak secrets or other followers", () => {
  const s = fixture();
  const e = pair(s);
  duel(s, e, 1700, 1500);
  assert.throws(() => authenticate(s, "0".repeat(64)));
  assert.equal(authenticate(s, "a".repeat(64)), "a");
  const snap = snapshot(s, "a", base);
  const encoded = JSON.stringify(snap);
  assert.ok(!encoded.includes("a".repeat(64)));
  assert.ok(!encoded.includes('pairCode":"11111111'));
  assert.equal(snap.followers.length, 1);
  assert.equal(snap.followers[0]!.ownerId, "a");
  assert.equal(snap.encounter!.result!.outcome, "win");
  assert.ok(!("results" in snap.encounter!));
});
test("host-only room actions and lobby complete profiles enforced", () => {
  const s = fixture();
  assert.throws(() => action(s, "b", "finish"));
  assert.throws(() =>
    action(s, "a", "profile", {
      profile: { nickname: "x", hobby: "x", comment: "" },
    }),
  );
  assert.throws(() =>
    joinRoom(s, newMember("c", "c".repeat(64), "CCCCCCCC", "red"), base),
  );
});
test("standard team balance supports simultaneous independent encounters and spectator privacy", () => {
  const s = fixture("standard", 4);
  assert.deepEqual(
    Object.values(s.members).map((m) => m.participant.team),
    ["red", "blue", "red", "blue"],
  );
  const e = pair(s, "a", "b");
  const other = pair(s, "c", "d");
  assert.notEqual(e.id, other.id);
  assert.equal(snapshot(s, "c", base).encounter!.id, other.id);
  assert.throws(() => action(s, "c", "cancel", { encounterId: e.id }));
});
test("both falling awards exactly one bone to each with no rematch", () => {
  const s = fixture();
  const e = pair(s);
  duel(s, e, null, null);
  assert.equal(e.status, "finished");
  for (const id of e.playerIds) {
    assert.equal(e.results[id]!.outcome, "loss");
    assert.equal(s.members[id]!.followers[0]!.kind, "bone");
  }
  home(s, e);
  assert.equal(pair(s, "a", "b", base + 10_000).kind, "coop");
});
test("safe exact tie gives no reward and both simultaneous ready presses start a fresh round", () => {
  const s = fixture();
  const e = pair(s);
  duel(s, e, 1500, 1500);
  assert.equal(e.status, "draw");
  assert.equal(s.members.a!.followers.length, 0);
  assert.equal(s.completed.length, 0);
  const round = e.round;
  for (const id of e.playerIds)
    action(s, id, "ready", { encounterId: e.id, round }, base + 6000);
  assert.equal(e.round, 2);
  assert.equal(e.status, "countdown");
  assert.deepEqual(e.decisions, {});
  assert.throws(() =>
    action(
      s,
      "a",
      "duelInput",
      { encounterId: e.id, round: 1, at: e.startAt! + 1000, fell: false },
      e.startAt! + 1000,
    ),
  );
});
test("duel ranking uses server-computed depth and validates fall/timestamp payload", () => {
  const s = fixture();
  const e = pair(s);
  const t = start(s, e);
  assert.throws(() =>
    action(
      s,
      "a",
      "duelInput",
      { encounterId: e.id, round: 1, at: t + 100, fell: true },
      t + 100,
    ),
  );
  assert.throws(() =>
    action(
      s,
      "a",
      "duelInput",
      { encounterId: e.id, round: 1, at: t + 1799, fell: false, depth: 1 },
      t + 1799,
    ),
  );
  action(
    s,
    "a",
    "duelInput",
    { encounterId: e.id, round: 1, at: t + 1700, fell: false },
    t + 1700,
  );
  action(
    s,
    "b",
    "duelInput",
    { encounterId: e.id, round: 1, at: t + 1600, fell: false },
    t + 1750,
  );
  assert.equal(e.results.a!.outcome, "win");
  assert.equal(e.decisions.a!.depth, (1700 / 1800) ** 2);
});
test("same request replay is idempotent across transports; changed payload with same ID rejected", () => {
  const s = fixture();
  const e = pair(s);
  const t = start(s, e);
  const value = { encounterId: e.id, round: 1, at: t + 1500, fell: false };
  action(s, "a", "duelInput", value, t + 1500, "same");
  action(s, "b", "duelInput", { ...value, at: t + 1600 }, t + 1600);
  assert.equal(action(s, "a", "duelInput", value, t + 1700, "same"), false);
  assert.equal(s.members.a!.followers.length, 1);
  assert.equal(
    command(s, "a", "same", { ...value, type: "duelInput" }, t + 1700),
    false,
  );
  assert.throws(() =>
    action(s, "a", "duelInput", { ...value, fell: true }, t + 1700, "same"),
  );
});
test("new IDs cannot reverse a settled duel or award repeated rewards", () => {
  const s = fixture();
  const e = pair(s);
  duel(s, e, null, 1600);
  action(
    s,
    "a",
    "duelInput",
    { encounterId: e.id, round: 1, at: e.startAt! + 1700, fell: false },
    e.startAt! + 1800,
  );
  assert.equal(e.results.a!.outcome, "loss");
  assert.equal(s.members.a!.followers.length, 1);
});
test("standard completed pair is blocked even if only an existing bone was revived", () => {
  const s = fixture("standard", 3);
  const d = pair(s);
  duel(s, d, null, 1600);
  home(s, d);
  const c = pair(s, "a", "c", base + 10_000);
  assert.equal(c.kind, "coop");
  winCoop(s, c);
  assert.equal(c.results.a!.delta, 2);
  assert.equal(c.results.a!.newFollower, null);
  assert.equal(s.members.a!.followers.length, 1);
  home(s, c, base + 50_000);
  assert.throws(() => pair(s, "a", "c", base + 50_000));
});
test("presentation coop revives own oldest bone while bone-free peer gains one normal follower", () => {
  const s = fixture();
  const d = pair(s);
  duel(s, d, null, 1600);
  home(s, d);
  const c = pair(s, "a", "b", base + 10_000);
  winCoop(s, c);
  assert.equal(c.results.a!.promoted!.kind, "normal");
  assert.equal(c.results.a!.delta, 2);
  assert.equal(c.results.a!.promoted!.revivedWith!.id, "b");
  assert.equal(s.members.a!.followers.length, 1);
  assert.equal(c.results.b!.newFollower!.kind, "normal");
  assert.equal(s.members.b!.followers.length, 2);
  home(s, c, base + 50_000);
  assert.throws(() => pair(s, "a", "b", base + 50_000));
});
test("cooperative real miss gives both bones; partner cannot input the other side", () => {
  const s = fixture("standard", 3);
  const e = pair(s, "a", "c");
  const t = start(s, e);
  assert.throws(() =>
    action(
      s,
      "c",
      "coopInput",
      {
        encounterId: e.id,
        round: 1,
        level: 0,
        hop: 1,
        at: t + 1300,
        miss: false,
      },
      t + 1300,
    ),
  );
  action(
    s,
    "a",
    "coopInput",
    { encounterId: e.id, round: 1, level: 0, hop: 1, at: t + 1600, miss: true },
    t + 1600,
  );
  assert.equal(e.results.a!.outcome, "coopFailure");
  assert.equal(e.results.c!.outcome, "coopFailure");
  assert.equal(e.coop.failedAt, t + 1600);
});
test("delayed duplicate cooperative hits cannot fail the next hop and cannot advance multiple hops", () => {
  const s = fixture("standard", 3);
  const e = pair(s, "a", "c");
  const t = start(s, e);
  const a = {
    encounterId: e.id,
    round: 1,
    level: 0,
    hop: 1,
    at: t + 1300,
    miss: false,
  };
  action(s, "a", "coopInput", a, t + 1300);
  action(s, "a", "coopInput", a, t + 1500);
  assert.equal(e.coop.hop, 2);
  assert.equal(e.coop.hits.length, 1);
});
test("missing duel/co-op inputs cancel without any reward", () => {
  for (const coop of [false, true]) {
    const s = fixture("standard", 3);
    const e = pair(s, "a", coop ? "c" : "b");
    const t = start(s, e);
    advance(s, t + (coop ? 1300 + 230 : 1800) + INPUT_LAG + 1);
    assert.equal(e.status, "cancelled");
    assert.equal(s.members.a!.followers.length, 0);
  }
});
test("disconnect cancels uncompleted encounter; reconnect can pair again after both return", () => {
  const s = fixture();
  const e = pair(s);
  start(s, e);
  connectionChanged(s, "b", false, base + 3200);
  assert.equal(e.status, "cancelled");
  assert.equal(s.completed.length, 0);
  connectionChanged(s, "b", true, base + 4000);
  home(s, e);
  assert.equal(pair(s, "a", "b", base + 10_000).kind, "duel");
});
test("disconnect after settlement and one player returning preserves the other result", () => {
  const s = fixture();
  const e = pair(s);
  duel(s, e, 1700, 1600);
  connectionChanged(s, "b", false, base + 5000);
  action(s, "a", "return", { encounterId: e.id }, base + 6000);
  assert.equal(
    snapshot(s, "b", base + 6000).encounter!.result!.outcome,
    "loss",
  );
  assert.equal(e.status, "finished");
});
test("closing allows in-flight settlement and freezes consistent final ranks once", () => {
  const s = fixture();
  const e = pair(s);
  const t = start(s, e);
  action(s, "a", "finish", {}, t + 500);
  assert.equal(s.status, "closing");
  assert.throws(() => pair(s, "a", "b", t + 600));
  for (const id of e.playerIds)
    action(
      s,
      id,
      "duelInput",
      { encounterId: e.id, round: 1, at: t + 1800, fell: true },
      t + 1800,
    );
  assert.equal(s.status, "finale");
  assert.equal(s.finalSnapshot!.redPower, 1);
  assert.equal(s.finalSnapshot!.bluePower, 1);
  assert.deepEqual(
    s.finalSnapshot!.rankings.map((r) => r.rank),
    [1, 1],
  );
  const final = JSON.stringify(s.finalSnapshot);
  action(s, "a", "finale", {}, t + 2000);
  const startAt = s.finaleStartsAt;
  action(s, "a", "finale", {}, t + 3000);
  assert.equal(s.finaleStartsAt, startAt);
  advance(s, startAt! + 13_000);
  assert.equal(s.status, "ended");
  assert.equal(JSON.stringify(s.finalSnapshot), final);
});
test("deadline grace never converts unfinished game or offered pair into a loss", () => {
  const s = fixture();
  const e = pair(s, "a", "b", s.endsAt! - 1000);
  advance(s, s.endsAt!);
  assert.equal(s.status, "closing");
  advance(s, s.closingAt!);
  assert.equal(e.status, "cancelled");
  assert.equal(s.finalSnapshot!.redPower, 0);
  assert.equal(s.finalSnapshot!.bluePower, 0);
  assert.deepEqual(s.finalSnapshot!.mvpIds, []);
});
test("state rehydration preserves request IDs, pending decisions and same personalized result", () => {
  let s = fixture();
  let e = pair(s);
  const t = start(s, e);
  action(
    s,
    "a",
    "duelInput",
    { encounterId: e.id, round: 1, at: t + 1500, fell: false },
    t + 1500,
    "persisted",
  );
  s = JSON.parse(JSON.stringify(s));
  e = s.encounters[e.id]!;
  action(
    s,
    "b",
    "duelInput",
    { encounterId: e.id, round: 1, at: t + 1600, fell: false },
    t + 1600,
  );
  assert.equal(e.results.a!.outcome, "loss");
  assert.ok(s.requests["a:persisted"]);
  assert.ok(nextAlarm(s, t + 1600) > t + 1600);
});
