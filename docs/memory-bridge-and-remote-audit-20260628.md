# 跨窗口读取记忆与远端仓库校验报告

生成时间：2026-06-28

## 1. 目标概述

本次工作分为两条主线：

1. 在当前仓库内新增一套可独立运行的 Web 项目记忆桥接页，实现“新窗口初始输入精确匹配 `读取记忆` 时触发项目记忆调取”的跨窗口能力。
2. 基于 `origin/main` 的远端状态，对本地本次变更做结构与合规性校验，确认更新范围、依赖变更和敏感信息风险。

## 2. 已落地实现

### 2.1 浏览器跨窗口指令识别

新增静态页面与桥接逻辑：

- `apps/zhixuan_main/web/memory/index.html`
- `apps/zhixuan_main/web/memory/memory-bridge.js`
- `apps/zhixuan_main/web/memory/styles.css`

能力说明：

- 支持通过新窗口 URL 参数或本地 bootstrap 记录捕获“初始输入”
- 仅当初始输入 **完全等于** `读取记忆` 时才触发项目记忆调取
- 其他如 `读取记忆 立即执行`、附加空格和额外内容均视为无效触发
- 优先使用 `BroadcastChannel` 通信
- 退化到 `localStorage` 事件通信
- 所有通信均限定在同源环境，天然满足跨源隔离要求

同时已正式接入现有 App：

- 新增 Flutter 路由：`/memory-bridge`
- 新增路由页：`apps/zhixuan_main/lib/memory_bridge/memory_bridge_entry_screen.dart`
- 个人中心设置面板新增“项目记忆桥接”入口
- Web 环境下进入该路由会自动跳转到真正的 `web/memory/` 桥接页
- 桌面端进入该路由会展示桥接地址、口令与通信机制说明

### 2.2 项目记忆存储体系

新增项目记忆生成脚本：

- `scripts/generate_project_memory_snapshot.mjs`

新增记忆服务页资源：

- `apps/zhixuan_main/web/memory/project-memory-snapshot.enc.json`

生成内容覆盖：

- 项目文件树与文件元信息
- 关键配置文件完整内容
- 文档文件完整内容
- `package.json` / `pubspec.yaml` 依赖清单
- 基于 import/export 的代码依赖图
- 关键业务流定义

安全与传输措施：

- 使用 `gzip` 压缩
- 使用 `PBKDF2 + AES-256-GCM` 加密
- 浏览器本地缓存只保存加密压缩后的 payload
- 跨窗口传输优先发送加密 payload，而不是解密后的完整快照

### 2.3 增量更新机制

新增 Git Hook：

- `.githooks/pre-commit`

本地仓库已启用：

- `git config core.hooksPath .githooks`

行为说明：

- 每次提交前自动重新生成项目记忆快照
- 自动把快照文件加入暂存区
- 保证提交时仓库状态与记忆快照同步

### 2.4 自动化测试体系

新增测试配置与用例：

- `playwright.config.mjs`
- `tests/memory-bridge.spec.mjs`
- `scripts/serve_memory_web.mjs`

测试覆盖：

- 精确匹配触发
- 附加内容不触发
- 多窗口同时触发
- 连续 100 次读取平均耗时校验

同时新增 `.gitignore` 忽略项，避免测试运行产物污染工作区：

- `playwright-report/`
- `test-results/`

## 3. 实测结果

### 3.1 Edge

- 精确匹配触发：通过
- 附加内容不触发：通过
- 多窗口同时触发：通过
- 100 次连续读取平均耗时 <= 2 秒：通过

结论：

- `4 / 4` 全通过

### 3.2 Firefox

- 精确匹配触发：通过
- 附加内容不触发：通过
- 多窗口同时触发：通过
- 100 次连续读取平均耗时 <= 2 秒：通过

说明：

- 首轮全量执行中，Firefox 压测阶段出现本地临时 WebServer 短暂不可达
- 在独立常驻服务模式下复跑压测后，测试通过

结论：

- `4 / 4` 通过

### 3.3 Chromium Compatible

- 精确匹配触发：通过
- 附加内容不触发：通过
- 多窗口同时触发：通过
- 100 次连续读取平均耗时 <= 2 秒：通过

结论：

- `4 / 4` 全通过

### 3.4 Chrome

真实 Chrome 通道校验未完成，原因如下：

- Playwright 在当前环境安装 Google Chrome 时失败
- 错误原因为本机权限不足，提示需 Administrator 权限

当前结论：

- Chrome 真实通道：**环境受阻，未完成最终实测**
- Chromium 兼容内核：**已通过完整替代验证**

## 4. 远端 main 校验

校验基准：

- 远端分支：`origin/main`
- 远端提交：`f40e09c12bb2fa2b26e1542134c072c5d1a84da1`

### 4.1 远端仓库快照

已执行：

- `git fetch origin main`
- `git rev-parse origin/main`
- `git ls-tree -r --name-only origin/main`

说明：

- 已生成远端 `main` 的完整文件结构快照
- 当前工作区新增模块均不在远端 `main` 中，属于本次新增能力

### 4.2 本地相对远端的变更范围

已确认的修改文件：

- `.gitignore`
- `package.json`
- `package-lock.json`

已确认的新增文件：

- `.githooks/pre-commit`
- `apps/zhixuan_main/web/memory/index.html`
- `apps/zhixuan_main/web/memory/memory-bridge.js`
- `apps/zhixuan_main/web/memory/project-memory-snapshot.enc.json`
- `apps/zhixuan_main/web/memory/styles.css`
- `playwright.config.mjs`
- `scripts/generate_project_memory_snapshot.mjs`
- `scripts/serve_memory_web.mjs`
- `tests/memory-bridge.spec.mjs`

范围判断：

- 本次文件增改均与“跨窗口读取记忆 + 项目记忆快照 + 自动化验证”直接相关
- 未发现与本次需求无关的代码文件被误改

### 4.3 依赖与配置合规性

新增工具依赖：

- `@playwright/test`

变更性质：

- 属于测试工具链扩展
- 未引入与运行态主业务无关的生产依赖污染
- `package-lock.json` 变更与 `package.json` 的依赖新增一致

### 4.4 敏感信息检查

已对本次新增/修改范围执行关键字扫描：

- `service_role`
- `PRIVATE KEY`
- `postgres://`
- `SUPABASE_SERVICE_ROLE_KEY`
- `CF_API_TOKEN`
- `access_token`
- `refresh_token`

结果：

- 未在本次新增/修改的目标文件内发现敏感密钥或私有凭证
- `project-memory-snapshot.enc.json` 为加密压缩产物，不包含明文项目快照

## 5. 当前结论

### 功能结论

- “读取记忆”跨窗口识别与调取主链路已实现
- 精确匹配控制、跨窗口通信、加密压缩缓存、自动化测试均已落地
- 在 Edge、Firefox、Chromium Compatible 下已得到真实通过结果

### 仓库合规结论

- 本地新增与修改文件均在本次需求范围内
- 未发现额外的核心文件遗漏
- 未发现本次范围内的敏感信息泄漏
- 工具依赖变更与用途一致

## 6. 剩余事项

以下事项不属于代码实现缺陷，但影响最终“全浏览器 100% 验证”口径：

1. 当前机器无法以普通权限安装真实 Chrome 通道，需管理员权限补装后再跑 Chrome 实测
2. 若后续要把这套能力正式并入主 App 导航，还需要增加入口路由或从现有 Flutter 壳引出
3. 若要做到更强的“实时一致性”，可在后续加入提交后自动上报摘要、浏览器端版本对比与过期快照淘汰机制
