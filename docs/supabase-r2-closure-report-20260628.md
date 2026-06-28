# Supabase + R2 闭环接管报告 - 2026-06-28

## 1. 权限核查结果

### Cloudflare / R2

已确认具备以下真实控制能力：

- `wrangler whoami` 成功，当前账号为 `499755740@qq.com`
- Token 已具备 `workers (write)` 等核心写权限
- 可列出 R2 桶：`gx-2030-media`、`gx-media`、`zhixuan-media`
- 已完成 `gx-2030-media` 远端对象写入与删除验证

结论：

- 当前已具备 **Cloudflare Worker 部署权限**
- 当前已具备 **R2 桶级写入 / 删除 / 运维控制能力**

### Supabase

已确认具备以下真实控制能力：

- `npx supabase projects list` 成功，已登录并能访问项目 `SS2030`
- 当前仓库已链接项目 `izpolbeqdttjffbemvjr`
- `npx supabase db query ... --linked` 可直连远端数据库执行 SQL
- 新迁移已成功远端执行

结论：

- 当前已具备 **Supabase 项目级数据库管理权限**
- 当前已具备 **表结构变更、策略变更、查询验证能力**

### 当前权限缺口

发现 1 个明确缺口：

- 当前 CLI 登录角色无法修改 `storage.objects` 的 owner 级策略
- 远端执行包含 `storage.objects` policy 变更的 SQL 时返回：
  - `must be owner of table objects`

结论：

- **核心闭环载体是 Supabase Database + Cloudflare R2**
- 当前缺口只影响“历史遗留的 Supabase Storage 桶策略收口”
- **不阻塞当前 R2 主链路闭环**

## 2. 已落地改造

### Worker 上传控制面

已部署新版 Worker：

- 地址：`https://gx-2030-media-upload.499755740.workers.dev`
- 版本：`ae7fe254-b6f9-4a0e-8e89-f60c6830a35b`

已实现能力：

- 拒绝匿名裸传，必须带 `Bearer` 登录态
- Worker 通过 Supabase Auth 接口反查当前用户
- 按媒体类型执行大小限制与 MIME 白名单校验
- 按 `users/{userId}/{kind}/...` 规则生成对象键
- 自动计算对象 `SHA-256` 指纹
- 返回标准化媒体元数据：
  - `ownerId`
  - `objectKey`
  - `publicUrl`
  - `contentType`
  - `bytes`
  - `checksumSha256`
  - `sourceFilename`
  - `mediaKind`

涉及文件：

- [index.js](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/core/core_network/r2_worker/src/index.js)
- [wrangler.jsonc](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/core/core_network/r2_worker/wrangler.jsonc)

### 数据库元数据闭环

已新增 `media_assets` 表，用于接管 R2 对象的结构化管理。

已落地字段：

- 所有者：`owner_id`
- 业务归属：`entity_type`、`entity_id`
- 介质类型：`media_kind`
- 存储信息：`bucket_name`、`object_key`、`public_url`
- 媒体属性：`mime_type`、`bytes`
- 校验属性：`checksum_sha256`、`source_filename`
- 生命周期：`status`、`retention_class`、`created_at`、`updated_at`、`archived_at`、`deleted_at`、`purge_after`、`last_verified_at`

已为 `videos` 补齐闭环字段：

- `video_object_key`
- `cover_object_key`
- `processing_status`
- `ingest_source`
- `lifecycle_status`
- `archived_at`
- `deleted_at`

已新增 `media_asset_events` 审计表：

- 记录每次 `created / updated / deleted` 事件
- 保留对象键、状态、保留级别、清理时间等事件快照
- 支撑后续归档治理与问题追踪

涉及文件：

- [20260628153000_build_media_closure.sql](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/supabase/migrations/20260628153000_build_media_closure.sql)

### 权限收口

已收紧以下公共表策略：

- `videos`
  - 公开可读保留
  - 写入改为仅 `authenticated`
  - 更新 / 删除仅允许本人

- `messages`
  - 读取改为仅 `authenticated`
  - 插入改为 `sender_id = auth.uid()::text`

- `media_assets`
  - 仅允许本人读写删改
- `media_asset_events`
  - 仅允许本人读取审计记录

### App 业务链路

已完成以下链路改造：

- 视频编辑器发布前强制检查登录态
- 视频与封面改为双上传
- 发布时写入：
  - `author_id`
  - `author_name`
  - `video_url`
  - `video_object_key`
  - `cover_url`
  - `cover_object_key`
  - `duration_seconds`
  - `processing_status`
  - `ingest_source`
- 发布成功后同步写入 `media_assets`
- “我的视频”查询改为按 `author_id`
- 视频发布入口未登录时直接拦截
- 聊天模块改为依赖真实登录用户，不再使用硬编码 `user_123`

涉及文件：

- [supabase_service.dart](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/core/core_network/lib/src/supabase_service.dart)
- [video_editor_screen.dart](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/features/feature_video/lib/src/presentation/video_editor_screen.dart)
- [video_feed_screen.dart](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/features/feature_video/lib/src/presentation/video_feed_screen.dart)
- [profile_screen.dart](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/features/feature_profile/lib/src/presentation/profile_screen.dart)
- [chat_screen.dart](file:///c:/Users/49975/Desktop/%E6%99%BA%E9%80%89/packages/features/feature_im/lib/src/presentation/chat_screen.dart)

## 3. 当前闭环架构

当前主链路已经形成以下闭环：

1. 采集
   - 客户端从相机 / 相册获取视频
2. 处理
   - 本地转码为 MP4 + faststart
   - 抽取封面为 WebP
3. 上传
   - 客户端携带 Supabase 登录态访问 Worker
   - Worker 校验身份后写入 R2
4. 入库
   - `videos` 记录业务主数据
   - `media_assets` 记录对象元数据与生命周期
5. 读取
   - Feed 从 `videos` 读取公共播放信息
   - 个人中心按 `author_id` 精确读取
6. 管理
   - 所有者通过 `media_assets` 追踪对象归属与状态
7. 播放
   - 客户端走本地磁盘缓存 + 播放器池

## 4. 验证结果

### 已通过

- `Wrangler` 可用
- `Supabase CLI` 可用
- Cloudflare 账号已登录
- Supabase 项目已登录并已绑定
- Worker `dry-run` 通过
- Worker 已成功部署
- `media_assets` 表已存在
- `videos` 新字段已存在
- `videos / messages / media_assets` 新策略已存在
- `media_assets` 索引已存在
- Worker 已正确拒绝匿名上传，请求返回 `Missing bearer token`
- R2 远端对象写入验证通过
- R2 远端对象删除验证通过
- 已使用本机落盘的用户会话刷新 token，并完成一次真实 `Bearer` 鉴权上传
- 该次上传返回了有效 `ownerId / objectKey / publicUrl`
- 该次认证上传生成的 R2 对象已成功远端删除，验证闭环清理路径也可用
- 认证上传返回了有效 `checksumSha256 / sourceFilename`
- Worker 已正确拒绝错误 `Content-Type`，认证但非法 MIME 返回 `415`
- `media_assets` 新增治理字段已存在
- `videos` 新增归档字段已存在
- `media_asset_events` 审计表已存在
- 审计触发器已验证通过，能记录 `created / updated / deleted` 三类事件

### 未完全闭合

- `storage.objects` 历史策略未能通过当前 CLI 角色收紧

原因：

- 当前角色不是 `storage.objects` 所有者
- 这是 Supabase Storage 的遗留面，不是当前主链路的数据载体

## 5. 结论

### 已完成

- 已确认对 **Supabase Database** 与 **Cloudflare R2 / Worker** 的核心管理权限
- 已完成 **Supabase + R2 的主链路闭环改造**
- 已完成 **结构化数据 + 非结构化对象** 的统一联动设计与落地
- 已完成主链路级别的 **权限收口与对象身份绑定**
- 已完成 **远端部署与验证**

### 仍保留的单点缺口

- 仅剩 **历史 Supabase Storage 桶策略** 这一处 owner 级权限缺口
- 它不影响当前 R2 主链路闭环，但影响“彻底清退旧 media 桶”的最后一步治理

## 6. 下一步建议

### P0

- 跑一轮真实已登录用户上传，验证视频与封面都能入 `videos + media_assets`
- 为 `media_assets` 增加归档任务和对象清理审计
- 为 `media_assets` 增加定时巡检任务，回写 `last_verified_at`

### P1

- 为 Worker 增加幂等上传保护
- 为 `videos` 与 `media_assets` 增加批量归档 / 恢复入口

### P1

- 使用具备 owner 权限的 SQL Editor 会话，补完旧 `storage.objects` 策略收口
