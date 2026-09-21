import mysql from 'mysql2/promise';

export async function createMysqlStore(env = process.env) {
  if (!env.DB_PASSWORD) throw new Error('DB_PASSWORD is required for MySQL');
  const pool = mysql.createPool({
    host: env.DB_HOST,
    port: Number(env.DB_PORT || 3306),
    user: env.DB_USER || 'notepad',
    password: env.DB_PASSWORD,
    database: env.DB_NAME || 'notepad',
    charset: 'utf8mb4',
    timezone: 'Z',
    connectionLimit: 4,
    connectTimeout: 10000,
  });
  try {
    await pool.query(`CREATE TABLE IF NOT EXISTS notes (
      sequence_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      id CHAR(36) NOT NULL UNIQUE,
      content TEXT NOT NULL,
      created_at DATETIME(3) NOT NULL
    ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  } catch (error) {
    await pool.end();
    throw error;
  }
  return {
    async list() {
      const [rows] = await pool.query('SELECT id, content, created_at FROM notes ORDER BY sequence_id DESC');
      return rows.map((row) => ({ id: row.id, content: row.content, createdAt: row.created_at.toISOString() }));
    },
    async save(note) {
      await pool.execute('INSERT INTO notes (id, content, created_at) VALUES (?, ?, ?)',
        [note.id, note.content, new Date(note.createdAt)]);
    },
    async ping() { await pool.query('SELECT 1'); },
    async close() { await pool.end(); },
  };
}
