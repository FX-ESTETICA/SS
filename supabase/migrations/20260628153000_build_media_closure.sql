-- 构建 Supabase + R2 的闭环媒体元数据层，并收紧匿名写权限

CREATE TABLE IF NOT EXISTS media_assets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  media_kind TEXT NOT NULL,
  bucket_name TEXT NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  public_url TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  bytes BIGINT DEFAULT 0 NOT NULL,
  status TEXT DEFAULT 'ready' NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  archived_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_media_assets_owner_id ON media_assets(owner_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_entity ON media_assets(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_media_assets_status ON media_assets(status);

ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own media assets" ON media_assets;
DROP POLICY IF EXISTS "Users can insert their own media assets" ON media_assets;
DROP POLICY IF EXISTS "Users can update their own media assets" ON media_assets;
DROP POLICY IF EXISTS "Users can delete their own media assets" ON media_assets;

CREATE POLICY "Users can view their own media assets"
  ON media_assets FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "Users can insert their own media assets"
  ON media_assets FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own media assets"
  ON media_assets FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can delete their own media assets"
  ON media_assets FOR DELETE
  TO authenticated
  USING (owner_id = auth.uid());

ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS video_object_key TEXT,
  ADD COLUMN IF NOT EXISTS cover_object_key TEXT,
  ADD COLUMN IF NOT EXISTS processing_status TEXT DEFAULT 'ready' NOT NULL,
  ADD COLUMN IF NOT EXISTS ingest_source TEXT DEFAULT 'desktop_client' NOT NULL;

UPDATE videos
SET processing_status = 'ready'
WHERE processing_status IS NULL;

ALTER TABLE videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public videos are insertable by everyone" ON videos;
DROP POLICY IF EXISTS "Authenticated users can insert their own videos" ON videos;
DROP POLICY IF EXISTS "Users can update their own videos" ON videos;
DROP POLICY IF EXISTS "Users can delete their own videos" ON videos;

CREATE POLICY "Authenticated users can insert their own videos"
  ON videos FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can update their own videos"
  ON videos FOR UPDATE
  TO authenticated
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Users can delete their own videos"
  ON videos FOR DELETE
  TO authenticated
  USING (author_id = auth.uid());

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public messages are viewable by everyone." ON messages;
DROP POLICY IF EXISTS "Public messages are insertable by everyone." ON messages;
DROP POLICY IF EXISTS "Authenticated users can read messages" ON messages;
DROP POLICY IF EXISTS "Authenticated users can insert their own messages" ON messages;

CREATE POLICY "Authenticated users can read messages"
  ON messages FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Authenticated users can insert their own messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid()::text);
