# Debug Session: camera-native-validation
- **Status**: [OPEN]
- **Issue**: Windows 桌面端相机需要验证原生启用状态、硬件加速配置是否真实生效，修复顶部状态栏异常显示，并基于设备能力优化视频帧率。
- **Debug Server**: http://127.0.0.1:7777/event
- **Log File**: .dbg/trae-debug-log-camera-native-validation.ndjson

## Reproduction Steps
1. 启动 `apps/zhixuan_main` Windows 桌面应用。
2. 进入视频页，点击加号进入相机页。
3. 观察顶部是否出现设备名与提示文案。
4. 观察相机预览清晰度、延迟、设备选择是否正确。
5. 录制或切换摄像头，观察是否有异常日志或明显卡顿。

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| H1 | `ResolutionPreset.max / fps / bitrate / prepareForVideoRecording` 未被 `camera_windows` 真正采纳，当前只是目标参数 | High | Med | Pending |
| H2 | 顶部异常“状态栏”实际上是业务 UI 自绘的设备名和提示文案，不是系统原生状态栏 | High | Low | Pending |
| H3 | 当前命中了错误摄像头或低质量 `USB2.0 UVC` 设备，导致清晰度与延迟都偏差 | High | Low | Pending |
| H4 | 当前设备实际输出帧率低于目标值，30FPS 只是请求值而不是最终值 | Med | Med | Pending |

## Log Evidence
- `pre-fix` 应用日志：仅枚举到 `1` 个摄像头，名称为 `USB2.0 HD IR UVC WebCam ...`，镜头方向为 `front`
- `pre-fix` 应用日志：初始化目标参数已经下发，`resolutionPreset=max`、`fpsTarget=30`、`videoBitrateTarget=12000000`
- `pre-fix` 应用日志：原生最终协商的预览尺寸为 `1280x720`，初始化耗时约 `1009ms`
- 系统设备清单：Windows 暴露出两个同名 `USB2.0 HD IR UVC WebCam` 端点，但 Flutter 应用层当前只拿到 `MI_00` 这一路
- 插件源码证据：`camera_windows` 通过 `PlatformMediaSettings` 把 `resolutionPreset / framesPerSecond / videoBitrate` 传给原生层
- 插件源码证据：Windows 端 `prepareForVideoRecording()` 为 `No-op`，说明它不是当前低延迟的真实加速开关
- 用户截图证据：顶部异常显示的“状态栏信息”来自相机页自绘的设备名与 `超清预览 · 30FPS 优先` 文案，而非系统原生状态栏

## Verification Conclusion
- `H1` 部分确认：相机目标参数确实已传入原生插件，但 Windows 端 `prepareForVideoRecording` 不生效；当前真正拿到的是 `1280x720` 预览，而不是“绝对最大画质”
- `H2` 确认：顶部异常信息是业务 UI 自绘，不是系统状态栏；已在修复中移除文本并改为纯净控制按钮
- 用户复测反馈：`顶部已纯净`
- `H3` 确认：当前问题不是“选错多个候选设备”导致，应用层只枚举到 `1` 个可用摄像头，而且它本身就是 `USB2.0 HD IR UVC WebCam`
- `H4` 部分确认：此前仅请求 `30FPS`，并未证明设备实际输出帧率；修复中已把目标提升为 `60FPS 优先`，交由原生层按能力回落
