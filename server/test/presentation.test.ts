import test from "node:test";
import assert from "node:assert/strict";
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
  snapshot,
  type RoomState,
  type Encounter,
} from "../src/room";
const base = 1_000_000;
let seq = 0;
const profile = { nickname: "あか", hobby: "音楽", comment: "" };
function act(
  s: RoomState,
  id: string,
  type: string,
  fields: Record<string, unknown> = {},
  now = base,
  requestId = `p${++seq}`,
) {
  advance(s, now);
  return command(s, id, requestId, { type, ...fields }, now);
}
function solo(start = true) {
  const s = newRoom(
    "123456ABCDEF",
    "presentation",
    180,
    newMember("host", "a".repeat(64), "AAAAAAAA", "red"),
    base,
  );
  act(s, "host", "profile", { profile });
  connectionChanged(s, "host", true, base);
  if (start) act(s, "host", "start");
  return s;
}
function guest(s: RoomState, now = base) {
  const m = newMember("guest", "b".repeat(64), "BBBBBBBB", "red");
  joinRoom(s, m, now);
  connectionChanged(s, "guest", true, now);
  return m;
}
function readyGuest(s: RoomState, now = base) {
  guest(s, now);
  act(
    s,
    "guest",
    "profile",
    { profile: { ...profile, nickname: "あお" } },
    now,
  );
}
function botPair(
  s: RoomState,
  human = "host",
  botId = Object.keys(s.bots!)[0]!,
  now = base,
) {
  act(s, human, "pairBot", { botId }, now);
  return s.encounters[s.members[human]!.encounterId!]!;
}
function ready(s: RoomState, e: Encounter, now = base) {
  act(s, e.playerIds[0], "ready", { encounterId: e.id, round: e.round }, now);
  advance(s, e.startAt!);
  return e.startAt!;
}
function lose(s: RoomState, e: Encounter, now = base) {
  const at = ready(s, e, now) + 1800;
  act(
    s,
    e.playerIds[0],
    "duelInput",
    { encounterId: e.id, round: e.round, at, fell: true },
    at,
  );
  assert.equal(e.status, "finished");
}
function returnHome(s: RoomState, e: Encounter, now = base + 5000) {
  act(s, e.playerIds[0], "return", { encounterId: e.id }, now);
}
function winCoop(s: RoomState, e: Encounter, now: number) {
  ready(s, e, now);
  for (let level = 0; level < 3; level++) {
    const flight = [1000, 800, 650][level]!;
    for (let hop = 1; hop <= 6; hop++) {
      const at = e.coop.levelStartAt + 1.3 * flight + (hop - 1) * flight;
      if (hop % 2 === 1)
        act(
          s,
          e.playerIds[0],
          "coopInput",
          { encounterId: e.id, round: e.round, level, hop, at, miss: false },
          at,
        );
      else {
        assert.equal(nextAlarm(s, at - 1), at);
        advance(s, at);
      }
    }
    advance(s, e.coop.clearedAt!);
  }
}

test("presentation displays six balanced seats, persistent four inventories and an unplayable empty seat", () => {
  const s = solo(false);
  const before = JSON.stringify(s);
  const snap = snapshot(s, "host", base);
  assert.equal(snap.demoParticipants.length, 5);
  for (const team of ["red", "blue"]) {
    assert.equal(
      [...snap.participants, ...snap.demoParticipants].filter(
        (p) => p.team === team,
      ).length,
      3,
    );
    assert.equal(
      snap.demoParticipants
        .filter((p) => p.team === team)
        .reduce((n, p) => n + p.power, 0),
      6,
    );
  }
  assert.equal(snap.demoParticipants.filter((p) => p.playable).length, 4);
  assert.equal(snap.demoParticipants.find((p) => !p.playable)!.power, 0);
  assert.equal(JSON.stringify(s), before);
  for (const bot of Object.values(s.bots!)) {
    assert.equal("token" in bot, false);
    assert.equal("pairCode" in bot, false);
    assert.equal("admissionKey" in bot, false);
    assert.throws(() => authenticate(s, bot.participant.id));
    assert.throws(() =>
      command(s, bot.participant.id, "attack", { type: "finish" }, base),
    );
  }
});
test("standard rooms receive no bots and retain two-person minimum / no late admission", () => {
  const s = newRoom(
    "123456ABCDEF",
    "standard",
    180,
    newMember("host", "a".repeat(64), "AAAAAAAA", "red"),
    base,
  );
  act(s, "host", "profile", { profile });
  assert.throws(() => act(s, "host", "start"));
  assert.deepEqual(snapshot(s, "host", base).demoParticipants, []);
  assert.equal(s.bots, undefined);
  readyGuest(s);
  act(s, "host", "start");
  assert.throws(() =>
    joinRoom(s, newMember("third", "c".repeat(64), "CCCCCCCC", "red"), base),
  );
  assert.throws(() =>
    act(s, "host", "pairBot", { botId: "demo:123456ABCDEF:red:1" }),
  );
});
test("solo start requires the real host profile and admits only one late blue guest", () => {
  const s = newRoom(
    "123456ABCDEF",
    "presentation",
    180,
    newMember("host", "a".repeat(64), "AAAAAAAA", "red"),
    base,
  );
  assert.throws(() => act(s, "host", "start"));
  act(s, "host", "profile", { profile });
  act(s, "host", "start", {}, base, "start");
  const end = s.endsAt;
  assert.equal(act(s, "host", "start", {}, base + 100, "start"), false);
  assert.equal(s.endsAt, end);
  const before = snapshot(s, "host", base).demoParticipants.filter(
    (p) => p.playable,
  );
  guest(s, base + 1000);
  assert.equal(s.members.guest!.participant.team, "blue");
  assert.equal(s.members.guest!.participant.ready, false);
  assert.equal(snapshot(s, "host", base).demoParticipants.length, 4);
  assert.deepEqual(snapshot(s, "host", base).demoParticipants, before);
  assert.throws(() =>
    joinRoom(
      s,
      newMember("third", "c".repeat(64), "CCCCCCCC", "blue"),
      base + 1000,
    ),
  );
});
test("both real profiles must be ready; active guest profile saves once with idempotent recovery", () => {
  const s = solo();
  guest(s, base + 1000);
  assert.throws(() =>
    act(s, "host", "pair", { peerCode: "BBBBBBBB" }, base + 1000),
  );
  assert.throws(() =>
    act(s, "guest", "pairBot", { botId: Object.keys(s.bots!)[0] }, base + 1000),
  );
  const value = { profile: { ...profile, nickname: "あお" } };
  act(s, "guest", "profile", value, base + 1000, "profile");
  assert.equal(
    act(s, "guest", "profile", value, base + 2000, "profile"),
    false,
  );
  assert.throws(() => act(s, "guest", "profile", { profile }, base + 2000));
  assert.throws(() => act(s, "host", "profile", { profile }, base + 2000));
  act(s, "host", "pair", { peerCode: "BBBBBBBB" }, base + 2000);
  assert.equal(s.encounters[s.members.host!.encounterId!]!.kind, "duel");
});
test("late admission and first profile reject the deadline and every closed phase", () => {
  for (const status of ["closing", "finale", "ended"] as const) {
    const s = solo();
    s.status = status;
    assert.throws(() => guest(s, base + 1000));
  }
  const s = solo();
  assert.throws(() => guest(s, s.endsAt!));
  assert.equal(Object.keys(s.members).length, 1);
  guest(s, s.endsAt! - 1);
  assert.throws(() => act(s, "guest", "profile", { profile }, s.endsAt!));
  assert.equal(s.members.guest!.participant.ready, false);
  assert.equal(
    s.finalSnapshot!.rankings.some((r) => r.participant.id === "guest"),
    false,
  );
});
test("bot offers ready automatically, hides plan, and samples one persistent duel plan per round", () => {
  let s = solo();
  const e = botPair(s);
  assert.deepEqual(e.readyIds, [e.playerIds[1]]);
  assert.equal("botPlan" in snapshot(s, "host", base).encounter!, false);
  const at = ready(s, e);
  const plan = structuredClone(e.botPlan!);
  assert.ok(
    plan.duelFell
      ? plan.duelOffsetMs === 1800
      : plan.duelOffsetMs >= 1300 && plan.duelOffsetMs <= 1750,
  );
  s = JSON.parse(JSON.stringify(s));
  const stored = s.encounters[e.id]!;
  advance(s, at + plan.duelOffsetMs);
  assert.deepEqual(stored.botPlan, plan);
  assert.equal(stored.decisions[plan.botId]!.at, at + plan.duelOffsetMs);
  assert.equal(stored.decisions.host, undefined);
  assert.equal(s.members.host!.followers.length, 0);
});
test("zero seat and arbitrary bot IDs cannot be paired, authenticated or used as a QR code", () => {
  const s = solo();
  const zero = snapshot(s, "host", base).demoParticipants.find(
    (p) => !p.playable,
  )!;
  for (const botId of [zero.id, "host", "no-such-bot"])
    assert.throws(() => act(s, "host", "pairBot", { botId }));
  assert.throws(() => act(s, "host", "pair", { peerCode: "red:1" }));
  assert.equal(Object.keys(s.encounters).length, 0);
});
test("bot occupancy spans two real devices; disconnect releases it without rewards or removing the other encounter", () => {
  const s = solo();
  readyGuest(s);
  const e = botPair(s);
  const id = e.playerIds[1];
  assert.equal(
    snapshot(s, "guest", base).demoParticipants.find((p) => p.id === id)!.busy,
    true,
  );
  assert.throws(() => botPair(s, "guest", id));
  connectionChanged(s, "host", false, base + 100);
  assert.equal(e.status, "cancelled");
  assert.equal(s.bots![id]!.encounterId, null);
  const other = botPair(s, "guest", id, base + 200);
  returnHome(s, e, base + 300);
  assert.equal(s.bots![id]!.encounterId, other.id);
  assert.equal(s.members.host!.followers.length, 0);
  act(s, "guest", "cancel", { encounterId: other.id }, base + 400);
  assert.equal(s.bots![id]!.encounterId, null);
});
test("late real participant can join while the solo host has a bot encounter", () => {
  const s = solo();
  const e = botPair(s);
  ready(s, e);
  guest(s, e.startAt! + 100);
  act(s, "guest", "profile", { profile }, e.startAt! + 100);
  assert.equal(s.members.host!.encounterId, e.id);
  assert.equal(s.members.guest!.encounterId, null);
  assert.throws(() => botPair(s, "guest", e.playerIds[1], e.startAt! + 100));
});
test("human safe win / bot safe win / both fall use the same reward rules", () => {
  for (const [humanAt, humanFell, botAt, botFell, outcome] of [
    [1700, false, 1500, false, "win"],
    [1000, false, 1500, false, "loss"],
    [1800, true, 1800, true, "loss"],
  ] as const) {
    const s = solo();
    const e = botPair(s);
    const at = ready(s, e);
    e.botPlan!.duelOffsetMs = botAt;
    e.botPlan!.duelFell = botFell;
    act(
      s,
      "host",
      "duelInput",
      { encounterId: e.id, round: 1, at: at + humanAt, fell: humanFell },
      at + humanAt,
    );
    advance(s, at + Math.max(humanAt, botAt));
    assert.equal(e.results.host!.outcome, outcome);
    assert.equal(s.members.host!.followers.length, 1);
    const bot = s.bots![e.playerIds[1]]!;
    assert.equal(bot.followers.length, 3);
    assert.equal(bot.encounterId, null);
    advance(s, at + 5000);
    assert.equal(bot.followers.length, 3);
  }
});
test("exact tie has no rewards and one human ready starts a new bot round", () => {
  const s = solo();
  const e = botPair(s);
  const at = ready(s, e);
  e.botPlan!.duelOffsetMs = 1500;
  e.botPlan!.duelFell = false;
  act(
    s,
    "host",
    "duelInput",
    { encounterId: e.id, round: 1, at: at + 1500, fell: false },
    at + 1500,
  );
  assert.equal(e.status, "draw");
  assert.equal(s.members.host!.followers.length, 0);
  act(s, "host", "ready", { encounterId: e.id, round: 1 }, at + 2000);
  assert.equal(e.round, 2);
  assert.equal(e.status, "countdown");
  assert.equal(e.readyIds.length, 2);
});
test("one human plays every own coop turn while alarms play only bot turns and both inventories receive REBORN", () => {
  const s = solo();
  const e = botPair(s);
  const id = e.playerIds[1];
  lose(s, e);
  returnHome(s, e);
  assert.equal(
    snapshot(s, "host", base).demoParticipants.find((p) => p.id === id)!
      .nextKind,
    "coop",
  );
  const c = botPair(s, "host", id, base + 6000);
  assert.equal(c.kind, "coop");
  const botPower = snapshot(s, "host", base).demoParticipants.find(
    (p) => p.id === id,
  )!.power;
  winCoop(s, c, base + 6000);
  assert.equal(c.results.host!.outcome, "coopSuccess");
  assert.equal(c.results.host!.delta, 2);
  assert.equal(s.members.host!.followers.length, 1);
  assert.equal(s.members.host!.followers[0]!.kind, "normal");
  assert.equal(
    snapshot(s, "host", base).demoParticipants.find((p) => p.id === id)!.power,
    botPower + 2,
  );
  assert.equal(
    snapshot(s, "host", base).demoParticipants.find((p) => p.id === id)!
      .nextKind,
    null,
  );
  returnHome(s, c, base + 60000);
  assert.throws(() => botPair(s, "host", id, base + 60000));
});
test("human coop miss awards bones but absent human input only cancels, releasing the bot", () => {
  for (const miss of [true, false]) {
    const s = solo();
    const e = botPair(s);
    const id = e.playerIds[1];
    lose(s, e);
    returnHome(s, e);
    const c = botPair(s, "host", id, base + 6000);
    const at = ready(s, c, base + 6000);
    if (miss)
      act(
        s,
        "host",
        "coopInput",
        {
          encounterId: c.id,
          round: 1,
          level: 0,
          hop: 1,
          at: at + 1000,
          miss: true,
        },
        at + 1000,
      );
    else advance(s, at + 4000);
    assert.equal(c.status, miss ? "finished" : "cancelled");
    assert.equal(s.members.host!.followers.length, miss ? 2 : 1);
    assert.equal(s.bots![id]!.encounterId, null);
  }
});
test("hard room deadline cancels uncompleted bot input rather than settling after grace", () => {
  const s = solo();
  const e = botPair(s, "host", Object.keys(s.bots!)[0]!, s.endsAt! - 1000);
  ready(s, e, s.endsAt! - 1000);
  advance(s, s.endsAt! + 30000);
  assert.equal(e.status, "cancelled");
  assert.equal(s.members.host!.followers.length, 0);
  assert.equal(s.bots![e.playerIds[1]]!.encounterId, null);
  assert.equal(s.finalSnapshot!.redPower, 6);
  assert.equal(s.finalSnapshot!.bluePower, 6);
});
test("legacy room migration preserves bot IDs and frozen final results; solo finals include demo scores only once", () => {
  const s = solo();
  delete s.bots;
  const before = snapshot(s, "host", base).demoParticipants;
  assert.equal(advance(s, base), true);
  assert.deepEqual(snapshot(s, "host", base).demoParticipants, before);
  const revision = s.revision;
  assert.equal(advance(s, base), false);
  assert.equal(s.revision, revision);
  act(s, "host", "finish");
  assert.equal(s.finalSnapshot!.redPower, 6);
  assert.equal(s.finalSnapshot!.bluePower, 6);
  assert.equal(s.finalSnapshot!.rankings.length, 6);
  assert.equal(s.finalSnapshot!.mvpIds.length, 2);
  assert.equal(s.members.host!.followers.length, 0);
  const frozen = JSON.stringify(s.finalSnapshot);
  delete s.bots;
  advance(s, base + 1000);
  assert.equal(JSON.stringify(s.finalSnapshot), frozen);
});

test("restoration cancels a disconnected human before a due bot turn could award a result", () => {
  const s = solo();
  const e = botPair(s);
  const at = ready(s, e);
  e.botPlan!.duelOffsetMs = 1500;
  e.botPlan!.duelFell = false;
  act(
    s,
    "host",
    "duelInput",
    { encounterId: e.id, round: 1, at: at + 1000, fell: false },
    at + 1000,
  );
  reconcileConnections(s, new Set(), at + 1600);
  assert.equal(e.status, "cancelled");
  assert.equal(s.members.host!.followers.length, 0);
  assert.equal(e.decisions[e.playerIds[1]], undefined);
  assert.equal(s.bots![e.playerIds[1]]!.encounterId, null);
});
