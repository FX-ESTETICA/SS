ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS stream_url TEXT,
  ADD COLUMN IF NOT EXISTS stream_object_prefix TEXT,
  ADD COLUMN IF NOT EXISTS stream_format TEXT;

UPDATE videos
SET stream_format = 'mp4'
WHERE stream_format IS NULL
  AND COALESCE(video_url, '') <> '';

CREATE INDEX IF NOT EXISTS idx_videos_stream_format
  ON videos (stream_format);
