// 极简静态服务器：node tools/serve.js [port]
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(fileURLToPath(new URL('.', import.meta.url)), '..');
const port = Number(process.argv[2] || 5173);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
};

createServer(async (req, res) => {
  try {
    const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    let rel = normalize(urlPath).replace(/^([/\\])+/, '');
    if (rel === '') rel = 'index.html';
    const filePath = join(root, rel);
    if (filePath !== root && !filePath.startsWith(root + sep)) {
      res.writeHead(403);
      return res.end('Forbidden');
    }
    const data = await readFile(filePath);
    const type = MIME[extname(filePath).toLowerCase()] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end('Not Found');
  }
}).listen(port, () => {
  console.log(`暗夜幸存者已启动 → http://localhost:${port} （Ctrl+C 停止）`);
});
