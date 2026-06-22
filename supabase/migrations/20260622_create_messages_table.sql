-- 20260622_create_messages_table.sql
-- 创建 IM 聊天消息表

CREATE TABLE IF NOT EXISTS messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  content TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 开启 Realtime 实时订阅支持 (关键：只有开启这个，WebSocket 才能监听到新消息)
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- 配置 RLS (所有人可读可写，仅用于测试，生产环境需加入 Auth 鉴权)
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public messages are viewable by everyone." ON messages FOR SELECT USING (true);
CREATE POLICY "Public messages are insertable by everyone." ON messages FOR INSERT WITH CHECK (true);

-- 插入一条初始问候消息
INSERT INTO messages (content, sender_id) VALUES
  ('欢迎来到智选超级 APP！WebSocket 长连接已建立，你可以开始实时聊天了 🚀', 'system_bot');