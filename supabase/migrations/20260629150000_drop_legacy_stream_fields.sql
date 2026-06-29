UPDATE public.videos
SET primary_distribution_kind = 'direct_file'
WHERE primary_distribution_kind = 'hls'
  AND COALESCE(video_url, '') <> '';

DROP INDEX IF EXISTS idx_videos_stream_format;

ALTER TABLE public.videos
  DROP COLUMN IF EXISTS stream_url,
  DROP COLUMN IF EXISTS stream_object_prefix,
  DROP COLUMN IF EXISTS stream_format;
