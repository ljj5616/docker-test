import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { createApp } from '../src/app.js';

async function start(dataDir) {
  const app = createApp({ dataDir });
  await new Promise((resolve) => app.listen(0, '127.0.0.1', resolve));
  return { app, url: `http://127.0.0.1:${app.address().port}` };
}
async function close(app) { await new Promise((resolve) => app.close(resolve)); }
test('저장, 동시 요청, 서버 재시작 후 데이터 유지', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'notepad-'));
  let server = await start(dir);
  try {
    assert.deepEqual(await (await fetch(`${server.url}/api/notes`)).json(), []);
    const results = await Promise.all(Array.from({ length: 12 }, (_, i) => fetch(`${server.url}/api/notes`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content: `메모 ${i}\n두 번째 줄` }),
    })));
    assert.ok(results.every((r) => r.status === 201));
    await close(server.app);
    server = await start(dir);
    const notes = await (await fetch(`${server.url}/api/notes`)).json();
    assert.equal(notes.length, 12);
    assert.equal(new Set(notes.map((note) => note.id)).size, 12);
    assert.ok(notes.some((note) => note.content === '메모 0\n두 번째 줄'));
  } finally { await close(server.app); await rm(dir, { recursive: true, force: true }); }
});
test('입력 검증, 정적 페이지, 상태 확인, 잘못된 저장 파일 보호', async () => {
  const dir = await mkdtemp(path.join(tmpdir(), 'notepad-'));
  const { app, url } = await start(dir);
  const post = (body, type = 'application/json') => fetch(`${url}/api/notes`, { method: 'POST', headers: { 'Content-Type': type }, body });
  try {
    for (const content of ['', '   ', 123, 'a'.repeat(10001)]) assert.equal((await post(JSON.stringify({ content }))).status, 400);
    assert.equal((await post('{')).status, 400);
    assert.equal((await post('null')).status, 400);
    assert.equal((await post('{}', 'text/plain')).status, 415);
    assert.equal((await post(JSON.stringify({ content: 'a'.repeat(70000) }))).status, 413);
    assert.equal((await fetch(`${url}/missing`)).status, 404);
    assert.deepEqual(await (await fetch(`${url}/health`)).json(), { status: 'ok' });
    assert.match(await (await fetch(url)).text(), /작은 메모장/);
    assert.equal((await fetch(`${url}/style.css`)).status, 200);
    await writeFile(path.join(dir, 'notes.json'), 'broken');
    assert.equal((await post(JSON.stringify({ content: '보호 테스트' }))).status, 500);
  } finally { await close(app); await rm(dir, { recursive: true, force: true }); }
});
