import { RuleError, type Member, type RoomState } from "./room";

/** This key grants session recovery: never expose it in URLs or snapshots. */
export function admissionKey(value: unknown): string {
  if (typeof value !== "string" || !/^[a-f0-9]{64}$/.test(value)) {
    throw new RuleError("参加の再試行情報を確認してください。", 400);
  }
  return value;
}

/** Preserve old successful creates whose original response was lost. */
export async function legacyRoomCodeForAdmission(key: string): Promise<string> {
  admissionKey(key);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`tsunagun-room-v1:${key}`),
  );
  return [...new Uint8Array(digest).slice(0, 6)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
}

/** Five decimal digits, stable for one secret. Collisions are explicit errors. */
export async function roomCodeForAdmission(key: string): Promise<string> {
  return (Number.parseInt(await legacyRoomCodeForAdmission(key), 16) % 100_000)
    .toString()
    .padStart(5, "0");
}

export function creationCodeDigits(value: unknown): 5 | undefined {
  if (value === undefined || value === 5) return value;
  throw new RuleError("ルームコードの形式を確認してください。", 400);
}

export async function resolveCreation(
  key: string,
  visit: (code: string, operation: "recover" | "create") => Promise<Response>,
  format: "short" | "legacy" = "short",
): Promise<Response> {
  const legacy = await visit(await legacyRoomCodeForAdmission(key), "recover");
  // A settings mismatch, expired own room or transient error must never create
  // another room. Only an explicit absence falls through to the new short code.
  if (legacy.status !== 404) return legacy;
  const shortCode = await roomCodeForAdmission(key);
  if (format === "short") return visit(shortCode, "create");
  // An older client must not allocate a second room for a key already used by
  // a newer client. It cannot understand that short room code, so ask it to
  // update without classifying this as a collision or rotating its secret.
  const short = await visit(shortCode, "recover");
  if (short.ok) {
    return Response.json(
      { error: "この参加処理は新しいアプリで再開してください。" },
      { status: 409 },
    );
  }
  if (short.status !== 404) return short;
  return visit(await legacyRoomCodeForAdmission(key), "create");
}

export function recoveredMember(
  room: RoomState,
  key: string,
  kind: "create" | "join",
): Member | undefined {
  admissionKey(key);
  const member = Object.values(room.members).find(
    (m) => m.admissionKey === key,
  );
  if (
    member &&
    (member.participant.id === room.hostId) !== (kind === "create")
  ) {
    throw new RuleError("前の参加処理とは種類が異なります。", 409);
  }
  return member;
}

export function creationOwner(
  room: RoomState,
  key: string,
  mode: unknown,
  durationSeconds: unknown,
): Member | undefined {
  const prior = recoveredMember(room, key, "create");
  if (
    prior &&
    (room.mode !== mode || room.durationSeconds !== durationSeconds)
  ) {
    throw new RuleError("同じ参加処理で異なるルームは作成できません。", 409);
  }
  return prior;
}
