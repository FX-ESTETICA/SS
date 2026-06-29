DELETE FROM public.media_asset_events
WHERE entity_type = 'video'
   OR asset_id IN (
     SELECT id
     FROM public.media_assets
     WHERE entity_type = 'video'
        OR media_kind IN ('video', 'cover', 'stream')
   );

DELETE FROM public.video_pipeline_jobs;

DELETE FROM public.media_assets
WHERE entity_type = 'video'
   OR media_kind IN ('video', 'cover', 'stream');

DELETE FROM public.videos;

DELETE FROM public.media_upload_sessions
WHERE media_kind IN ('video', 'cover', 'stream');
