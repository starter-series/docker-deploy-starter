'use strict';

// Behavioral HTTP tests for app/server.js.
//
// Starts the real server on an ephemeral port and makes real requests:
//   - GET /health           -> 200 + {"status":"ok"} when ready
//   - GET /                 -> 200 + greeting JSON
//   - GET /<unknown>        -> 404 (NOT 200-for-everything)
//   - GET /health (failing readiness check injected) -> 503
//
// The 404 assertion fails if the "200 for every path" regression returns.
// The 503 assertion fails if /health is hardcoded to 200 and cannot express
// failure (the MAJOR finding) — it drives the real isReady() path.

const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../app/server.js');

// Start a server on an ephemeral port (0) and return { port, close }.
function start(options) {
  const { server } = createApp(options);
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      resolve({
        port,
        close: () =>
          new Promise((res) => server.close(() => res())),
      });
    });
  });
}

async function get(port, urlPath) {
  const res = await fetch(`http://127.0.0.1:${port}${urlPath}`);
  let body = null;
  const text = await res.text();
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: res.status, body };
}

test('GET /health returns 200 and {status:"ok"} when ready', async () => {
  const srv = await start();
  try {
    const res = await get(srv.port, '/health');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { status: 'ok' });
  } finally {
    await srv.close();
  }
});

test('GET / returns 200 with greeting JSON', async () => {
  const srv = await start();
  try {
    const res = await get(srv.port, '/');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
    assert.ok(
      typeof res.body.message === 'string' && res.body.message.length > 0,
      'expected a non-empty message'
    );
  } finally {
    await srv.close();
  }
});

test('GET unknown path returns 404 (not 200-for-everything)', async () => {
  const srv = await start();
  try {
    for (const p of ['/totally-unknown', '/api/nope', '/health/extra', '/favicon.ico']) {
      const res = await get(srv.port, p);
      assert.equal(res.status, 404, `${p} should be 404, got ${res.status}`);
    }
  } finally {
    await srv.close();
  }
});

test('GET /health returns 503 when a readiness check fails', async () => {
  // Inject a failing dependency probe — this proves /health reflects a real
  // readiness signal and can report failure, instead of always 200.
  const srv = await start({
    readinessChecks: [async () => false],
  });
  try {
    const res = await get(srv.port, '/health');
    assert.equal(res.status, 503, 'failing readiness must yield 503');
    assert.equal(res.body.status, 'unavailable');
  } finally {
    await srv.close();
  }
});

test('GET /health returns 503 when a readiness check throws', async () => {
  const srv = await start({
    readinessChecks: [
      async () => {
        throw new Error('db unreachable');
      },
    ],
  });
  try {
    const res = await get(srv.port, '/health');
    assert.equal(res.status, 503, 'throwing readiness must yield 503');
    assert.equal(res.body.status, 'unavailable');
  } finally {
    await srv.close();
  }
});

test('GET /health returns 200 only when every readiness check passes', async () => {
  const srv = await start({
    readinessChecks: [async () => true, async () => true],
  });
  try {
    const res = await get(srv.port, '/health');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { status: 'ok' });
  } finally {
    await srv.close();
  }
});
