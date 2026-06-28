-- 清理仍指向旧 Cloudflare 链路的历史媒体数据，保留新的身份/商户/店铺底座

WITH legacy_assets AS (
  SELECT id
  FROM media_assets
  WHERE bucket_name IN ('gx-media', 'gx-2030-media')
     OR public_url LIKE 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/%'
     OR public_url LIKE 'https://gx-2030-media-upload.499755740.workers.dev/objects/%'
)
DELETE FROM media_asset_events
WHERE asset_id IN (SELECT id FROM legacy_assets);

DELETE FROM media_assets
WHERE bucket_name IN ('gx-media', 'gx-2030-media')
   OR public_url LIKE 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/%'
   OR public_url LIKE 'https://gx-2030-media-upload.499755740.workers.dev/objects/%';

DELETE FROM media_asset_events
WHERE asset_id NOT IN (SELECT id FROM media_assets);

DELETE FROM videos
WHERE video_url LIKE 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/%'
   OR COALESCE(cover_url, '') LIKE 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/%'
   OR video_url LIKE 'https://gx-2030-media-upload.499755740.workers.dev/objects/%'
   OR COALESCE(cover_url, '') LIKE 'https://gx-2030-media-upload.499755740.workers.dev/objects/%';

DELETE FROM products
WHERE image_url LIKE 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/%'
   OR image_url LIKE 'https://gx-2030-media-upload.499755740.workers.dev/objects/%';
