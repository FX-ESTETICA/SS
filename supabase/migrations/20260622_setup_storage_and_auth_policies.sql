-- 20260622_setup_storage_and_auth_policies.sql
-- 彻底打通“发布链路”与“用户体系”的最终云端配置

---------------------------------------------------------
-- 1. 创建 Storage Bucket (存储桶)
---------------------------------------------------------
-- 尝试创建名为 'media' 的公共存储桶 (如果不存在的话)
INSERT INTO storage.buckets (id, name, public)
VALUES ('media', 'media', true)
ON CONFLICT (id) DO NOTHING;

---------------------------------------------------------
-- 2. 配置 Storage (R2/S3 兼容层) 的安全规则 (RLS)
---------------------------------------------------------
-- 允许任何人 (包含未登录游客) 上传文件到 media 桶
-- 生产环境建议将 USING (true) 替换为 auth.role() = 'authenticated'
CREATE POLICY "Allow public uploads to media"
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'media' );

-- 允许任何人读取 media 桶的文件
CREATE POLICY "Allow public read to media"
ON storage.objects FOR SELECT 
USING ( bucket_id = 'media' );

-- 允许用户更新自己上传的文件 (可选)
CREATE POLICY "Allow public update to media"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'media' );

-- 允许用户删除自己上传的文件 (可选)
CREATE POLICY "Allow public delete from media"
ON storage.objects FOR DELETE
USING ( bucket_id = 'media' );

---------------------------------------------------------
-- 3. 补全核心数据表的 RLS (行级安全策略) 权限
---------------------------------------------------------
-- 之前 videos 表只开放了 SELECT (读)，现在我们要允许客户端 INSERT (写) 动态
CREATE POLICY "Public videos are insertable by everyone" 
ON videos FOR INSERT 
WITH CHECK (true);

-- (可选) 确保存储策略生效，有时需要主动给 storage.objects 开启 RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
