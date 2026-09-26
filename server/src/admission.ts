import { RuleError, type Member, type RoomState } from './room';

/** This key grants session recovery: never expose it in URLs or snapshots. */
export function admissionKey(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-f0-9]{64}$/.test(value)) {
    throw new RuleError('参加の再試行情報を確認してください。', 400);
  }
  return value;
}

/** A stable public room code, without exposing any reversible part of the key. */
export async function roomCodeForAdmission(key: string): Promise<string> {
  admissionKey(key);
  const digest = await crypto.subtle.digest(
    'SHA-256', new TextEncoder().encode(`tsunagun-room-v1:${key}`),
  );
  return [...new Uint8Array(digest).slice(0, 6)]
    .map(value => value.toString(16).padStart(2, '0')).join('').toUpperCase();
}

export function recoveredMember(
  room: RoomState,
  key: string,
  kind: 'create' | 'join',
): Member | undefined {
  admissionKey(key);
  const member = Object.values(room.members).find(m => m.admissionKey === key);
  if (member && (member.participant.id === room.hostId) !== (kind === 'create')) {
    throw new RuleError('前の参加処理とは種類が異なります。', 409);
  }
  return member;
}
