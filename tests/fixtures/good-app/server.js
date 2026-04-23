// Healthy app fixture: responds 200 on /health.
// Used by the rollback integration test to simulate a successful deploy.
const http = require('http');
const port = process.env.PORT || 3000;
http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', build: 'good' }));
    return;
  }
  res.writeHead(200);
  res.end('good');
}).listen(port, () => console.log(`good app on ${port}`));
