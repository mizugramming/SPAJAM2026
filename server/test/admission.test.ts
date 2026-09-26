import test from 'node:test';
import assert from 'node:assert/strict';
import { admissionKey, recoveredMember, roomCodeForAdmission } from '../src/admission';
import { newMember, newRoom, joinRoom, snapshot } from '../src/room';

const hostKey = '1'.repeat(64), guestKey = '2'.repeat(64);
test('admission keys are strong secret capabilities with stable public codes', async () => {
  assert.throws(() => admissionKey('short'));
  assert.throws(() => admissionKey('g'.repeat(64)));
  const code = await roomCodeForAdmission(hostKey);
  assert.match(code, /^[A-F0-9]{12}$/);
  assert.equal(code, await roomCodeForAdmission(hostKey));
  assert.notEqual(code, await roomCodeForAdmission(guestKey));
  assert.equal(code.includes(hostKey), false);
});
test('same admission recovers a full or already active room without another member', () => {
  const host = newMember('host','a'.repeat(64),'AAAAAAAA','red',hostKey);
  const room = newRoom('123456ABCDEF','presentation',180,host,1000);
  const guest = newMember('guest','b'.repeat(64),'BBBBBBBB','blue',guestKey);
  joinRoom(room,guest,1001);
  room.status = 'active';
  assert.equal(recoveredMember(room,hostKey,'create')?.token, host.token);
  assert.equal(recoveredMember(room,guestKey,'join')?.token, guest.token);
  assert.equal(Object.keys(room.members).length,2);
  assert.equal(recoveredMember(room,'3'.repeat(64),'join'),undefined);
  assert.throws(() => recoveredMember(room,hostKey,'join'));
  assert.throws(() => recoveredMember(room,guestKey,'create'));
  const publicView = JSON.stringify(snapshot(room,'guest',2000));
  assert.equal(publicView.includes(hostKey),false);
  assert.equal(publicView.includes(guestKey),false);
  assert.equal(publicView.includes(guest.token),false);
});
