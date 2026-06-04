const http = require('http');

const port = process.env.PORT || 3000;

// --- Readiness checks -------------------------------------------------------
//
// /health is only useful if it can actually report FAILURE — a health check
// that always returns 200 tells your load balancer / orchestrator nothing and
// defeats the rollback logic in scripts/deploy-with-rollback.sh (an unhealthy
// container would look healthy and never roll back).
//
// `readinessChecks` is a list of async functions. Each must resolve truthy
// when its dependency is reachable and reject / resolve falsy otherwise. The
// process records `started` once `listen` fires, which is a real (if minimal)
// readiness signal: before the listener is up, /health reports 503.
//
// TODO(you): wire your real dependencies here. Examples:
//   readinessChecks.push(async () => { await db.query('SELECT 1'); return true; });
//   readinessChecks.push(async () => (await redis.ping()) === 'PONG');
// A check that throws or returns falsy flips /health to 503 so deploys roll
// back and orchestrators stop routing traffic.
function createApp(options = {}) {
  const state = { started: false };
  const readinessChecks = options.readinessChecks || [
    // Default real signal: the HTTP listener must be bound. This is replaced
    // /augmented by callers with real dependency probes.
    async () => state.started,
  ];

  async function isReady() {
    const results = await Promise.allSettled(
      readinessChecks.map((check) => Promise.resolve().then(check))
    );
    return results.every(
      (r) => r.status === 'fulfilled' && Boolean(r.value)
    );
  }

  const server = http.createServer((req, res) => {
    if (req.url === '/health') {
      isReady()
        .then((ready) => {
          const code = ready ? 200 : 503;
          res.writeHead(code, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: ready ? 'ok' : 'unavailable' }));
        })
        .catch(() => {
          res.writeHead(503, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'unavailable' }));
        });
      return;
    }

    if (req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', message: 'Hello from Docker!' }));
      return;
    }

    // Unknown path: a real server must not answer 200 for everything.
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'not_found' }));
  });

  // Mark ready only once the listener is actually bound.
  server.on('listening', () => {
    state.started = true;
  });

  return { server, state, isReady, readinessChecks };
}

if (require.main === module) {
  const { server } = createApp();
  server.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}

module.exports = { createApp };
