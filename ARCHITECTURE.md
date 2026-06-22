# 智选超级 APP (Zhixuan Super App) - AI 核心记忆库 & 项目圣经
**最后更新:** 2026-06-22

> ⚠️ **AI 强制指令 (AI Handover Instructions):** 
> 1. 当新会话开启并要求你读取此文件时，**你必须无条件遵循以下所有架构设计、技术栈约束和避坑指南**。
> 2. 你还需要同时读取 `supabase/migrations/` 目录下的 SQL 文件，以获取当前最新的云端数据库真实结构，才能做到 100% 完美衔接开发。
> 3. **绝对执行原则：完成 UI 或功能更新后，绝不要询问用户“是否需要编译预览”，也绝对禁止说“几秒钟搞定/稍等片刻”等废话。你必须静默地、直接在终端执行 `flutter run -d windows` （或者使用热重载），直接把浏览打开给用户看最终效果！**
> 4. **多语言基础语言规范：所有 UI 界面文字必须使用中文（作为未来 i18n 的基础），绝对不要在 UI 中硬编码英文。**

---

## 1. 产品定位与核心商业逻辑
- **目标:** 打造一款降维打击的国民级超级 APP，一码多端（完美适配 Android, iOS, Windows, Web）。
- **功能融合:** 淘宝（电商瀑布流）、抖音（全屏短视频）、微信/WhatsApp（实时通讯 IM）、58同城（本地生活）。
- **商业要求:** 前期绝对 0 成本运营，利用云服务白嫖海量流量和存储。极致流畅的 UI 体验。
- **代码仓库:** `https://github.com/FX-ESTETICA/SS.git`

## 2. 顶层技术栈 (Tech Stack)
- **前端与多端引擎:** Flutter (Dart)。Windows 桌面端作为开发期的主要预览环境（避开 Web 性能瓶颈）。
- **工程结构:** Monorepo (基于 Melos 管理多包)。
- **后端与数据库:** Supabase (PostgreSQL + Auth + Realtime WebSocket)。
- **海量媒体存储:** Cloudflare R2 对象存储 (0 Egress 流出流量费，全球 CDN 加速)。

## 3. 核心工程架构 (Clean Architecture)
所有代码**严禁**互相耦合，必须遵循以下物理隔离的目录结构：
- `apps/zhixuan_main/`: 主壳工程，仅负责路由分发和基础引擎挂载。
- `packages/core/`: 核心基建。
  - `core_network/`: 全局网络与云端中枢 (Dio + fpdart + Supabase)。
  - `core_design_system/`: 像素级统一设计系统 (Colors, Typography, Themes)。
- `packages/features/`: 独立的业务模块。
  - `feature_video/`: 抖音短视频模块。
  - `feature_im/`: 微信聊天模块。
  - `feature_shop/`: 淘宝商城模块。

## 4. 数据库与存储 (Database & Migrations)
- **Supabase Project URL:** https://izpolbeqdttjffbemvjr.supabase.co
- **Anon Key:** sb_publishable_MFLwIbZIgBmUAnP9rqcSVQ_zzTwpq3y
- **Database as Code:** 数据库结构不保存在代码里，而是保存在 `supabase/migrations/` 目录下。
  - *AI 必读:* 新会话必须 `ls supabase/migrations` 并阅读 SQL，了解 `videos`, `messages`, `products` 等表的最新字段。
- **存储方案:** 媒体链接必须使用 `https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev` 作为前缀。

## 5. 避坑指南与自动化工作流 (Crucial Lessons Learned - 绝不能再犯的错误)

开发过程中遇到过多次致命崩溃，已形成以下**绝对规范**：

### 🚨 坑点 1: Web 端性能瓶颈导致白屏闪退
- **问题:** Windows Web 引擎 (CanvasKit/HTML) 无法承载视频解码器和复杂缓存图片的高性能渲染。
- **解决方案:** 开发和预览**必须**使用原生的 Windows 桌面级应用程序进行编译 (`flutter run -d windows`)。

### 🚨 坑点 2: Windows 编译缓存导致 UI 死活不更新 / LNK1168
- **问题:** 修改代码后，即使 `taskkill` 杀掉进程重新 `flutter run`，界面依然是旧的。这是因为 Windows 下 CMake/Ninja 增量编译缓存损坏，导致一直复用旧的 `.exe`。
- **终极解决方案 (AI 全权接管):** 绝对不能只杀进程！必须执行“核弹级”清理：
  1. `taskkill /F /IM zhixuan_main.exe`
  2. `cd apps/zhixuan_main && flutter clean` (必须清空 build 缓存！)
  3. `flutter pub get`
  4. 重新 `flutter run -d windows`

### 🚨 坑点 3: 桌面端布局约束异常 (RenderBox was not laid out)
- **问题:** 在 IM 聊天框等场景中，`TextField` 设置了 `maxLines: null` 且被包裹在 `Expanded` 中，Web/桌面端由于屏幕无边界，导致原生 C++ 渲染引擎内存溢出自毁。
- **解决方案:** 在无限高度的组件外层，必须包裹明确的物理边界，例如 `BoxConstraints(maxHeight: 120)`。

### 🚨 坑点 4: 官方 video_player 在 Windows 下直接白屏崩溃
- **问题:** Flutter 官方 `video_player` 插件在 Windows 桌面端不自带解码器实现，导致 `UnimplementedError: init() has not been implemented` 并白屏。
- **解决方案:** 必须使用 `video_player_win` 插件，并在初始化时针对 Windows 显式调用 `WindowsVideoPlayer.registerWith();`。

## 6. 当前进度与下一步计划
- **已完成:** 核心架构搭建、Supabase 接入、Cloudflare R2 接入、视频模块的云端数据渲染和 Windows 桌面端适配（已解决刷新和视频解码问题）。
- **待开发 1:** `feature_im` 模块接入 Supabase Realtime WebSocket 实现消息秒发秒回。
- **待开发 2:** `feature_shop` 模块实现骨架屏和淘宝高并发瀑布流。