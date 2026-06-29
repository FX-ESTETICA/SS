-- 阶段 2：上传会话与幂等底座
-- 目标：为上传签发、幂等控制、续传策略与失败追踪提供平台级入口

CREATE TABLE IF NOT EXISTS public.media_upload_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_identity_id UUID REFERENCES public.user_identities(id) ON DELETE SET NULL,
  media_kind TEXT NOT NULL,
  upload_purpose TEXT DEFAULT 'generic' NOT NULL,
  source_filename TEXT NOT NULL,
  content_type TEXT NOT NULL,
  file_size_bytes BIGINT,
  checksum_sha256 TEXT,
  idempotency_key TEXT NOT NULL,
  object_prefix TEXT NOT NULL,
  status TEXT DEFAULT 'issued' NOT NULL,
  expected_width INTEGER,
  expected_height INTEGER,
  bytes_uploaded BIGINT DEFAULT 0 NOT NULL,
  retry_count INTEGER DEFAULT 0 NOT NULL,
  last_error_code TEXT,
  last_error_message TEXT,
  resume_strategy TEXT DEFAULT 'single_request' NOT NULL,
  upload_metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
  output_payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) + INTERVAL '1 day' NOT NULL,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

DO $$
BEGIN
  ALTER TABLE public.media_upload_sessions
    ADD CONSTRAINT chk_media_upload_sessions_media_kind
    CHECK (
      media_kind IN (
        'video',
        'cover',
        'stream',
        'avatar'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_upload_sessions
    ADD CONSTRAINT chk_media_upload_sessions_status
    CHECK (
      status IN (
        'issued',
        'uploading',
        'uploaded',
        'failed',
        'abandoned',
        'consumed'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE public.media_upload_sessions
    ADD CONSTRAINT chk_media_upload_sessions_resume_strategy
    CHECK (
      resume_strategy IN (
        'single_request',
        'resumable_planned',
        'multipart_planned'
      )
    );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS idx_media_upload_sessions_owner_idempotency
  ON public.media_upload_sessions(owner_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_owner_created_at
  ON public.media_upload_sessions(owner_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_status_created_at
  ON public.media_upload_sessions(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_checksum
  ON public.media_upload_sessions(checksum_sha256)
  WHERE checksum_sha256 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_object_prefix
  ON public.media_upload_sessions(object_prefix, created_at DESC);

ALTER TABLE public.media_upload_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own media upload sessions" ON public.media_upload_sessions;
DROP POLICY IF EXISTS "Users can insert their own media upload sessions" ON public.media_upload_sessions;
DROP POLICY IF EXISTS "Users can update their own media upload sessions" ON public.media_upload_sessions;

CREATE POLICY "Users can view their own media upload sessions"
  ON public.media_upload_sessions FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "Users can insert their own media upload sessions"
  ON public.media_upload_sessions FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Users can update their own media upload sessions"
  ON public.media_upload_sessions FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

CREATE OR REPLACE FUNCTION public.set_media_upload_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_media_upload_sessions_set_updated_at ON public.media_upload_sessions;
CREATE TRIGGER trg_media_upload_sessions_set_updated_at
  BEFORE UPDATE ON public.media_upload_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_media_upload_sessions_updated_at();
