import { createApp } from './app.js';
import { createMysqlStore } from './mysql-store.js';

const store = process.env.DB_HOST ? await createMysqlStore() : undefined;
const server = createApp({ store });
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';
server.listen(port, host, () => {
  console.log(`메모장 실행: http://${host}:${server.address().port}`);
});
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(async () => {
      await store?.close();
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 10000).unref();
  });
}
