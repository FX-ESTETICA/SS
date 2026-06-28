import pkg from 'pg';
const { Client } = pkg;

// 你记忆里的 Supabase 数据库连接密码（如果你设置过）
// 如果没有，这步可能会失败，但我必须尝试直连底层 Postgres
const connectionString = 'postgresql://postgres.izpolbeqdttjffbemvjr:[YOUR_PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres';

async function upgrade() {
  const client = new Client({
    connectionString: connectionString,
  });

  try {
    await client.connect();
    console.log('成功直连底层 Postgres 引擎...');

    // 强行注入所有字段
    await client.query(`
      ALTER TABLE videos
        ADD COLUMN IF NOT EXISTS cover_url TEXT,
        ADD COLUMN IF NOT EXISTS view_count BIGINT DEFAULT 0 NOT NULL,
        ADD COLUMN IF NOT EXISTS like_count BIGINT DEFAULT 0 NOT NULL,
        ADD COLUMN IF NOT EXISTS comment_count BIGINT DEFAULT 0 NOT NULL,
        ADD COLUMN IF NOT EXISTS share_count BIGINT DEFAULT 0 NOT NULL,
        ADD COLUMN IF NOT EXISTS duration_seconds DECIMAL(5,2),
        ADD COLUMN IF NOT EXISTS width INTEGER,
        ADD COLUMN IF NOT EXISTS height INTEGER;
    `);
    
    console.log('表结构物理升级完毕！');
    
    const res = await client.query(`SELECT column_name FROM information_schema.columns WHERE table_name = 'videos';`);
    console.log('当前真实存在的列:', res.rows.map(r => r.column_name).join(', '));
    
  } catch (err) {
    console.error('连接失败，这说明我们需要你在网页端手动执行 SQL。', err.message);
  } finally {
    await client.end();
  }
}

upgrade();