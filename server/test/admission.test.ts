import test from "node:test";
import assert from "node:assert/strict";
import {
  admissionKey,
  recoveredMember,
  roomCodeForAdmission,
  legacyRoomCodeForAdmission,
  resolveCreation,
  creationOwner,
  creationCodeDigits,
} from "../src/admission";
import { newMember, newRoom, joinRoom, snapshot } from "../src/room";

const hostKey = "1".repeat(64),
  guestKey = "2".repeat(64);
test("admission keys are strong secret capabilities with stable public codes", async () => {
  assert.throws(() => admissionKey("short"));
  assert.throws(() => admissionKey("g".repeat(64)));
  const code = await roomCodeForAdmission(hostKey);
  assert.match(code, /^[0-9]{5}$/);
  assert.equal(code, await roomCodeForAdmission(hostKey));
  assert.notEqual(code, await roomCodeForAdmission(guestKey));
  assert.equal(code.includes(hostKey), false);
});
test("same admission recovers a full or already active room without another member", () => {
  const host = newMember("host", "a".repeat(64), "AAAAAAAA", "red", hostKey);
  const room = newRoom("123456ABCDEF", "presentation", 180, host, 1000);
  const guest = newMember(
    "guest",
    "b".repeat(64),
    "BBBBBBBB",
    "blue",
    guestKey,
  );
  joinRoom(room, guest, 1001);
  room.status = "active";
  assert.equal(recoveredMember(room, hostKey, "create")?.token, host.token);
  assert.equal(recoveredMember(room, guestKey, "join")?.token, guest.token);
  assert.equal(Object.keys(room.members).length, 2);
  assert.equal(recoveredMember(room, "3".repeat(64), "join"), undefined);
  assert.throws(() => recoveredMember(room, hostKey, "join"));
  assert.throws(() => recoveredMember(room, guestKey, "create"));
  const publicView = JSON.stringify(snapshot(room, "guest", 2000));
  assert.equal(publicView.includes(hostKey), false);
  assert.equal(publicView.includes(guestKey), false);
  assert.equal(publicView.includes(guest.token), false);
});

test("legacy response-loss recovery wins over new short-code allocation", async () => {
  const visits: { code: string; operation: string }[] = [];
  const response = await resolveCreation(hostKey, async (code, operation) => {
    visits.push({ code, operation });
    return Response.json({ recovered: true }, { status: 201 });
  });
  assert.equal(response.status, 201);
  assert.deepEqual(visits, [
    { code: await legacyRoomCodeForAdmission(hostKey), operation: "recover" },
  ]);
  assert.match(visits[0]!.code, /^[A-F0-9]{12}$/);
});
test("only missing legacy rooms allocate new numeric codes; errors never allocate a second room", async () => {
  for (const status of [201, 409, 410, 500, 503]) {
    let visits = 0;
    const result = await resolveCreation(hostKey, async () => {
      visits++;
      return new Response(null, { status });
    });
    assert.equal(visits, 1);
    assert.equal(result.status, status);
  }
  const visits: { code: string; operation: string }[] = [];
  await resolveCreation(hostKey, async (code, operation) => {
    visits.push({ code, operation });
    return new Response(null, { status: operation === "recover" ? 404 : 201 });
  });
  assert.deepEqual(visits, [
    { code: await legacyRoomCodeForAdmission(hostKey), operation: "recover" },
    { code: await roomCodeForAdmission(hostKey), operation: "create" },
  ]);
});
test("code collision is returned explicitly instead of probing a different code for the same secret", async () => {
  const collision = { error: "重複", code: "ROOM_CODE_COLLISION" };
  const response = await resolveCreation(hostKey, async (_code, operation) =>
    Response.json(operation === "recover" ? { error: "missing" } : collision, {
      status: operation === "recover" ? 404 : 409,
    }),
  );
  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), collision);
});
test("same create key recovers only its owner and rejects setting changes without collision classification", () => {
  const host = newMember("host", "a".repeat(64), "AAAAAAAA", "red", hostKey);
  const room = newRoom("01234", "presentation", 180, host, 1000);
  assert.equal(creationOwner(room, hostKey, "presentation", 180), host);
  assert.equal(creationOwner(room, guestKey, "presentation", 180), undefined);
  assert.throws(
    () => creationOwner(room, hostKey, "standard", 180),
    (error) => {
      assert.equal((error as { status: number }).status, 409);
      assert.equal((error as { code?: string }).code, undefined);
      return true;
    },
  );
  assert.throws(() => creationOwner(room, hostKey, "presentation", 300));
});

test("only explicit five-digit capability changes the legacy creation format", () => {
  assert.equal(creationCodeDigits(undefined), undefined);
  assert.equal(creationCodeDigits(5), 5);
  for (const value of [null, "5", 12, 4, 5.5, true, {}, []])
    assert.throws(() => creationCodeDigits(value));
});
test("legacy clients keep twelve-character creation but cannot duplicate a short-code session", async () => {
  const visits: { code: string; operation: string }[] = [];
  const result = await resolveCreation(
    hostKey,
    async (code, operation) => {
      visits.push({ code, operation });
      return new Response(null, {
        status: operation === "recover" ? 404 : 201,
      });
    },
    "legacy",
  );
  assert.equal(result.status, 201);
  assert.deepEqual(visits, [
    { code: await legacyRoomCodeForAdmission(hostKey), operation: "recover" },
    { code: await roomCodeForAdmission(hostKey), operation: "recover" },
    { code: await legacyRoomCodeForAdmission(hostKey), operation: "create" },
  ]);
  let count = 0;
  const existingShort = await resolveCreation(
    hostKey,
    async () => {
      count++;
      return new Response(null, { status: count === 1 ? 404 : 201 });
    },
    "legacy",
  );
  assert.equal(count, 2);
  assert.equal(existingShort.status, 409);
  assert.equal(
    ((await existingShort.json()) as { code?: string }).code,
    undefined,
  );
});
