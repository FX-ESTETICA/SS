ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS content_orientation TEXT,
  ADD COLUMN IF NOT EXISTS aspect_ratio_label TEXT;

ALTER TABLE videos
  ALTER COLUMN content_orientation SET DEFAULT 'portrait',
  ALTER COLUMN aspect_ratio_label SET DEFAULT '9:16';

UPDATE videos
SET
  content_orientation = CASE
    WHEN COALESCE(width, 0) > COALESCE(height, 0) THEN 'landscape'
    ELSE 'portrait'
  END,
  aspect_ratio_label = CASE
    WHEN COALESCE(width, 0) > COALESCE(height, 0) THEN '16:9'
    ELSE '9:16'
  END
WHERE content_orientation IS NULL
   OR aspect_ratio_label IS NULL;

CREATE INDEX IF NOT EXISTS idx_videos_content_orientation_created_at
  ON videos (content_orientation, created_at DESC);
