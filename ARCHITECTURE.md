# 智选超级 APP (Zhixuan Super App) - AI 核心记忆库 & 项目圣经
**最后更新:** 2026-06-26

> ⚠️ **AI 强制指令 (Boot Sequence & Handover Instructions):** 
> 0. **终极启动协议 (Boot Sequence):** 当用户发送“读取记忆”时，你必须静默执行以下连招：
>    - 完整阅读本文件，铭记所有红线。
>    - 执行 `git log -n 3` 了解最近的开发脉络。
>    - 使用 `grep -r "@AI_CONTEXT" .` 和 `grep -r "@AI_CORE_MECHANISM" .` 全局扫描代码库中的隐式记忆锚点，将散落的代码锚点纳入上下文。
>    - 回复用户：“记忆 100% 同步完毕。当前红线已锁定，代码锚点已加载。请指示下一步操作。”
> 1. 当新会话开启并要求你读取此文件时，**你必须无条件遵循以下所有架构设计、技术栈约束和避坑指南**。
> 2. 你还需要同时读取 `supabase/migrations/` 目录下的 SQL 文件，以获取当前最新的云端数据库真实结构，才能做到 100% 完美衔接开发。
> 3. **绝对执行原则：完成 UI 或功能更新后，绝不要询问用户“是否需要编译预览”，也绝对禁止说“几秒钟搞定/稍等片刻”等废话。你必须静默地、直接在终端执行 `flutter run -d windows` （或者使用热重载），直接把浏览打开给用户看最终效果！**
> 4. **多语言与色彩规范：**
>    - **语言：** 所有 UI 界面文字必须使用中文，绝对不要在 UI 中硬编码英文。
>    - **【最新绝对红线】前景实色原则：** 所有的文本（Text）和图标（Icon）等交互前景元素必须是 100% 纯实色（纯白 #FFFFFF 或纯黑 #000000），**绝对禁止使用透明度（Alpha/Opacity）或灰色**来区分层级，以免显得“脏”。层级和状态仅通过“大小、粗细（FontWeight/Icon Weight）、实心/线框形态”来区分。
>    - **【背景特例】沉浸式空间氛围 (Spatial Aura) 与全局切换：** 允许且鼓励在纯黑底色上使用极其微弱、极具质感的**深暗色流光渐变**作为一种“宇宙暗物质/极光”般的背景点缀。为了满足用户个性化，**背景必须是全局可切换的**（通过 BackgroundManager 控制，目前支持 极简纯黑 / 七彩流光渐变 / 绯红星云 / 深海蓝焰 / 翡翠光雾），且弹窗、设置面板等覆盖层必须保持绝对透明（禁止使用深色蒙版），让底层背景完全透出。

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

## 3. 极致性能优化 (Performance Tuning)

为了达到对标国民级 APP（抖音、微信）的物理级性能，本项目在应用层进行了深度的降维优化：

### 3.1 视频播放池 (Ring Buffer)
抛弃了常规的 `StatefulWidget` 绑定生命周期做法。在 `VideoEnginePool` 中维护了 3 个常驻显存的 C++ 播放器实例（`media_kit`）。滑动时，仅在底层进行 URL 的内存指针切换，配合 `PlaylistMode.single` 硬件级循环，实现了 0 GC 抖动和极低 CPU 占用的短视频秒开体验。

### 3.2 布局防抖与 GPU 零开销跑马灯 (Continuous Marquee)
在商城轮播广告中，抛弃了常规的 `PageView` 或 `ListView`。实现了 `ContinuousMarqueeBanner`：
1. **白嫖全局时钟**：不创建任何独立的 `Timer` 或 `AnimationController`，直接绑定到底层的 `BackgroundManager.instance.globalTimeNotifier`。这意味着当用户闲置 3 秒触发休眠时，跑马灯会自动随之冻结，CPU 归 0。
2. **纯 GPU 位移**：使用 `Transform.translate` 进行像素级偏移，配合模运算 (`%`) 实现无限循环。这**绝对避免了在动画帧中修改布局尺寸**，不会触发任何 `performLayout`，让跑马灯在极致丝滑的同时保持极低功耗。

### 3.3 异步解码与内存池扩容
针对瀑布流的高清大图，在引擎启动时强制干预 `PaintingBinding`，将 `ImageCache` 的底层 C++ 纹理缓冲池扩容至 256MB。配合 `CustomScrollView` 高达 2500 像素的 `cacheExtent`，让图片解码完全在屏幕外的 Isolate 独立线程中异步完成，实现滑动时的绝对零掉帧。

### 3.4 交互休眠机制 (Idle Pause)
通过在根节点拦截 `PointerEvent` 并结合 `BackgroundManager`，实现了“交互唤醒，静止休眠”。当用户停止操作 3 秒后，所有底层的流光 Shader 动画和重绘请求将被强行冻结，实现闲置状态下 0% 的绝对冰点 CPU 占用。

## 4. 数据库与存储 (Database & Migrations)
- **Supabase Project URL:** https://izpolbeqdttjffbemvjr.supabase.co
- **Anon Key:** sb_publishable_MFLwIbZIgBmUAnP9rqcSVQ_zzTwpq3y
- **Database as Code:** 数据库结构不保存在代码里，而是保存在 `supabase/migrations/` 目录下。
  - *AI 必读:* 新会话必须 `ls supabase/migrations` 并阅读 SQL，了解 `videos`, `messages`, `products` 等表的最新字段。
- **存储方案:** 媒体上传统一走 `https://zhixuan-media-upload.499755740.workers.dev`，公开访问统一走 `https://zhixuan-media-upload.499755740.workers.dev/objects/` 前缀，R2 正式桶名为 `zhixuan-media`。

## 5. 避坑指南与自动化工作流 (Crucial Lessons Learned - 绝不能再犯的错误)

开发过程中遇到过多次致命崩溃，已形成以下**绝对规范**：

### 🚨 坑点 1: Web 端性能瓶颈导致白屏闪退
- **问题:** Windows Web 引擎 (CanvasKit/HTML) 无法承载视频解码器和复杂缓存图片的高性能渲染。
- **解决方案:** 开发和预览**必须**使用原生的 Windows 桌面级应用程序进行编译 (`flutter run -d windows`)。

### 🚨 坑点 2: Windows 编译缓存导致 UI 死活不更新 / LNK1168 / 构建卡死
- **问题:** 修改代码后，即使 `taskkill` 杀掉进程重新 `flutter run`，界面依然是旧的。或者因为修改代码引入了错误导致编译彻底卡死。这是因为 Windows 下 CMake/Ninja 增量编译缓存损坏，或者某些后台进程 (dart.exe) 锁死了文件。
- **终极解决方案 (AI 全权接管，必须遵循以下步骤):** 
  绝对不能只杀进程！为了确保 100% 能打开最新应用并且不再重复等待，必须执行以下“终极核弹级”清理（顺序绝不能错）：
  1. 彻底杀掉所有可能锁死文件的进程：`taskkill /F /IM zhixuan_main.exe; taskkill /F /IM dart.exe; taskkill /F /IM flutter.bat` （这一步非常关键，很多时候是后台残留的 dart 进程锁死了 build 文件夹导致 `flutter clean` 失败）
  2. `cd apps/zhixuan_main`
  3. 执行 `flutter clean` (必须清空 build 缓存！)
  4. 执行 `flutter pub get`
  5. 重新执行 `flutter run -d windows`

### 🚨 坑点 3: 桌面端布局约束异常 (RenderBox was not laid out)
- **问题:** 在 IM 聊天框等场景中，`TextField` 设置了 `maxLines: null` 且被包裹在 `Expanded` 中，Web/桌面端由于屏幕无边界，导致原生 C++ 渲染引擎内存溢出自毁。
- **解决方案:** 在无限高度的组件外层，必须包裹明确的物理边界，例如 `BoxConstraints(maxHeight: 120)`。

### 🚨 坑点 4: 官方 video_player 在 Windows 下直接白屏崩溃
- **问题:** Flutter 官方 `video_player` 插件在 Windows 桌面端不自带解码器实现，导致 `UnimplementedError: init() has not been implemented` 并白屏。
- **解决方案:** 必须使用 `video_player_win` 插件，并在初始化时针对 Windows 显式调用 `WindowsVideoPlayer.registerWith();`。

## 6. 当前进度与下一步计划
- **已完成:** 
  - 核心架构搭建、Supabase 接入、Cloudflare R2 接入。
  - 视频模块 (`feature_video`)：云端数据渲染和 Windows 桌面端适配（已解决刷新和视频解码问题）。
  - IM 模块 (`feature_im`)：已接入 Supabase Realtime WebSocket，实现消息秒发秒回与极简 UI 适配。
  - 商城模块 (`feature_shop`)：已实现 Shimmer 骨架屏加载与 `flutter_staggered_grid_view` 淘宝高并发瀑布流，并完成本地缓存熔断防护。
  - **用户模块 (`feature_profile`)**：已完整接入 Supabase Auth，实现真实邮箱密码登录/注册链路，动态切换个人主页状态。
  - **发布链路**：打通端侧视频上传，支持本地极限压缩转码并自动上传至云端节点（支持 R2 兜底机制），同步写入 Supabase 数据库发布动态。
  - **个人主页展示**：打通真实用户数据与发布记录查询，实现动态瀑布流取代原有的模拟数据，形成闭环体验。
- **待开发:** 
  - (核心商业闭环已全链路打通，随时可准备部署或开启新业务模块拓展)

## 7. 终极多媒体架构 (The Ultimate 0-Cost Media Architecture)
**核心商业逻辑：端侧极限压榨算力，云端绝对 0 成本中转。**
这套架构是国民级 APP 的降维打击方案，必须严格在 `packages/core/core_media/` 或相关模块中贯彻：

### 📸 图片：端侧所见即所得与极限压缩
- **所见即所得裁剪:** 使用 `image_cropper`，用户选图后全屏沉浸裁剪。上传前看到的像素，就是瀑布流里展示的像素（1:1映射）。
- **极限压缩:** **绝对禁止原图直传**。必须使用 `flutter_image_compress` 压榨手机硬件，将长边限制在 1920px 级别并转为 `WebP` 格式。10MB 的图必须压到 200KB-400KB 左右。
- **内存防线:** 渲染时 `CachedNetworkImage` 必须基于设备 DPI 动态计算 `memCacheWidth`，物理阻断 OOM。

### 🎬 视频：15秒精确控制与硬件转码
- **时间轴截取:** 用户上传大视频时，提供底层解码的时间轴，支持最长 15 秒的精确滑动截取。
- **帧级封面提取:** 在截取区间内，允许滑动选取最满意的一帧，端侧抽取为高清 WebP 图片作为封面，分离上传，保证瀑布流封面秒开。
- **端侧硬件转码:** 引入 `ffmpeg_kit_flutter`（或类似硬解方案），发布时在手机端强制硬件转码为 H.264 (720p/1080p, 动态码率 2-4Mbps)。将 200MB 的视频压到 5MB 以内。

### 💰 0 成本护城河
- **服务器 CPU 消耗为 0:** 压缩、转码、抽帧全部白嫖千万用户的手机终端算力。
- **下行流量费 (Egress) 为 0:** 所有媒体资产压缩后直传 **Cloudflare R2** 边缘节点，配合全球 CDN 实现极速且免费的分发。
- **渲染零掉帧:** 瀑布流无论滑动多快，必须采用**单一播放器实例视口检测 (Single Player Viewport Tracking)**，进入视口中心才挂载播放，滑出即销毁。

## 8. 终极记忆规范：代码即记忆 (AI Anchors)
为了保持记忆与代码的绝对同步，本项目采用“代码锚点”机制。不要在外部文档中维护容易过期的状态，而是直接在代码中埋入标签：
- `@AI_CONTEXT`: 用于标记临时方案、技术债、或者特定业务逻辑的上下文。例如：`// @AI_CONTEXT: [2026-06-26] 临时依赖，下个版本用 go_router 解耦。`
- `@AI_CORE_MECHANISM`: 用于标记核心底层机制（如零开销跑马灯、视频播放池），警告 AI 不要用常规思路去修改它。
当 AI 接手开发时，会自动扫描这些标签获取上下文。开发过程中，如果做出非标架构决策，**必须在代码中留下对应的 AI 锚点注释**。

## 9. 最新架构升级 (Architecture Evolution)
**[2026-06-26] 第一步：终极解耦 (Zero Horizontal Coupling)**
- 已全量引入 `go_router`。
- `feature_profile` 和 `feature_shop` 之间的横向依赖已被彻底物理剥离。
- 全局路由中枢位于 `apps/zhixuan_main/lib/router/app_router.dart`，所有的模块只和主工程发生路由交互。

**[2026-06-26] 第二步：中枢神经 (Reactive State Hub)**
- 已在 `zhixuan_main` 引入 `flutter_riverpod` 和 `riverpod_annotation`。
- `main.dart` 中已包裹 `ProviderScope`，确立了全局状态和依赖注入 (DI) 的绝对中枢。
- 后续开发需遵循 Riverpod 的响应式流范式，摒弃面条式事件回调。

**[2026-06-26] 第三步：绝对防线 (DDD & Functional Error Handling)**
- 核心网络层 `core_network` 引入了 `AppFailure` 领域错误基类和 `FutureEither<T>` 别名。
- **强制约束：** 严禁在 UI 层使用 `try-catch`。所有的业务层方法必须返回 `FutureEither<T>`（即 `Future<Either<AppFailure, T>>`），UI 层必须通过 `.fold((error) => ..., (data) => ...)` 强制处理所有成功与失败的分支，从根本上杜绝未捕获异常导致的崩溃。
