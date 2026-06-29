-- 阶段 1：视频平台协议与资源模型重建
-- 目标：补齐平台级状态机、资源角色与工作流任务表，为后续服务端统一转码与唯一主分发资产做准备

ALTER TABLE public.videos
  ADD COLUMN IF NOT EXISTS workflow_status TEXT,
  ADD COLUMN IF NOT EXISTS moderation_status TEXT,
  ADD COLUMN IF NOT EXISTS distribution_status TEXT,
  ADD COLUMN IF NOT EXISTS distribution_channel TEXT,
  ADD COLUMN IF NOT EXISTS primary_distribution_kind TEXT,
  ADD COLUMN IF NOT EXISTS asset_schema_version INTEGER,
  ADD COLUMN IF NOT EXISTS published_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.videos
  ALTER COLUMN workflow_status SET DEFAULT 'ready',
  ALTER COLUMN moderation_status SET DEFAULT 'approved',
  ALTER COLUMN distribution_status SET DEFAULT 'ready',
  ALTER COLUMN distribution_channel SET DEFAULT 'recommendation',
  ALTER COLUMN primary_distribution_kind SET DEFAULT 'direct_file',
  ALTER COLUMN asset_schema_version SET DEFAULT 1;

UPDATE public.videos
SET
  workflow_status = COALESCE(
    workflow_status,
    CASE
      WHEN processing_status = 'ready' THEN 'ready'
      ELSE 'uploaded'
    END
  ),
  moderation_status = COALESCE(moderation_status, 'approved'),
  distribution_status = COALESCE(
    distribution_status,
    CASE
      WHEN lifecycle_status = 'active' THEN 'ready'
      WHEN lifecycle_status = 'archived' THEN 'offline'
      ELSE 'deleted'
    END
  ),
  distribution_channel = COALESCE(
    distribution_channel,
    CASE
      WHEN content_orientation = 'landscape' THEN 'landscape'
      ELSE 'recommendation'
    END
  ),
  primary_distribution_kind = COALESCE(
    primary_distribution_kind,
    CASE
      WHEN COALESCE(stream_format, '') = 'hls' THEN 'hls'
      WHEN COALESCE(video_url, '') <> '' THEN 'direct_file'
      ELSE 'none'
    END
  ),
  asset_schema_version = COALESCE(asset_schema_version, 1),
  published_at = COALESCE(published_at, created_at)
WHERE workflow_status IS NULL
   OR moderation_status IS NULL
   OR distribution_status IS NULL
   OR distribution_channel IS NULL
   OR primary_distribution_kind IS NULL
   OR asset_schema_version IS NULL
   OR published_at IS NULL;

DO $$
BEGIN
  ALTER TABLE public.videos
    ADD CONSTRAINT chk_videos_workflow_status
    CHECK (
      workflow_status IN (
        'uploaded',
        'queued',
        'processing',
        'packaging',
        'review_pending',
        'ready',
        'failed'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.videos
    ADD CONSTRAINT chk_videos_moderation_status
    CHECK (
      moderation_status IN (
        'pending',
        'approved',
        'rejected',
        'restricted'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.videos
    ADD CONSTRAINT chk_videos_distribution_status
    CHECK (
      distribution_status IN (
        'pending',
        'ready',
        'offline',
        'deleted'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.videos
    ADD CONSTRAINT chk_videos_distribution_channel
    CHECK (
      distribution_channel IN (
        'recommendation',
        'landscape',
        'private',
        'draft'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.videos
    ADD CONSTRAINT chk_videos_primary_distribution_kind
    CHECK (
      primary_distribution_kind IN (
        'none',
        'direct_file',
        'hls',
        'dash',
        'cmaf'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_videos_distribution_channel_created_at
  ON public.videos(distribution_channel, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_videos_workflow_distribution
  ON public.videos(workflow_status, distribution_status, created_at DESC);

ALTER TABLE public.media_assets
  ADD COLUMN IF NOT EXISTS asset_role TEXT,
  ADD COLUMN IF NOT EXISTS asset_scope TEXT,
  ADD COLUMN IF NOT EXISTS asset_family TEXT,
  ADD COLUMN IF NOT EXISTS storage_tier TEXT,
  ADD COLUMN IF NOT EXISTS availability_status TEXT,
  ADD COLUMN IF NOT EXISTS processing_profile TEXT,
  ADD COLUMN IF NOT EXISTS asset_metadata JSONB;

ALTER TABLE public.media_assets
  ALTER COLUMN asset_role SET DEFAULT 'auxiliary',
  ALTER COLUMN asset_scope SET DEFAULT 'distribution',
  ALTER COLUMN asset_family SET DEFAULT 'primary',
  ALTER COLUMN storage_tier SET DEFAULT 'hot',
  ALTER COLUMN availability_status SET DEFAULT 'online',
  ALTER COLUMN asset_metadata SET DEFAULT '{}'::jsonb;

UPDATE public.media_assets
SET
  asset_role = COALESCE(
    asset_role,
    CASE media_kind
      WHEN 'video' THEN 'playback_file'
      WHEN 'cover' THEN 'cover'
      WHEN 'stream_manifest' THEN 'stream_manifest'
      ELSE 'auxiliary'
    END
  ),
  asset_scope = COALESCE(
    asset_scope,
    CASE media_kind
      WHEN 'cover' THEN 'presentation'
      ELSE 'distribution'
    END
  ),
  asset_family = COALESCE(
    asset_family,
    CASE media_kind
      WHEN 'cover' THEN 'cover'
      ELSE 'playback'
    END
  ),
  storage_tier = COALESCE(storage_tier, 'hot'),
  availability_status = COALESCE(
    availability_status,
    CASE
      WHEN status = 'archived' THEN 'archived'
      WHEN status = 'deleted' THEN 'deleted'
      WHEN status = 'quarantined' THEN 'quarantined'
      ELSE 'online'
    END
  ),
  processing_profile = COALESCE(
    processing_profile,
    CASE media_kind
      WHEN 'video' THEN 'mp4_fallback'
      WHEN 'cover' THEN 'webp_cover'
      WHEN 'stream_manifest' THEN 'single_quality_hls_manifest'
      ELSE 'standard'
    END
  ),
  asset_metadata = COALESCE(asset_metadata, '{}'::jsonb)
WHERE asset_role IS NULL
   OR asset_scope IS NULL
   OR asset_family IS NULL
   OR storage_tier IS NULL
   OR availability_status IS NULL
   OR processing_profile IS NULL
   OR asset_metadata IS NULL;

DO $$
BEGIN
  ALTER TABLE public.media_assets
    ADD CONSTRAINT chk_media_assets_asset_role
    CHECK (
      asset_role IN (
        'source_upload',
        'mezzanine',
        'playback_file',
        'fallback_playback',
        'stream_manifest',
        'stream_segment',
        'cover',
        'thumbnail',
        'auxiliary'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_assets
    ADD CONSTRAINT chk_media_assets_asset_scope
    CHECK (
      asset_scope IN (
        'ingest',
        'production',
        'distribution',
        'presentation',
        'audit'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_assets
    ADD CONSTRAINT chk_media_assets_asset_family
    CHECK (
      asset_family IN (
        'source',
        'mezzanine',
        'playback',
        'cover',
        'audit',
        'primary'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_assets
    ADD CONSTRAINT chk_media_assets_storage_tier
    CHECK (
      storage_tier IN (
        'hot',
        'warm',
        'cold',
        'archive'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_assets
    ADD CONSTRAINT chk_media_assets_availability_status
    CHECK (
      availability_status IN (
        'online',
        'offline',
        'archived',
        'deleted',
        'quarantined'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_media_assets_entity_role
  ON public.media_assets(entity_type, entity_id, asset_role);

CREATE INDEX IF NOT EXISTS idx_media_assets_family_tier
  ON public.media_assets(asset_family, storage_tier, created_at DESC);

CREATE TABLE IF NOT EXISTS public.video_pipeline_jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  video_id UUID NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL,
  job_type TEXT NOT NULL,
  status TEXT DEFAULT 'queued' NOT NULL,
  source_origin TEXT DEFAULT 'client_direct' NOT NULL,
  attempt_count INTEGER DEFAULT 0 NOT NULL,
  started_at TIMESTAMP WITH TIME ZONE,
  finished_at TIMESTAMP WITH TIME ZONE,
  error_code TEXT,
  error_message TEXT,
  input_payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  output_payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_video_pipeline_jobs_video
  ON public.video_pipeline_jobs(video_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_video_pipeline_jobs_owner
  ON public.video_pipeline_jobs(owner_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_video_pipeline_jobs_status
  ON public.video_pipeline_jobs(status, created_at DESC);

DO $$
BEGIN
  ALTER TABLE public.video_pipeline_jobs
    ADD CONSTRAINT chk_video_pipeline_jobs_type
    CHECK (
      job_type IN (
        'ingest',
        'transcode',
        'packaging',
        'publish',
        'backfill',
        'archive',
        'delete'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.video_pipeline_jobs
    ADD CONSTRAINT chk_video_pipeline_jobs_status
    CHECK (
      status IN (
        'queued',
        'running',
        'completed',
        'failed',
        'cancelled'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.video_pipeline_jobs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own video pipeline jobs" ON public.video_pipeline_jobs;
DROP POLICY IF EXISTS "Users can insert their own video pipeline jobs" ON public.video_pipeline_jobs;
DROP POLICY IF EXISTS "Users can update their own video pipeline jobs" ON public.video_pipeline_jobs;

CREATE POLICY "Users can view their own video pipeline jobs"
  ON public.video_pipeline_jobs FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "Users can insert their own video pipeline jobs"
  ON public.video_pipeline_jobs FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own video pipeline jobs"
  ON public.video_pipeline_jobs FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE OR REPLACE FUNCTION public.set_video_pipeline_jobs_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_video_pipeline_jobs_set_updated_at ON public.video_pipeline_jobs;
CREATE TRIGGER trg_video_pipeline_jobs_set_updated_at
  BEFORE UPDATE ON public.video_pipeline_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.set_video_pipeline_jobs_updated_at();
