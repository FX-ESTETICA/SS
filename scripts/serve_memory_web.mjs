import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const webRoot = path.resolve(__dirname, '..', 'apps', 'zhixuan_main', 'web');
const port = Number(process.env.MEMORY_WEB_PORT ?? 4173);

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function resolvePath(requestUrl) {
  const url = new URL(requestUrl, `http://127.0.0.1:${port}`);
  let pathname = decodeURIComponent(url.pathname);
  if (pathname === '/') {
    pathname = '/memory/index.html';
  }
  if (pathname.endsWith('/')) {
    pathname += 'index.html';
  }
  return path.normalize(path.join(webRoot, pathname));
}

const server = http.createServer((request, response) => {
  const filePath = resolvePath(request.url ?? '/');

  if (!filePath.startsWith(webRoot)) {
    response.writeHead(403);
    response.end('Forbidden');
    return;
  }

  fs.readFile(filePath, (error, content) => {
    if (error) {
      response.writeHead(404);
      response.end('Not Found');
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    response.writeHead(200, {
      'Content-Type': contentTypes[ext] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
    });
    response.end(content);
  });
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Memory web server running at http://127.0.0.1:${port}/memory/`);
});
