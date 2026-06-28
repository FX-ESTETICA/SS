-- 增强媒体治理能力：归档状态机、对象指纹、审计事件与自动更新时间

ALTER TABLE media_assets
  ADD COLUMN IF NOT EXISTS checksum_sha256 TEXT,
  ADD COLUMN IF NOT EXISTS source_filename TEXT,
  ADD COLUMN IF NOT EXISTS retention_class TEXT DEFAULT 'standard' NOT NULL,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS purge_after TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE videos
  ADD COLUMN IF NOT EXISTS lifecycle_status TEXT DEFAULT 'active' NOT NULL,
  ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

UPDATE videos
SET lifecycle_status = 'active'
WHERE lifecycle_status IS NULL;

DO $$
BEGIN
  ALTER TABLE media_assets
    ADD CONSTRAINT chk_media_assets_status
    CHECK (status IN ('pending', 'ready', 'archived', 'deleted', 'quarantined'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE media_assets
    ADD CONSTRAINT chk_media_assets_retention_class
    CHECK (retention_class IN ('standard', 'critical', 'archive'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE videos
    ADD CONSTRAINT chk_videos_lifecycle_status
    CHECK (lifecycle_status IN ('active', 'archived', 'deleted'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS media_asset_events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset_id UUID NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  event_payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_media_asset_events_asset_id
  ON media_asset_events(asset_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_asset_events_owner_id
  ON media_asset_events(owner_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_asset_events_entity
  ON media_asset_events(entity_type, entity_id, created_at DESC);

ALTER TABLE media_asset_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own media asset events" ON media_asset_events;

CREATE POLICY "Users can view their own media asset events"
  ON media_asset_events FOR SELECT
  TO authenticated
  USING (owner_id = auth.uid());

CREATE OR REPLACE FUNCTION set_media_assets_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION log_media_asset_event()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  target_row media_assets;
  action_type TEXT;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_row = OLD;
    action_type = 'deleted';
  ELSIF TG_OP = 'INSERT' THEN
    target_row = NEW;
    action_type = 'created';
  ELSE
    target_row = NEW;
    action_type = 'updated';
  END IF;

  INSERT INTO media_asset_events (
    asset_id,
    owner_id,
    entity_type,
    entity_id,
    event_type,
    event_payload
  ) VALUES (
    target_row.id,
    target_row.owner_id,
    target_row.entity_type,
    target_row.entity_id,
    action_type,
    jsonb_build_object(
      'status', target_row.status,
      'retention_class', target_row.retention_class,
      'object_key', target_row.object_key,
      'public_url', target_row.public_url,
      'purge_after', target_row.purge_after,
      'archived_at', target_row.archived_at,
      'deleted_at', target_row.deleted_at,
      'updated_at', target_row.updated_at
    )
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_media_assets_set_updated_at ON media_assets;
CREATE TRIGGER trg_media_assets_set_updated_at
  BEFORE UPDATE ON media_assets
  FOR EACH ROW
  EXECUTE FUNCTION set_media_assets_updated_at();

DROP TRIGGER IF EXISTS trg_media_assets_audit_insert ON media_assets;
CREATE TRIGGER trg_media_assets_audit_insert
  AFTER INSERT ON media_assets
  FOR EACH ROW
  EXECUTE FUNCTION log_media_asset_event();

DROP TRIGGER IF EXISTS trg_media_assets_audit_update ON media_assets;
CREATE TRIGGER trg_media_assets_audit_update
  AFTER UPDATE ON media_assets
  FOR EACH ROW
  EXECUTE FUNCTION log_media_asset_event();

DROP TRIGGER IF EXISTS trg_media_assets_audit_delete ON media_assets;
CREATE TRIGGER trg_media_assets_audit_delete
  AFTER DELETE ON media_assets
  FOR EACH ROW
  EXECUTE FUNCTION log_media_asset_event();
