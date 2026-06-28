# 登录状态测试报告 - 2026-06-28

## 测试目标

- 验证当前系统中的登录状态是否已正确持久化存储。
- 检查会话令牌的有效性、过期时间与存储安全性。
- 核对系统中需要权限的页面与功能是否正确识别登录状态。
- 排查登录状态异常丢失、权限判断缺失与越权访问风险。

## 测试范围

- Flutter Windows 客户端
- Supabase Auth 会话持久化
- Tab 页面与功能入口
- 本机已落盘的用户会话缓存

## 核心结论

### 1. 会话已持久化，但存储方式不安全

当前系统存在本地会话缓存文件：

- `C:\Users\49975\AppData\Roaming\com.zhixuan\zhixuan_main\shared_preferences.json`

在该文件中发现以下关键字段：

- `flutter.sb-izpolbeqdttjffbemvjr-auth-token`
- `flutter.supabase.auth.token-code-verifier`

说明：

- 登录状态已被成功持久化到本机。
- 但会话内容保存在明文 `shared_preferences.json` 中，不属于安全存储。
- 对桌面端而言，这意味着本机其他高权限进程或本地攻击者可直接读取 token。

### 2. 当前落盘 access token 已过期

从本地缓存解析出的关键信息如下：

- 用户邮箱：`499755740@qq.com`
- 用户 ID：`15f83e50-b8f3-4ef2-a942-67f7d7d5f553`
- `expires_at`：`2026-06-27 21:29:09` 本地时间
- 检查时间：`2026-06-28 16:54:47` 本地时间
- 结论：当前本地缓存中的 `access token` 已过期

说明：

- 本地缓存中仍存在 `refresh token`，理论上 SDK 可能在应用启动后尝试自动刷新。
- 但代码中没有显式配置 `persistSession`、`autoRefreshToken`，也没有手动刷新或刷新失败兜底逻辑。
- 因此，当前项目对“过期后自动续期成功”的验证仍然不充分，属于依赖 SDK 默认行为。

### 3. access token 过期时间本身基本合理，但整体安全设计不达标

本地缓存中的会话信息包含：

- `expires_in = 3600`

判断：

- 1 小时 access token 有效期本身属于常见且相对合理的安全配置。
- 但由于 refresh 策略、rotation 策略、多设备策略都未在仓库中显式配置或可审计，因此不能判定整套会话安全方案“符合设计要求”。
- 更严重的问题是 token 明文持久化，直接拉低整体安全等级。

## 代码实现检查

### Supabase 初始化

文件：

- `apps/zhixuan_main/lib/main.dart`
- `packages/core/core_network/lib/src/supabase_service.dart`

现状：

- 项目已调用 `Supabase.initialize(...)`
- 未显式声明认证参数，如：
  - `persistSession`
  - `autoRefreshToken`
  - 刷新失败处理

风险：

- 认证行为依赖 SDK 默认值，升级依赖后可能产生行为漂移。
- 无法从代码层直接审计“令牌续期策略是否符合当前系统设计要求”。

### 登录与登出逻辑

文件：

- `packages/core/core_network/lib/src/data/auth_repository.dart`
- `packages/features/feature_profile/lib/src/presentation/profile_screen.dart`

现状：

- 已实现邮箱密码登录、注册、登出。
- 个人页通过 `auth.currentSession != null` 判断是否登录。
- 个人页通过 `onAuthStateChange` 刷新 UI。

风险：

- 登录态判断只集中在“我的页”局部 UI，不是全局认证中心。
- 登录失败时，如果错误文案包含 `Invalid login credentials`，会直接触发注册，这会把“输错密码”与“用户不存在”混淆。

## 页面与权限识别检查

### 识别正确

- `ProfileScreen`
  - 能根据 `currentSession != null` 切换登录前/登录后界面。
  - 能在登出后通过事件监听自动刷新 UI。

### 存在缺陷

- `ChatScreen`
  - 无登录拦截。
  - 发送消息使用硬编码 `senderId = 'user_123'`。
  - 无法证明消息发送与当前登录用户强绑定。

- `VideoUploadScreen`
  - 可直接从视频页进入，没有登录校验。

- `VideoEditorScreen`
  - 发布时才读取 `currentUser`，但进入编辑器本身未校验登录。
  - 未登录时会回退到匿名作者名，说明发布流程没有真正阻断匿名操作。

- `BookingRecordsScreen`
  - 主入口直接挂载，无登录拦截。
  - 当前虽然是静态演示数据，但一旦接入真实数据会直接暴露越权风险。

- 商城详情页
  - `ProductDetailScreen` 与 `LocalServiceDetailScreen` 的 `isMerchantMode` 默认值为 `true`。
  - 这会带来商家编辑能力误暴露风险。

## 后端权限策略检查

文件：

- `supabase/migrations/20260622_setup_storage_and_auth_policies.sql`

发现：

- `storage.objects` 上传策略允许游客写入
- `videos` 插入策略允许所有人写入

结论：

- 即使前端未来补上页面级登录校验，只要后端 RLS 仍然开放，匿名写入风险依旧存在。
- 当前系统的身份验证设计没有形成“前端守卫 + 后端强制”的闭环。

## 风险评级

- P0 高危：会话 token 明文保存在 `shared_preferences.json`
- P0 高危：`access token` 已过期，但代码未显式定义刷新与失败处理策略
- P0 高危：聊天、视频上传、视频发布、预约页均无统一登录守卫
- P0 高危：后端 `videos insert` 与存储上传策略对匿名用户开放
- P1 中危：登录失败自动转注册，存在误注册与错误账户创建风险
- P1 中危：商家模式默认开启，存在权限越界展示

## 测试结论

当前系统 **未通过** 登录状态与权限设计验收，原因如下：

1. 登录状态已持久化，但存储安全性不合格。
2. 本地 access token 已过期，自动续期链路未在代码中显式可审计。
3. 只有“我的页”能较好识别登录态，其他关键模块缺乏统一权限判断。
4. 后端策略未收紧，匿名用户仍可执行敏感写操作。

## 整改建议

### P0 必做

1. 将会话存储从明文 `shared_preferences` 切换到系统安全存储方案。
2. 在 `Supabase.initialize` 显式声明并统一管理认证参数与刷新策略。
3. 建立全局 Auth 状态中心，统一驱动路由守卫与页面守卫。
4. 给聊天、上传、发布、预约、资料编辑入口补全登录拦截。
5. 收紧 Supabase RLS，把敏感写操作至少限制为 `authenticated`。

### P1 建议

1. 移除“登录失败自动注册”逻辑，改为明确区分登录与注册流程。
2. 将商家模式默认值改为 `false`，仅从商家入口显式打开。
3. 增加会话过期、刷新失败、异地登录失效的统一提示与回收机制。

## 备注

本次报告基于以下两类证据生成：

- 仓库代码静态审计
- 当前系统本地持久化文件的真实内容检查

本次未执行完整 UI 自动化登录回归，因此“应用启动后 SDK 是否会自动刷新已过期 token 并成功恢复 UI”仍需做一轮运行态验证。
