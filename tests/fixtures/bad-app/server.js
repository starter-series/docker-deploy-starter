// Broken app fixture: /health always returns 500.
// Used by the rollback integration test to simulate a failed deploy that
// should trigger rollback to the previous (good) image.
const http = require('http');
const port = process.env.PORT || 3000;
http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'broken', build: 'bad' }));
    return;
  }
  res.writeHead(500);
  res.end('bad');
}).listen(port, () => console.log(`bad app on ${port}`));
