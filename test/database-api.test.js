import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApp } from '../src/app.js';

test('DB 저장소로 메모 저장·조회 및 연결 장애 감지', async () => {
  const saved = [];
  let unavailable = false;
  const store = {
    async ping() { if (unavailable) throw new Error('Simulated database outage'); },
    async save(note) { saved.unshift(note); },
    async list() { return saved; },
  };
  const app = createApp({ store });
  await new Promise((resolve) => app.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${app.address().port}`;
  try {
    assert.deepEqual(await (await fetch(`${url}/health`)).json(), { status: 'ok', storage: 'mysql' });
    const response = await fetch(`${url}/api/notes`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: "한글 📝 'quoted'" }),
    });
    assert.equal(response.status, 201);
    const note = await response.json();
    assert.equal(saved[0].content, "한글 📝 'quoted'");
    assert.deepEqual(await (await fetch(`${url}/api/notes`)).json(), [note]);
    unavailable = true;
    assert.equal((await fetch(`${url}/health`)).status, 500);
  } finally { await new Promise((resolve) => app.close(resolve)); }
});
