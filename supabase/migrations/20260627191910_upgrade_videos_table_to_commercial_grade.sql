-- 商业级大改造：彻底重构 videos 表

-- 1. 为了保证数据平滑过渡，我们先清空测试期的脏数据
TRUNCATE TABLE videos;

-- 2. 添加商业级核心字段
ALTER TABLE videos
  -- 我们暂时保留 author_name 方便测试，但增加 author_id 建立真实的关联约束
  ADD COLUMN IF NOT EXISTS author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  -- 封面图
  ADD COLUMN IF NOT EXISTS cover_url TEXT,
  -- 计数器
  ADD COLUMN IF NOT EXISTS view_count BIGINT DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS like_count BIGINT DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS comment_count BIGINT DEFAULT 0 NOT NULL,
  ADD COLUMN IF NOT EXISTS share_count BIGINT DEFAULT 0 NOT NULL,
  -- 物理属性
  ADD COLUMN IF NOT EXISTS duration_seconds DECIMAL(5,2),
  ADD COLUMN IF NOT EXISTS width INTEGER,
  ADD COLUMN IF NOT EXISTS height INTEGER;

-- 3. 建立极其关键的性能索引 (B-Tree 索引)
-- 用于 "按最新时间排序" 的极速分页查询
CREATE INDEX IF NOT EXISTS idx_videos_created_at ON videos(created_at DESC);
-- 用于 "查看某个用户的视频列表" 的极速查询
CREATE INDEX IF NOT EXISTS idx_videos_author_id ON videos(author_id);
-- 用于 "爆款推荐" 按点赞/播放量排序的极速查询
CREATE INDEX IF NOT EXISTS idx_videos_popularity ON videos(view_count DESC, like_count DESC);
