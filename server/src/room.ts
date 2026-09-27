/** Authoritative, deterministic room rules. No transport or trusted client outcomes. */
export type Team = "red" | "blue";
export type Outcome = "win" | "loss" | "coopSuccess" | "coopFailure";
export type Profile = { nickname: string; hobby: string; comment: string };
export type Participant = {
  id: string;
  profile: Profile;
  team: Team;
  ready: boolean;
  connected: boolean;
};
export type Follower = {
  id: string;
  ownerId: string;
  peerId: string;
  profile: Profile;
  kind: "normal" | "bone";
  ordinal: number;
  revivedWith: Participant | null;
};
export type Result = {
  outcome: Outcome;
  peer: Participant;
  newFollower: Follower | null;
  promoted: Follower | null;
  delta: number;
};
export type Encounter = {
  id: string;
  kind: "duel" | "coop";
  playerIds: [string, string];
  readyIds: string[];
  status:
    | "offered"
    | "countdown"
    | "playing"
    | "finished"
    | "draw"
    | "cancelled";
  round: number;
  startAt: number | null;
  fallMs: number;
  decisions: Record<string, { fell: boolean; depth: number; at: number }>;
  coop: {
    level: number;
    hop: number;
    levelStartAt: number;
    hits: { hop: number; playerId: string; at: number }[];
    clearedAt: number | null;
    failedAt?: number;
    failedHop?: number;
  };
  results: Record<string, Result>;
  message?: string;
  createdAt: number;
  botPlan?: { botId: string; duelOffsetMs: number; duelFell: boolean };
};
export type DemoParticipant = Participant & {
  isDemo: true;
  normalCount: number;
  boneCount: number;
  power: number;
  playable: boolean;
  busy: boolean;
  nextKind: "duel" | "coop" | null;
};
export type Ranking = {
  participant: Participant & { isDemo?: true };
  normalCount: number;
  boneCount: number;
  power: number;
  rank: number;
};
export type FinalSnapshot = {
  redPower: number;
  bluePower: number;
  rankings: Ranking[];
  mvpIds: string[];
};
export type Actor = {
  participant: Participant;
  followers: Follower[];
  encounterId: string | null;
};
export type Member = Actor & {
  token: string;
  admissionKey?: string;
  pairCode: string;
};
export type Bot = Actor;
export type RoomState = {
  schema: 1;
  code: string;
  mode: "standard" | "presentation";
  hostId: string;
  status: "lobby" | "active" | "closing" | "finale" | "ended";
  durationSeconds: number;
  createdAt: number;
  expiresAt: number;
  revision: number;
  endsAt: number | null;
  closingAt: number | null;
  finaleStartsAt: number | null;
  members: Record<string, Member>;
  bots?: Record<string, Bot>;
  encounters: Record<string, Encounter>;
  completed: string[];
  requests: Record<string, string>;
  finalSnapshot: FinalSnapshot | null;
};
export type Action = Record<string, unknown> & { type: string };
export const ROOM_TTL = 24 * 60 * 60 * 1000;
export const INPUT_LAG = 1800;
export const MAX_MEMBERS = 24;
const FUTURE_TOLERANCE = 250;
const LEVELS = [
  { flight: 1000, window: 230 },
  { flight: 800, window: 190 },
  { flight: 650, window: 150 },
];
const active = (e: Encounter) =>
  ["offered", "countdown", "playing", "draw"].includes(e.status);
const pairKey = (a: string, b: string) => [a, b].sort().join(":");
const emptyProfile = (): Profile => ({ nickname: "", hobby: "", comment: "" });
const clone = <T>(v: T): T => structuredClone(v);
function canonical(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    const entries = Object.entries(value).sort(([a], [b]) =>
      a.localeCompare(b),
    );
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`;
  }
  return JSON.stringify(value);
}
export class RuleError extends Error {
  constructor(
    message: string,
    public status = 409,
    public code?: "ROOM_CODE_COLLISION",
  ) {
    super(message);
  }
}
function requireRule(
  value: unknown,
  message: string,
  status = 409,
): asserts value {
  if (!value) throw new RuleError(message, status);
}
export function record(value: unknown): Record<string, unknown> {
  requireRule(
    value && typeof value === "object" && !Array.isArray(value),
    "送信内容を確認してください。",
    400,
  );
  return value as Record<string, unknown>;
}
function exactKeys(value: Record<string, unknown>, keys: string[]) {
  requireRule(
    Object.keys(value).every((k) => keys.includes(k)),
    "未対応の送信項目があります。",
    400,
  );
}
function integer(
  value: unknown,
  min: number,
  max: number,
  name: string,
): number {
  requireRule(
    typeof value === "number" &&
      Number.isSafeInteger(value) &&
      value >= min &&
      value <= max,
    `${name}を確認してください。`,
    400,
  );
  return value;
}
function string(value: unknown, max: number, name: string): string {
  requireRule(
    typeof value === "string" && value.length > 0 && value.length <= max,
    `${name}を確認してください。`,
    400,
  );
  return value;
}
function flag(value: unknown, name: string): boolean {
  requireRule(typeof value === "boolean", `${name}を確認してください。`, 400);
  return value;
}
export function validateProfile(value: unknown): Profile {
  const p = record(value);
  exactKeys(p, ["nickname", "hobby", "comment"]);
  const segmenter = new Intl.Segmenter("ja", { granularity: "grapheme" });
  const text = (key: string, limit: number, required: boolean) => {
    requireRule(
      typeof p[key] === "string",
      "プロフィールを確認してください。",
      400,
    );
    const v = (p[key] as string).trim();
    requireRule(
      v.length <= limit * 16 &&
        [...segmenter.segment(v)].length <= limit &&
        (!required || v.length > 0) &&
        !/[\u0000-\u001f\u007f]/u.test(v),
      `${key === "nickname" ? "ニックネーム" : key === "hobby" ? "趣味" : "ひとこと"}は${limit}文字以内で入力してください。`,
      400,
    );
    return v;
  };
  return {
    nickname: text("nickname", 20, true),
    hobby: text("hobby", 60, true),
    comment: text("comment", 80, false),
  };
}
export function newMember(
  id: string,
  token: string,
  pairCode: string,
  team: Team,
  admissionKey?: string,
): Member {
  return {
    participant: {
      id,
      profile: emptyProfile(),
      team,
      ready: false,
      connected: false,
    },
    token,
    admissionKey,
    pairCode,
    followers: [],
    encounterId: null,
  };
}
export function newRoom(
  code: string,
  mode: unknown,
  durationSeconds: unknown,
  host: Member,
  now: number,
): RoomState {
  requireRule(
    mode === "standard" || mode === "presentation",
    "ルームの種類を確認してください。",
    400,
  );
  const duration = integer(durationSeconds, 60, 3600, "制限時間");
  return {
    schema: 1,
    code,
    mode,
    hostId: host.participant.id,
    status: "lobby",
    durationSeconds: duration,
    createdAt: now,
    expiresAt: now + ROOM_TTL,
    revision: 1,
    endsAt: null,
    closingAt: null,
    finaleStartsAt: null,
    members: { [host.participant.id]: host },
    ...(mode === "presentation" ? { bots: initialBots(code) } : {}),
    encounters: {},
    completed: [],
    requests: {},
    finalSnapshot: null,
  };
}
export function joinRoom(s: RoomState, member: Member, now: number) {
  requireRule(now < s.expiresAt, "このルームの保存期間が終了しました。", 410);
  const canJoinStartedPresentation =
    s.mode === "presentation" &&
    s.status === "active" &&
    Object.keys(s.members).length === 1 &&
    s.endsAt !== null &&
    now < s.endsAt;
  requireRule(
    s.status === "lobby" || canJoinStartedPresentation,
    "このルームの参加受付は終了しています。",
  );
  requireRule(
    Object.keys(s.members).length <
      (s.mode === "presentation" ? 2 : MAX_MEMBERS),
    "ルームの人数が上限に達しました。",
  );
  requireRule(
    !s.members[member.participant.id] &&
      !Object.values(s.members).some((m) => m.pairCode === member.pairCode),
    "参加情報が重複しました。",
  );
  // The solo presentation host is already red. A late guest fills the blue
  // real-player slot; decorative guests never affect team allocation.
  if (canJoinStartedPresentation) member.participant.team = "blue";
  s.members[member.participant.id] = member;
  s.revision++;
}
export function authenticate(s: RoomState, token: unknown): string {
  requireRule(
    typeof token === "string" && /^[a-f0-9]{64}$/.test(token),
    "参加情報を確認できません。",
    401,
  );
  const member = Object.values(s.members).find((m) => m.token === token);
  requireRule(member, "参加情報を確認できません。", 401);
  return member.participant.id;
}
/** Bots have persistent inventories, but no credentials or pair codes. */
function initialBots(code: string): Record<string, Bot> {
  const bots: Record<string, Bot> = {};
  for (const [teamIndex, team] of (["red", "blue"] as const).entries()) {
    for (let index = 0; index < 2; index++) {
      const id = `demo:${code}:${team}:${index + 1}`;
      const kinds: Follower["kind"][] =
        index === 0 ? ["normal", "bone"] : ["bone", "bone"];
      bots[id] = {
        participant: {
          id,
          team,
          ready: true,
          connected: true,
          profile: {
            nickname: `デモ参加者${teamIndex * 3 + index + 1}`,
            hobby: "",
            comment: "",
          },
        },
        followers: kinds.map((kind, n) => ({
          id: `seed:${id}:${n + 1}`,
          ownerId: id,
          peerId: `demo:seed:${n + 1}`,
          profile: { nickname: "デモの仲間", hobby: "", comment: "" },
          kind,
          ordinal: n + 1,
          revivedWith: null,
        })),
        encounterId: null,
      };
    }
  }
  return bots;
}
function botsFor(s: RoomState): Record<string, Bot> {
  return s.mode === "presentation" ? (s.bots ?? initialBots(s.code)) : {};
}
function actorFor(s: RoomState, id: string): Actor | undefined {
  return (
    s.members[id] ?? (s.mode === "presentation" ? s.bots?.[id] : undefined)
  );
}
function nextKindFor(
  s: RoomState,
  selfId: string,
  botId: string,
): "duel" | "coop" | null {
  const key = pairKey(selfId, botId);
  return s.completed.includes(`${key}:coop`)
    ? null
    : s.completed.includes(`${key}:duel`)
      ? "coop"
      : "duel";
}
function counts(actor: Actor) {
  const normalCount = actor.followers.filter((f) => f.kind === "normal").length;
  const boneCount = actor.followers.filter((f) => f.kind === "bone").length;
  return { normalCount, boneCount, power: normalCount * 3 + boneCount };
}
function demoParticipants(s: RoomState, selfId?: string): DemoParticipant[] {
  if (s.mode !== "presentation") return [];
  const demos: DemoParticipant[] = Object.values(botsFor(s)).map((bot) => ({
    ...clone(bot.participant),
    ...counts(bot),
    isDemo: true,
    playable: true,
    busy: bot.encounterId !== null,
    nextKind: selfId ? nextKindFor(s, selfId, bot.participant.id) : null,
  }));
  // A fifth, unplayable zero-point seat previews the second real participant.
  for (const [teamIndex, team] of (["red", "blue"] as const).entries()) {
    if (!Object.values(s.members).some((m) => m.participant.team === team)) {
      demos.push({
        id: `demo:${s.code}:${team}:3`,
        profile: {
          nickname: `デモ参加者${teamIndex * 3 + 3}`,
          hobby: "",
          comment: "",
        },
        team,
        ready: false,
        connected: false,
        isDemo: true,
        normalCount: 0,
        boneCount: 0,
        power: 0,
        playable: false,
        busy: false,
        nextKind: null,
      });
    }
  }
  return demos;
}
export function snapshot(s: RoomState, selfId: string, now: number) {
  const me = s.members[selfId];
  requireRule(me, "参加情報を確認できません。", 401);
  const e = me.encounterId ? s.encounters[me.encounterId] : null;
  return clone({
    code: s.code,
    mode: s.mode,
    status: s.status,
    hostId: s.hostId,
    selfId,
    serverNow: now,
    revision: s.revision,
    endsAt: s.endsAt,
    finaleStartsAt: s.finaleStartsAt,
    pairCode: me.pairCode,
    participants: Object.values(s.members).map((m) => m.participant),
    demoParticipants: demoParticipants(s, selfId),
    followers: me.followers,
    encounter: e
      ? {
          id: e.id,
          kind: e.kind,
          playerIds: e.playerIds,
          readyIds: e.readyIds,
          status: e.status,
          round: e.round,
          startAt: e.startAt,
          fallMs: e.fallMs,
          decisions: e.decisions,
          coop: e.coop,
          result: e.results[selfId] ?? null,
          message: e.message,
        }
      : null,
    finalSnapshot: s.finalSnapshot,
  });
}
function releaseBot(s: RoomState, e: Encounter) {
  const bot = e.botPlan && s.bots?.[e.botPlan.botId];
  if (bot?.encounterId === e.id) bot.encounterId = null;
}
function cancelEncounter(s: RoomState, e: Encounter, message: string) {
  if (!active(e)) return;
  e.status = "cancelled";
  e.readyIds = [];
  e.message = message;
  releaseBot(s, e);
}
export function connectionChanged(
  s: RoomState,
  id: string,
  connected: boolean,
  now: number,
  advanceClock = true,
) {
  const m = s.members[id];
  if (!m || m.participant.connected === connected) return;
  m.participant.connected = connected;
  if (!connected && m.encounterId) {
    const e = s.encounters[m.encounterId];
    if (e)
      cancelEncounter(
        s,
        e,
        "接続が途切れました。報酬は変わりません。ホームからもう一度ツナがれます。",
      );
  }
  s.revision++;
  if (advanceClock) advance(s, now);
}
/** Reconcile every socket before advancing any pending automated turn. */
export function reconcileConnections(
  s: RoomState,
  connectedIds: ReadonlySet<string>,
  now: number,
) {
  for (const id of Object.keys(s.members))
    connectionChanged(s, id, connectedIds.has(id), now, false);
  advance(s, now);
}
function reward(
  s: RoomState,
  e: Encounter,
  id: string,
  outcome: Outcome,
): Result {
  const m = actorFor(s, id)!;
  const peer = actorFor(s, e.playerIds.find((p) => p !== id)!)!.participant;
  if (outcome === "coopSuccess") {
    const bone = m.followers
      .filter((f) => f.kind === "bone")
      .sort((a, b) => a.ordinal - b.ordinal)[0];
    if (bone) {
      bone.kind = "normal";
      bone.revivedWith = clone(peer);
      return {
        outcome,
        peer: clone(peer),
        newFollower: null,
        promoted: clone(bone),
        delta: 2,
      };
    }
  }
  const f: Follower = {
    id: `${e.id}:${id}`,
    ownerId: id,
    peerId: peer.id,
    profile: clone(peer.profile),
    kind: outcome === "win" || outcome === "coopSuccess" ? "normal" : "bone",
    ordinal: m.followers.reduce((n, f) => Math.max(n, f.ordinal), 0) + 1,
    revivedWith: null,
  };
  m.followers.push(f);
  return {
    outcome,
    peer: clone(peer),
    newFollower: clone(f),
    promoted: null,
    delta: f.kind === "normal" ? 3 : 1,
  };
}
function settle(s: RoomState, e: Encounter, outcomes: [Outcome, Outcome]) {
  if (e.status === "finished") return;
  e.status = "finished";
  e.playerIds.forEach((id, i) => {
    e.results[id] = reward(s, e, id, outcomes[i]!);
  });
  const key =
    pairKey(...e.playerIds) + (s.mode === "presentation" ? `:${e.kind}` : "");
  if (!s.completed.includes(key)) s.completed.push(key);
  releaseBot(s, e);
}
function finalise(s: RoomState) {
  const actualRows: Ranking[] = Object.values(s.members)
    .filter((m) => m.participant.ready)
    .map((m) => {
      const normalCount = m.followers.filter((f) => f.kind === "normal").length;
      const boneCount = m.followers.filter((f) => f.kind === "bone").length;
      return {
        participant: clone(m.participant),
        normalCount,
        boneCount,
        power: normalCount * 3 + boneCount,
        rank: 0,
      };
    });
  const demoRows: Ranking[] = demoParticipants(s).map((sample) => {
    const {
      normalCount,
      boneCount,
      power,
      playable,
      busy,
      nextKind,
      ...participant
    } = sample;
    return { participant, normalCount, boneCount, power, rank: 0 };
  });
  const rows = [...actualRows, ...demoRows].sort(
    (a, b) =>
      b.power - a.power || a.participant.id.localeCompare(b.participant.id),
  );
  rows.forEach((r, i) => {
    r.rank =
      i > 0 && rows[i - 1]!.power === r.power ? rows[i - 1]!.rank : i + 1;
  });
  s.finalSnapshot = {
    redPower: rows
      .filter((r) => r.participant.team === "red")
      .reduce((n, r) => n + r.power, 0),
    bluePower: rows
      .filter((r) => r.participant.team === "blue")
      .reduce((n, r) => n + r.power, 0),
    rankings: rows,
    mvpIds: rows
      .filter((r) => r.rank === 1 && r.power > 0)
      .map((r) => r.participant.id),
  };
  s.status = "finale";
}
function applyDuelDecision(
  s: RoomState,
  e: Encounter,
  id: string,
  at: number,
  fell: boolean,
  now: number,
) {
  if (e.decisions[id] || e.status !== "playing") return;
  e.decisions[id] = {
    at,
    fell,
    depth: Math.min(1, ((at - e.startAt!) / e.fallMs) ** 2),
  };
  const [left, right] = e.playerIds.map((p) => e.decisions[p]);
  if (!left || !right) return;
  if (left.fell && right.fell) settle(s, e, ["loss", "loss"]);
  else if (!left.fell && !right.fell && left.at === right.at) {
    e.status = "draw";
    e.readyIds = [];
    e.createdAt = now;
    e.message = "ぴったり同点！もう一度勝負しよう。";
  } else {
    const leftWins = right.fell || (!left.fell && left.at > right.at);
    settle(s, e, leftWins ? ["win", "loss"] : ["loss", "win"]);
  }
}
function applyCoopInput(
  s: RoomState,
  e: Encounter,
  id: string,
  at: number,
  miss: boolean,
) {
  const hop = e.coop.hop,
    level = LEVELS[e.coop.level]!;
  if (miss || Math.abs(at - targetAt(e)) > level.window) {
    e.coop.failedAt = at;
    e.coop.failedHop = hop;
    settle(s, e, ["coopFailure", "coopFailure"]);
  } else {
    e.coop.hits.push({ hop, playerId: id, at });
    e.coop.hop++;
    if (hop === 6)
      e.coop.clearedAt =
        e.coop.levelStartAt + 1.3 * level.flight + 6 * level.flight + 350 + 900;
  }
}
/** Clock transitions include only server-owned bot turns; missing human inputs cancel. */
export function advance(s: RoomState, now: number): boolean {
  let changed = false;
  if (s.mode === "presentation" && s.bots === undefined) {
    s.bots = initialBots(s.code);
    changed = true;
  }
  if (s.status === "active" && s.endsAt !== null && now >= s.endsAt) {
    s.status = "closing";
    s.closingAt = s.endsAt + 30_000;
    changed = true;
  }
  for (const e of Object.values(s.encounters)) {
    // At the room's hard deadline, do not retrospectively settle late bot turns.
    if (s.status === "closing" && now >= s.closingAt! && active(e)) {
      cancelEncounter(s, e, "交流の時間が終了しました。");
      changed = true;
      continue;
    }
    if (e.status === "countdown" && e.startAt !== null && now >= e.startAt) {
      e.status = "playing";
      changed = true;
    }
    if (
      (e.status === "offered" || e.status === "draw") &&
      now >= e.createdAt + 120_000
    ) {
      cancelEncounter(
        s,
        e,
        "準備の時間が終了しました。もう一度ツナがってください。",
      );
      changed = true;
    }
    if (e.status !== "playing") continue;
    if (e.kind === "duel") {
      if (
        e.botPlan &&
        !e.decisions[e.botPlan.botId] &&
        now >= e.startAt! + e.botPlan.duelOffsetMs
      ) {
        applyDuelDecision(
          s,
          e,
          e.botPlan.botId,
          e.startAt! + e.botPlan.duelOffsetMs,
          e.botPlan.duelFell,
          now,
        );
        changed = true;
      }
      if (e.status === "playing" && now > e.startAt! + e.fallMs + INPUT_LAG) {
        cancelEncounter(
          s,
          e,
          "操作を受信できませんでした。報酬は変わりません。",
        );
        changed = true;
      }
    } else {
      if (e.coop.clearedAt !== null && now >= e.coop.clearedAt) {
        if (e.coop.level === 2) settle(s, e, ["coopSuccess", "coopSuccess"]);
        else
          e.coop = {
            level: e.coop.level + 1,
            hop: 1,
            levelStartAt: e.coop.clearedAt + 1200,
            hits: [],
            clearedAt: null,
          };
        changed = true;
      }
      if (e.status === "playing" && e.coop.clearedAt === null) {
        const due = targetAt(e);
        if (
          e.botPlan &&
          e.playerIds[(e.coop.hop - 1) % 2] === e.botPlan.botId &&
          now >= due
        ) {
          applyCoopInput(s, e, e.botPlan.botId, due, false);
          changed = true;
        }
        if (
          e.coop.clearedAt === null &&
          now > targetAt(e) + LEVELS[e.coop.level]!.window + INPUT_LAG
        ) {
          cancelEncounter(
            s,
            e,
            "操作を受信できませんでした。報酬は変わりません。",
          );
          changed = true;
        }
      }
    }
  }
  if (s.status === "closing" && !Object.values(s.encounters).some(active)) {
    finalise(s);
    changed = true;
  }
  if (
    s.status === "finale" &&
    s.finaleStartsAt !== null &&
    now >= s.finaleStartsAt + 13_000
  ) {
    s.status = "ended";
    changed = true;
  }
  if (changed) s.revision++;
  return changed;
}
function targetAt(e: Encounter) {
  const l = LEVELS[e.coop.level]!;
  return e.coop.levelStartAt + l.flight * 1.3 + (e.coop.hop - 1) * l.flight;
}
export function nextAlarm(s: RoomState, now: number): number {
  const times = [s.expiresAt];
  if (s.status === "active" && s.endsAt !== null) times.push(s.endsAt);
  if (s.status === "closing" && s.closingAt !== null) times.push(s.closingAt);
  if (s.status === "finale" && s.finaleStartsAt !== null)
    times.push(s.finaleStartsAt + 13_000);
  for (const e of Object.values(s.encounters)) {
    if (e.status === "offered" || e.status === "draw")
      times.push(e.createdAt + 120_000);
    if (e.status === "countdown") times.push(e.startAt!);
    if (e.status === "playing" && e.botPlan) {
      if (e.kind === "duel" && !e.decisions[e.botPlan.botId])
        times.push(e.startAt! + e.botPlan.duelOffsetMs);
      if (
        e.kind === "coop" &&
        e.coop.clearedAt === null &&
        e.playerIds[(e.coop.hop - 1) % 2] === e.botPlan.botId
      )
        times.push(targetAt(e));
    }
    if (e.status === "playing")
      times.push(
        e.kind === "duel"
          ? e.startAt! + e.fallMs + INPUT_LAG + 1
          : (e.coop.clearedAt ??
              targetAt(e) + LEVELS[e.coop.level]!.window + INPUT_LAG + 1),
      );
  }
  return Math.max(now + 1, Math.min(...times));
}
function encounterFor(s: RoomState, id: string, action: Action): Encounter {
  const encounterId = string(action.encounterId, 80, "交流情報");
  const e = s.encounters[encounterId];
  requireRule(
    e && e.playerIds.includes(id) && s.members[id]!.encounterId === e.id,
    "この交流は終了しています。",
  );
  return e;
}
function inputTime(a: Action, e: Encounter, now: number) {
  integer(a.round, 1, 1000, "ゲームの回数");
  requireRule(a.round === e.round, "前のゲームの操作です。");
  requireRule(
    e.status === "playing" && e.startAt !== null,
    "ゲームの開始を待ってください。",
  );
  const at = integer(a.at, e.startAt, now + FUTURE_TOLERANCE, "操作時刻");
  requireRule(
    now - at <= INPUT_LAG,
    "操作の受信が遅れました。接続を確認してください。",
  );
  return at;
}
/** Mutate a cloned state and persist it before publishing; caller rolls back on error. */
export function command(
  s: RoomState,
  id: string,
  requestId: unknown,
  input: unknown,
  now: number,
): boolean {
  const me = s.members[id];
  requireRule(me, "参加情報を確認できません。", 401);
  requireRule(now < s.expiresAt, "このルームの保存期間が終了しました。", 410);
  const req = string(requestId, 96, "操作ID");
  requireRule(/^[a-zA-Z0-9_-]+$/.test(req), "操作IDを確認してください。", 400);
  const raw = record(input);
  const type = string(raw.type, 24, "操作");
  const a = raw as Action;
  const fingerprint = canonical(a);
  const requestKey = `${id}:${req}`;
  if (s.requests[requestKey] !== undefined) {
    requireRule(
      s.requests[requestKey] === fingerprint,
      "同じ操作IDに異なる内容が送られました。",
    );
    return false;
  }
  requireRule(
    Object.keys(s.requests).length < 20_000,
    "このルームの操作上限に達しました。新しいルームを作成してください。",
    429,
  );
  const host = () =>
    requireRule(id === s.hostId, "主催者だけが操作できます。", 403);
  if (type === "profile") {
    exactKeys(a, ["type", "profile"]);
    const canCompleteLateProfile =
      s.mode === "presentation" &&
      s.status === "active" &&
      id !== s.hostId &&
      !me.participant.ready &&
      s.endsAt !== null &&
      now < s.endsAt;
    requireRule(
      s.status === "lobby" || canCompleteLateProfile,
      "開始後はプロフィールを変更できません。",
    );
    me.participant.profile = validateProfile(a.profile);
    me.participant.ready = true;
  } else if (type === "start") {
    exactKeys(a, ["type"]);
    host();
    requireRule(s.status === "lobby", "ルームはすでに開始しています。");
    const members = Object.values(s.members);
    requireRule(
      members.length >= (s.mode === "presentation" ? 1 : 2) &&
        members.every((m) => m.participant.ready),
      "全員のプロフィールが揃うまで待ってください。",
    );
    members.forEach(
      (m, i) => (m.participant.team = i % 2 === 0 ? "red" : "blue"),
    );
    s.status = "active";
    s.endsAt = now + s.durationSeconds * 1000;
  } else if (type === "pair" || type === "pairBot") {
    exactKeys(a, type === "pairBot" ? ["type", "botId"] : ["type", "peerCode"]);
    requireRule(s.status === "active", "いまは新しい交流を始められません。");
    let peer: Actor | undefined;
    if (type === "pairBot") {
      requireRule(s.mode === "presentation", "発表用ルームだけで遊べます。");
      const botId = string(a.botId, 80, "デモの相手");
      peer = s.bots?.[botId];
    } else {
      const code = string(a.peerCode, 8, "相手コード");
      peer = Object.values(s.members).find((m) => m.pairCode === code);
    }
    requireRule(
      peer && peer !== me,
      "このルームの相手コードを読み取ってください。",
    );
    requireRule(
      me.participant.ready && peer.participant.ready,
      "両方のプロフィールが揃うまで待ってください。",
    );
    requireRule(
      me.participant.connected && peer.participant.connected,
      "相手の接続を待ってください。",
    );
    requireRule(
      !me.encounterId && !peer.encounterId,
      "どちらかが交流中です。ホームへ戻ってからツナがってください。",
    );
    const key = pairKey(id, peer.participant.id);
    let kind: "duel" | "coop" =
      me.participant.team === peer.participant.team ? "coop" : "duel";
    if (s.mode === "presentation") {
      kind = s.completed.includes(`${key}:duel`) ? "coop" : "duel";
      requireRule(
        !s.completed.includes(`${key}:coop`),
        "この相手との対戦と協力は終了しました。",
      );
    } else
      requireRule(
        !s.completed.includes(key),
        "この相手とはツナがっています。別の仲間を探しましょう。",
      );
    const e: Encounter = {
      id: crypto.randomUUID(),
      kind,
      playerIds: [id, peer.participant.id],
      readyIds: type === "pairBot" ? [peer.participant.id] : [],
      ...(type === "pairBot"
        ? {
            botPlan: {
              botId: peer.participant.id,
              duelOffsetMs: 0,
              duelFell: false,
            },
          }
        : {}),
      status: "offered",
      round: 1,
      startAt: null,
      fallMs: 1800,
      decisions: {},
      coop: { level: 0, hop: 1, levelStartAt: 0, hits: [], clearedAt: null },
      results: {},
      createdAt: now,
    };
    s.encounters[e.id] = e;
    me.encounterId = e.id;
    peer.encounterId = e.id;
  } else if (type === "ready") {
    exactKeys(a, ["type", "encounterId", "round"]);
    const e = encounterFor(s, id, a);
    requireRule(
      a.round === e.round ||
        (e.status === "offered" &&
          e.readyIds.length === 1 &&
          a.round === e.round - 1),
      "前のゲームの準備操作です。",
    );
    requireRule(
      e.status === "offered" || e.status === "draw",
      "すでにゲームが始まっています。",
    );
    requireRule(
      e.playerIds.every((p) => actorFor(s, p)?.participant.connected),
      "相手の再接続を待ってください。",
    );
    if (e.status === "draw") {
      e.status = "offered";
      e.round++;
      e.decisions = {};
      e.readyIds = e.botPlan ? [e.botPlan.botId] : [];
      e.startAt = null;
      e.message = undefined;
      e.createdAt = now;
    }
    if (!e.readyIds.includes(id)) e.readyIds.push(id);
    if (e.readyIds.length === 2) {
      e.status = "countdown";
      e.startAt = now + 3000;
      e.coop.levelStartAt = e.startAt;
      if (e.botPlan && e.kind === "duel") {
        const random = crypto.getRandomValues(new Uint32Array(2));
        e.botPlan.duelFell = random[0]! / 0x1_0000_0000 < 0.15;
        e.botPlan.duelOffsetMs = e.botPlan.duelFell
          ? e.fallMs
          : 1300 + Math.floor((random[1]! / 0x1_0000_0000) * 451);
      }
    }
  } else if (type === "cancel") {
    exactKeys(a, ["type", "encounterId"]);
    const e = encounterFor(s, id, a);
    requireRule(active(e), "結果はすでに確定しています。");
    cancelEncounter(s, e, "交流を中断しました。報酬は変わりません。");
  } else if (type === "duelInput") {
    exactKeys(a, ["type", "encounterId", "round", "at", "fell"]);
    const e = encounterFor(s, id, a);
    requireRule(e.kind === "duel", "対戦の操作ではありません。");
    if (e.decisions[id]) {
      s.requests[requestKey] = fingerprint;
      return false;
    }
    const at = inputTime(a, e, now);
    const fell = flag(a.fell, "落下の操作");
    const elapsed = at - e.startAt!;
    requireRule(
      fell ? elapsed >= e.fallMs : elapsed < e.fallMs,
      "落下時刻と操作が一致しません。",
      400,
    );
    applyDuelDecision(s, e, id, at, fell, now);
  } else if (type === "coopInput") {
    exactKeys(a, [
      "type",
      "encounterId",
      "round",
      "level",
      "hop",
      "at",
      "miss",
    ]);
    const e = encounterFor(s, id, a);
    requireRule(e.kind === "coop", "協力の操作ではありません。");
    const level = integer(a.level, 0, 2, "レベル");
    const hop = integer(a.hop, 1, 6, "運搬回数");
    // Inputs from old hops or the other person's side cannot settle any outcome.
    if (
      a.round === e.round &&
      (level < e.coop.level || (level === e.coop.level && hop < e.coop.hop))
    ) {
      s.requests[requestKey] = fingerprint;
      return false;
    }
    requireRule(
      level === e.coop.level && hop === e.coop.hop && e.coop.clearedAt === null,
      "次の運搬を待ってください。",
    );
    requireRule(e.playerIds[(hop - 1) % 2] === id, "相手が運ぶ番です。");
    const at = inputTime(a, e, now);
    const miss = flag(a.miss, "運搬の操作");
    requireRule(
      at >= e.coop.levelStartAt,
      "次のレベルの開始を待ってください。",
    );
    applyCoopInput(s, e, id, at, miss);
  } else if (type === "return") {
    exactKeys(a, ["type", "encounterId"]);
    const e = encounterFor(s, id, a);
    requireRule(
      ["finished", "draw", "cancelled"].includes(e.status),
      "交流が終わるまで待ってください。",
    );
    if (e.status === "draw")
      cancelEncounter(s, e, "交流を中断しました。報酬は変わりません。");
    me.encounterId = null;
    if (e.playerIds.every((p) => actorFor(s, p)?.encounterId !== e.id))
      delete s.encounters[e.id];
  } else if (type === "finish") {
    exactKeys(a, ["type"]);
    host();
    requireRule(
      s.status === "active" || s.status === "closing",
      "交流時間は終了しています。",
    );
    if (s.status === "active") {
      s.status = "closing";
      s.closingAt = now + 30_000;
      s.endsAt = now;
    }
  } else if (type === "finale") {
    exactKeys(a, ["type"]);
    host();
    requireRule(
      s.status === "finale" || s.status === "ended",
      "交流の結果が揃うまで待ってください。",
    );
    if (s.finaleStartsAt === null) s.finaleStartsAt = now + 1000;
  } else if (type === "leave") {
    exactKeys(a, ["type"]);
    requireRule(s.status === "lobby", "開始後はルームから退室できません。");
    requireRule(
      id !== s.hostId || Object.keys(s.members).length === 1,
      "主催者は参加者がいる間は退室できません。",
    );
    delete s.members[id];
    if (id === s.hostId) {
      s.status = "ended";
      s.expiresAt = now;
    }
  } else throw new RuleError("未対応の操作です。", 400);
  s.requests[requestKey] = fingerprint;
  s.revision++;
  advance(s, now);
  return true;
}
