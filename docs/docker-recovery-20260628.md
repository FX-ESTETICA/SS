# Docker 故障处理记录 - 2026-06-28

## 目标

- 排查并修复本机 Docker 引擎无法启动的问题。
- 验证 `docker ps` 与 `docker run hello-world`。
- 为后续 `supabase start` 提供可用的本地容器基础设施。

## 当前结论

截至当前阶段，问题并非单纯的 Docker Engine 崩溃，而是安装链路与运行前置条件同时缺失：

1. 系统中不存在 `docker` 命令。
2. `winget list --id Docker.DockerDesktop` 未发现已安装的 Docker Desktop。
3. `Get-Service *docker*` 未返回任何 Docker 服务。
4. `wsl --status` 显示当前机器未安装 Windows Subsystem for Linux。
5. `daemon.json` 不存在，因此不存在旧配置语法错误导致的启动失败。
6. 磁盘空间充足，Docker 常用端口暂未发现被占用。

## 已执行的检查

### 1. Docker 安装状态

```powershell
docker --version
winget list --id Docker.DockerDesktop
Get-Service *docker* | Format-List Name,Status,DisplayName
```

结果：

- `docker --version`：命令不存在。
- `winget list --id Docker.DockerDesktop`：未找到已安装程序包。
- `Get-Service *docker*`：未发现 Docker 相关服务。

### 2. WSL 与虚拟化前置

```powershell
wsl --status
Get-ComputerInfo | Select-Object HyperVisorPresent, CsProcessors, OsName, OsVersion
systeminfo | findstr /i "Hyper-V Requirements Virtualization"
```

结果：

- `wsl --status`：提示未安装 WSL。
- 当前系统为 Windows 11 专业版。
- 当前可见 `HyperVisorPresent : False`，说明 Hyper-V/虚拟化运行层尚未启用到可用状态。

### 3. 配置、磁盘、端口排查

```powershell
$daemonPath = Join-Path $env:ProgramData 'Docker\config\daemon.json'
Get-PSDrive -PSProvider FileSystem
Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -in 2375,2376,4789,7946 }
```

结果：

- `daemon.json`：不存在。
- 磁盘空间：`C:` 与 `D:` 均有充足剩余空间。
- Docker 常见端口：未发现冲突监听。

## 当前根因判断

主因分两层：

1. **Docker Desktop 未安装**，因此根本不存在可启动的 Docker Engine。
2. **WSL2 前置缺失**，即使只安装 Docker Desktop，后续也大概率因底层虚拟化环境不完整而无法正常启动。

## 正在执行的修复动作

```powershell
wsl --install --no-distribution
winget install --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements
```

说明：

- 第一条用于补齐 WSL 前置。
- 第二条用于静默安装 Docker Desktop。
- 上述步骤可能触发管理员授权，并且在某些系统状态下需要重启后才能完全生效。

## 待完成验证

安装和前置启用结束后，需要继续执行：

```powershell
docker --version
docker info
Get-Service *docker*
docker ps
docker run hello-world
```

如验证通过，再继续执行：

```powershell
npx supabase start
```

## 复盘建议

- 以后在判断 “Docker 启动失败” 前，先做三步基础排查：`docker --version`、`winget list --id Docker.DockerDesktop`、`wsl --status`。
- 若这三项任一缺失，应先走安装与前置修复链路，而不是直接排查 `daemon.json`。
