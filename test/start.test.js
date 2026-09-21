import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';

test('프로세스 관리자가 진입 파일을 import해도 HTTP 서버가 시작된다', { timeout: 15000 }, async () => {
  const entry = new URL('../src/server.js', import.meta.url).href;
  const child = spawn(process.execPath, ['--input-type=module', '-e', `await import(${JSON.stringify(entry)})`], {
    env: { ...process.env, HOST: '127.0.0.1', PORT: '0' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const exited = once(child, 'exit');
  let output = '';
  let errors = '';
  child.stderr.on('data', (chunk) => { errors += chunk; });
  try {
    const url = await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`서버 시작 실패: ${errors}`)), 8000);
      child.once('error', (error) => { clearTimeout(timer); reject(error); });
      child.once('exit', () => { clearTimeout(timer); reject(new Error(`서버 조기 종료: ${errors}`)); });
      child.stdout.on('data', (chunk) => {
        output += chunk;
        const match = output.match(/http:\/\/127\.0\.0\.1:\d+/);
        if (match) { clearTimeout(timer); resolve(match[0]); }
      });
    });
    const response = await fetch(`${url}/health`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { status: 'ok' });
  } finally {
    child.kill();
    await exited;
  }
});
