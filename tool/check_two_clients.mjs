// Exercise the production Flutter UI and its real HTTP/WebSocket transport.
// This script never injects game results or calls room actions directly.
import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';

const url = process.env.TSUNAGUN_WEB_URL ?? 'http://127.0.0.1:8080';
const out = path.resolve(process.env.TSUNAGUN_CHECK_OUTPUT ?? 'build/device-validation');
const packagePath = process.env.TSUNAGUN_PLAYWRIGHT ??
  'build/device-validation-tools/node_modules/playwright-core/index.mjs';
const { chromium } = await import(pathToFileURL(path.resolve(packagePath)));
const headed = process.argv.includes('--headed');
const scenario = process.argv.find(arg => arg.startsWith('--scenario='))?.split('=')[1] ?? 'success';
assert.ok(['success', 'failure', 'standard'].includes(scenario), 'Unknown scenario');
await mkdir(out, { recursive: true });
const report = { startedAt: new Date().toISOString(), url, scenario, headed, checks: [], errors: [] };
const clients = [];
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
function pass(name, details = {}) {
  report.checks.push({ name, ...details });
  console.log(`PASS: ${name}`);
}
async function until(predicate, label, timeout = 20000) {
  const deadline = performance.now() + timeout;
  while (performance.now() < deadline) {
    if (await predicate()) return;
    await sleep(15);
  }
  throw new Error(`Timeout: ${label}`);
}
function observe(client, snapshot) {
  if (!snapshot) return;
  if (!client.latest || snapshot.code !== client.latest.code || snapshot.revision >= client.latest.revision) {
    client.latest = snapshot;
  }
}
async function enableSemantics(page) {
  await page.locator('flt-semantics-placeholder').waitFor({ state: 'attached', timeout: 45000 });
  await page.locator('flt-semantics-placeholder').evaluate(el => el.click());
  await page.locator('flt-semantics[role]').first().waitFor({ state: 'attached', timeout: 45000 });
}
async function launch(name, index) {
  const browser = await chromium.launch({
    headless: !headed,
    ...(process.env.TSUNAGUN_BROWSER ? { executablePath: process.env.TSUNAGUN_BROWSER } : {}),
    ignoreDefaultArgs: [
      '--disable-background-timer-throttling',
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
    ],
    args: [
      ...(process.env.WAYLAND_DISPLAY && headed ? ['--ozone-platform=wayland'] : []),
      `--window-position=${index * 650 + 8},8`, '--window-size=640,1000',
    ],
  });
  const context = await browser.newContext({ viewport: { width: 620, height: 920 }, locale: 'ja-JP' });
  const page = await context.newPage();
  const client = { name, browser, context, page, latest: null, clockBase: null, pings: new Map(), wsCount: 0, readySocket: 0, rtts: [] };
  clients.push(client);
  page.on('pageerror', error => report.errors.push({ client: name, message: error.message }));
  page.on('response', async response => {
    if (!/\/rooms(?:\/|$)/.test(new URL(response.url()).pathname)) return;
    try { observe(client, (await response.json()).snapshot); } catch { /* Non-JSON error */ }
  });
  page.on('websocket', ws => {
    if (!/\/rooms\/[^/]+\/socket$/.test(ws.url())) return;
    const socketNumber = ++client.wsCount;
    ws.on('close', () => {
      if (client.readySocket === socketNumber) client.readySocket = 0;
    });
    ws.on('framesent', ({ payload }) => {
      const message = JSON.parse(String(payload));
      if (message.type === 'ping') client.pings.set(message.id, performance.now());
      // Auth tokens and admission keys are intentionally neither retained nor logged.
    });
    ws.on('framereceived', ({ payload }) => {
      const received = performance.now();
      const message = JSON.parse(String(payload));
      observe(client, message.snapshot);
      if (message.snapshot) client.readySocket = socketNumber;
      if (message.type === 'pong' && client.pings.has(message.id)) {
        const sent = client.pings.get(message.id);
        client.pings.delete(message.id);
        const rtt = received - sent;
        if (rtt < 1000) {
          client.clockBase = message.serverNow + rtt / 2 - received;
          client.rtts.push(Math.round(rtt));
        }
      }
    });
  });
  await page.goto(url);
  await enableSemantics(page);
  await page.getByRole('button', { name: 'ルームをつくる', exact: true }).waitFor();
  return client;
}
async function click(client, name) {
  await client.page.getByRole('button', { name, exact: true }).click({ timeout: 20000 });
}
async function shots(stage) {
  await Promise.all(clients.map(c => c.page.screenshot({ path: path.join(out, `${scenario}-${stage}-${c.name}.png`) })));
}
async function profile(client) {
  const values = [
    ['ニックネーム', `動作確認${client.name}`],
    ['趣味', 'ゲーム'],
    ['ひとこと（任意）', '二端末の通信確認'],
  ];
  for (const [name, value] of values) {
    const field = client.page.getByRole('textbox', { name, exact: true });
    await field.click();
    // Flutter attaches its platform text editor after focus changes. Send real
    // keyboard input to that active editor, after the focus frame completes.
    await sleep(200);
    await client.page.keyboard.insertText(value);
    await sleep(150);
    assert.equal(await field.inputValue(), value, `${client.name}: ${name}`);
  }
  for (const [name, value] of values) {
    assert.equal(await client.page.getByRole('textbox', { name, exact: true }).inputValue(), value);
  }
  await click(client, 'この缶で参加する');
}
async function reload(client) {
  const id = client.latest.selfId;
  client.latest = null;
  client.readySocket = 0;
  client.clockBase = null;
  await client.page.reload();
  await enableSemantics(client.page);
  await until(() => client.latest?.selfId === id && client.readySocket === client.wsCount && client.readySocket > 0,
    `${client.name} session and authenticated socket restored`);
  await sleep(100);
  assert.equal(client.latest.selfId, id);
}
async function connect(a, b, cameraDenied = false) {
  await Promise.all([click(a, 'ツナがる'), click(b, 'ツナがる')]);
  if (cameraDenied) {
    await b.context.grantPermissions([]);
    await click(b, '相手のQRを読み取る');
    await b.page.getByText(/カメラを使えません。/).last().waitFor({ timeout: 20000 });
    await click(b, 'コードを入力する');
    pass('camera denial preserves the manual peer-code path');
  } else {
    await click(b, '相手のコードを入力する');
  }
  await b.page.getByRole('textbox', { name: '相手のコード', exact: true }).fill(a.latest.pairCode.toLowerCase());
  await click(b, 'ツナがる');
  await until(() => clients.every(c => c.latest?.encounter?.status === 'offered'), 'pair offered');
  assert.equal(a.latest.encounter.id, b.latest.encounter.id);
}
async function ready() {
  await Promise.all(clients.map(c => click(c, '準備OK！')));
  await until(() => clients.every(c => c.latest?.encounter?.startAt), 'shared countdown');
  assert.equal(clients[0].latest.encounter.startAt, clients[1].latest.encounter.startAt);
}
async function returnHome() {
  await Promise.all(clients.map(c => click(c, 'ホームへ戻る')));
  await Promise.all(clients.map(c => c.page.getByRole('button', { name: 'ツナがる', exact: true }).waitFor({ timeout: 20000 })));
}
async function mouseAt(client, serverAt) {
  await until(() => client.clockBase !== null, 'server clock calibration');
  while (client.clockBase + performance.now() < serverAt) {
    await sleep(Math.max(1, Math.min(20, serverAt - client.clockBase - performance.now() - 2)));
  }
  // Real mouse events pass through Flutter's existing game GestureDetector.
  await client.page.mouse.click(310, 530);
}
async function coopSuccess(a, b) {
  const flights = [1000, 800, 650];
  for (let level = 0; level < 3; level++) {
    await until(() => a.latest?.encounter?.coop?.level === level && a.latest.encounter.coop.levelStartAt > 0, `level ${level + 1}`);
    for (let hop = 1; hop <= 6; hop++) {
      const e = a.latest.encounter;
      const senderId = e.playerIds[hop % 2 === 1 ? 0 : 1];
      const sender = clients.find(c => c.latest.selfId === senderId);
      const at = e.coop.levelStartAt + flights[level] * (1.3 + hop - 1);
      await mouseAt(sender, at);
      await until(() => a.latest.encounter?.status === 'finished' || a.latest.encounter?.coop?.level > level || a.latest.encounter?.coop?.hop > hop, `co-op accepted ${level + 1}/${hop}`, 4000);
      assert.notEqual(a.latest.encounter?.result?.outcome, 'coopFailure', `Failed at level ${level + 1}, hop ${hop}`);
    }
  }
}

try {
  const a = await launch('A', 0);
  const b = await launch('B', 1);
  report.browser = a.browser.version();
  assert.notEqual(a.browser, b.browser);
  pass('two independent browser processes and storage areas');
  await shots('01-entry');
  if (scenario !== 'standard') await a.page.getByRole('switch', { name: /^発表用ルーム/ }).click();
  await click(a, 'ルームをつくる');
  await profile(a);
  await until(() => a.latest?.code, 'room creation');
  assert.match(a.latest.code, /^\d{5}$/);
  if (scenario === 'standard') {
    assert.equal(await a.page.getByRole('button', { name: '交流をはじめる', exact: true }).getAttribute('aria-disabled'), 'true');
    pass('standard room requires at least two completed profiles');
  }
  await click(b, 'ルームに参加する');
  await b.page.getByRole('textbox', { name: '5桁のルームコード', exact: true }).fill('123');
  await click(b, 'ルームに参加する');
  await b.page.getByText('5桁のルームコードを確かめてください。', { exact: true }).last().waitFor();
  pass('invalid room code stays in the input screen');
  await b.page.getByRole('textbox', { name: '5桁のルームコード', exact: true }).fill(a.latest.code);
  await click(b, 'ルームに参加する');
  await profile(b);
  await until(() => clients.every(c => c.latest?.participants?.filter(p => p.ready).length === 2), 'both profiles saved');
  assert.notEqual(a.latest.selfId, b.latest.selfId);
  assert.equal(a.latest.code, b.latest.code);
  await shots('02-lobby');
  await reload(b);
  pass('reload restores the same guest membership and profile');
  await click(a, '交流をはじめる');
  await until(() => clients.every(c => c.latest?.status === 'active'), 'shared start');
  assert.equal(a.latest.endsAt, b.latest.endsAt);
  assert.ok(clients.every(c => c.wsCount > 0));
  pass('real HTTPS/WSS room, distinct players, shared event deadline');
  await shots('03-home');

  await connect(a, b, true);
  const socketCounts = clients.map(c => c.wsCount);
  for (const client of [a, b, a, b]) {
    await client.page.bringToFront();
    await sleep(100);
  }
  for (const [index, client] of clients.entries()) {
    assert.equal(await client.page.evaluate(() => document.visibilityState), 'visible');
    assert.equal(client.wsCount, socketCounts[index]);
    assert.equal(client.latest.encounter.status, 'offered');
  }
  pass('switching focus between visible windows retains both sockets and the encounter');
  await ready();
  await shots('04-countdown');
  // Refresh during an uncompleted encounter closes the real socket.
  await reload(b);
  await until(() => clients.every(c => c.latest.encounter?.status === 'cancelled'), 'disconnect cancels without rewards');
  assert.ok(clients.every(c => c.latest.followers.length === 0));
  pass('refresh during game cancels for both without loss or reward');
  await returnHome();

  await connect(a, b);
  await ready();
  if (scenario === 'standard') {
    await mouseAt(a, a.latest.encounter.startAt + 800);
    await mouseAt(b, b.latest.encounter.startAt + 1400);
  }
  // Presentation scenarios deliberately let both real clients fall.
  await until(() => clients.every(c => c.latest.encounter?.status === 'finished'), 'duel finished', 15000);
  for (const client of clients) {
    assert.equal(client.latest.followers.length, 1);
    const expected = scenario === 'standard' && client === b ? 'normal' : 'bone';
    assert.equal(client.latest.followers[0].kind, expected);
  }
  await Promise.all(clients.map(c => c.page.getByRole('button', { name: 'ホームへ戻る', exact: true }).waitFor({ timeout: 20000 })));
  await shots('05-duel-result');
  pass(scenario === 'standard' ? 'real taps determine winner and loser on both clients' : 'both-fall gives exactly one bone to each real player');
  const originalFollower = b.latest.followers[0].id;
  await reload(b);
  assert.equal(b.latest.followers.length, 1);
  assert.equal(b.latest.followers[0].id, originalFollower);
  pass('confirmed result survives reload without duplicate followers');
  await returnHome();

  if (scenario === 'standard') {
    await Promise.all([click(a, 'ツナがる'), click(b, 'ツナがる')]);
    await click(b, '相手のコードを入力する');
    await b.page.getByRole('textbox', { name: '相手のコード', exact: true }).fill(a.latest.pairCode);
    const rejected = b.page.waitForResponse(response =>
      /\/actions$/.test(response.url()) && response.request().postDataJSON()?.type === 'pair');
    await click(b, 'ツナがる');
    assert.equal((await rejected).status(), 409);
    assert.ok(clients.every(c => c.latest.followers.length === 1));
    await returnHome();
    pass('standard room rejects a completed peer without duplicate rewards');
  }

  if (scenario !== 'standard') {
    await connect(a, b);
    assert.equal(a.latest.encounter.kind, 'coop');
    await ready();
    await shots('06-coop');
    if (scenario === 'success') await coopSuccess(a, b);
    else {
      const e = a.latest.encounter;
      const first = clients.find(c => c.latest.selfId === e.playerIds[0]);
      await mouseAt(first, e.coop.levelStartAt + 150);
    }
    await until(() => clients.every(c => c.latest.encounter?.status === 'finished'), 'cooperation finished', 15000);
    for (const client of clients) {
      const s = client.latest;
      assert.equal(s.encounter.result.outcome, scenario === 'success' ? 'coopSuccess' : 'coopFailure');
      assert.equal(s.followers.length, scenario === 'success' ? 1 : 2);
      assert.ok(s.followers.every(f => f.kind === (scenario === 'success' ? 'normal' : 'bone')));
      assert.equal(s.encounter.result.delta, scenario === 'success' ? 2 : 1);
    }
    await Promise.all(clients.map(c => c.page.getByRole('button', { name: 'ホームへ戻る', exact: true }).waitFor({ timeout: 15000 })));
    await shots('07-coop-result');
    pass(scenario === 'success' ? '18 real alternating taps across 3 levels; both bones REBORN once' : 'early real tap fails co-op and awards one additional bone to each');
    await returnHome();
  }

  await click(a, '交流を終えて綱引きへ');
  await click(a, '綱引きへ進む');
  await until(() => clients.every(c => c.latest?.status === 'finale'), 'shared final snapshot');
  assert.deepEqual(a.latest.finalSnapshot, b.latest.finalSnapshot);
  await shots('08-finale-wait');
  await click(a, '綱引きスタート！');
  await until(() => clients.every(c => c.latest.finaleStartsAt), 'shared finale start');
  assert.equal(a.latest.finaleStartsAt, b.latest.finaleStartsAt);
  await Promise.all(clients.map(c => c.page.getByRole('button', { name: 'みんなの活躍を見る', exact: true }).waitFor({ timeout: 20000 })));
  await shots('09-finale');
  await Promise.all(clients.map(c => click(c, 'みんなの活躍を見る')));
  await shots('10-awards');
  pass('identical final totals, common tug-of-war start and both ranking screens', {
    redPower: a.latest.finalSnapshot.redPower, bluePower: a.latest.finalSnapshot.bluePower,
  });
  assert.equal(report.errors.length, 0, 'Browser runtime errors');
  pass('no browser runtime exceptions');
  report.rttMs = clients.map(c => ({ client: c.name, samples: c.rtts.length, max: Math.max(...c.rtts) }));
  report.passed = true;
} catch (error) {
  report.passed = false;
  report.failure = error.message;
  console.error(`FAIL: ${error.message}`);
  await shots('failure').catch(() => {});
  for (const c of clients) {
    await writeFile(path.join(out, `${scenario}-failure-${c.name}.txt`), await c.page.locator('body').ariaSnapshot().catch(() => 'Page unavailable'));
  }
  process.exitCode = 1;
} finally {
  report.finishedAt = new Date().toISOString();
  report.clientStates = clients.map(c => ({
    client: c.name, roomStatus: c.latest?.status, socketCount: c.wsCount,
    encounter: c.latest?.encounter && {
      kind: c.latest.encounter.kind, status: c.latest.encounter.status,
      level: c.latest.encounter.coop?.level, hop: c.latest.encounter.coop?.hop,
    },
    followerCount: c.latest?.followers.length,
  }));
  await writeFile(path.join(out, `${scenario}-report.json`), JSON.stringify(report, null, 2));
  await Promise.all(clients.map(c => c.browser.close()));
}
