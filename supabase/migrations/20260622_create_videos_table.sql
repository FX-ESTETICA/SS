-- 20260622_create_videos_table.sql
-- 初始迁移：创建核心视频表并配置行级安全 (RLS)

CREATE TABLE IF NOT EXISTS videos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  video_url TEXT NOT NULL,
  author_name TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 配置顶级安全规则：允许所有人读取视频，但只有管理员能修改
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone." 
  ON videos FOR SELECT 
  USING (true);

-- 插入初始测试数据 (使用 Cloudflare R2 链接)
INSERT INTO videos (video_url, author_name, description) VALUES
  ('https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/test_video_1.mp4', '@全球CEO', '云端连接成功！这是来自 Cloudflare R2 边缘节点的真实视频源 🌍🚀'),
  ('https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/test_video_2.mp4', '@自然探索者', '完全免费的流出流量，这才是真正的降维打击 🐝'),
  ('https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/test_video_1.mp4', '@架构师', '无论你刷多少遍，都不用付一分钱宽带费 💻');
