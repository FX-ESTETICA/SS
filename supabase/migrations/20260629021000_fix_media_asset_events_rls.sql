-- 允许媒体资产审计触发器在用户会话内写入事件日志，避免发布链被 event 表 RLS 拦截

ALTER TABLE public.media_asset_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own media asset events" ON public.media_asset_events;

CREATE POLICY "Users can insert their own media asset events"
  ON public.media_asset_events FOR INSERT
  TO authenticated
  WITH CHECK (owner_id = auth.uid());
