import http from 'node:http';
import { mkdir, readFile, writeFile, rename } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const root = fileURLToPath(new URL('../', import.meta.url));
const MAX_BYTES = 64 * 1024;
const assets = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']],
  ['/style.css', ['style.css', 'text/css; charset=utf-8']],
]);

export function createApp({ dataDir = process.env.DATA_DIR || path.join(root, 'data') } = {}) {
  const file = path.join(dataDir, 'notes.json');
  let queue = Promise.resolve();
  async function readNotes() {
    try {
      const notes = JSON.parse(await readFile(file, 'utf8'));
      if (!Array.isArray(notes)) throw new Error('Invalid notes file');
      return notes;
    } catch (error) {
      if (error.code === 'ENOENT') return [];
      throw error;
    }
  }
  function json(res, status, data) {
    res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(data));
  }
  return http.createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Security-Policy', "default-src 'self'; frame-ancestors 'none'; base-uri 'none'");
    try {
      const url = new URL(req.url, 'http://localhost');
      if (req.method === 'GET' && url.pathname === '/health') return json(res, 200, { status: 'ok' });
      if (req.method === 'GET' && url.pathname === '/api/notes') {
        await queue;
        return json(res, 200, await readNotes());
      }
      if (req.method === 'POST' && url.pathname === '/api/notes') {
        if (req.headers['content-type']?.split(';')[0].trim() !== 'application/json') {
          return json(res, 415, { error: 'JSON 형식으로 보내주세요.' });
        }
        const chunks = [];
        let size = 0;
        for await (const chunk of req) {
          size += chunk.length;
          if (size > MAX_BYTES) return json(res, 413, { error: '메모가 너무 큽니다.' });
          chunks.push(chunk);
        }
        let body;
        try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
        catch { return json(res, 400, { error: '올바른 JSON이 아닙니다.' }); }
        if (typeof body?.content !== 'string' || !body.content.trim() || body.content.trim().length > 10000) {
          return json(res, 400, { error: '메모를 1~10,000자 이내로 입력해주세요.' });
        }
        const note = { id: randomUUID(), content: body.content.trim(), createdAt: new Date().toISOString() };
        const save = queue.then(async () => {
          const notes = await readNotes();
          notes.unshift(note);
          await mkdir(dataDir, { recursive: true });
          await writeFile(`${file}.tmp`, JSON.stringify(notes, null, 2), 'utf8');
          await rename(`${file}.tmp`, file);
        });
        queue = save.catch(() => {});
        await save;
        return json(res, 201, note);
      }
      const asset = assets.get(url.pathname);
      if (req.method === 'GET' && asset) {
        const content = await readFile(path.join(root, 'public', asset[0]));
        res.writeHead(200, { 'Content-Type': asset[1], 'Cache-Control': 'no-cache' });
        return res.end(content);
      }
      json(res, 404, { error: '찾을 수 없습니다.' });
    } catch (error) {
      console.error(error);
      if (!res.headersSent) json(res, 500, { error: '저장소에 접근하지 못했습니다. 다시 시도해주세요.' });
      else res.end();
    }
  });
}
