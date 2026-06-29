import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_video/feature_video.dart';
import 'package:feature_shop/feature_shop.dart';
import 'package:feature_im/feature_im.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:media_kit/media_kit.dart'; // 引入顶级播放器引擎
import 'package:window_manager/window_manager.dart';
import 'router/app_router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

// #region debug-point A:startup-probe
Future<void> _debugStartupProbe(
  String hypothesisId,
  String location,
  String msg, {
  Map<String, Object?> data = const <String, Object?>{},
  String? traceId,
}) async {
  try {
    final logFile = File(r'c:\Users\49975\Desktop\智选\.dbg\trae-debug-log-startup-black-screen.ndjson');
    final event = <String, Object?>{
      'sessionId': 'video-black-frame',
      'runId': 'post-fix',
      'hypothesisId': hypothesisId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'msg': '[DEBUG] $msg',
      'data': data,
      if (traceId != null) 'traceId': traceId,
    };
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString('${jsonEncode(event)}\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
// #endregion

// 强制覆盖全局 Http 证书校验（仅用于解决桌面端证书链不全的问题）
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  final startupTraceId = 'startup-${DateTime.now().microsecondsSinceEpoch}';
  final startupStopwatch = Stopwatch()..start();
  // 确保 Flutter 引擎完全绑定，这是初始化云端服务的前提
  WidgetsFlutterBinding.ensureInitialized();
  // #region debug-point A:start
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:main',
    'startup_enter',
    traceId: startupTraceId,
    data: <String, Object?>{
      'platform': Platform.operatingSystem,
    },
  ));
  // #endregion

  // 解决 Windows 桌面端由于缺少根证书导致的 HttpClient 访问 HTTPS 图片失败的问题
  HttpOverrides.global = MyHttpOverrides();

  // 扩大底层 C++ 纹理缓存池 (ImageCache) 到 256MB 和 1000 张图片。
  // 彻底消灭因缓存太小导致的图片频繁 GC (垃圾回收) 和滑动时的主线程重新解码卡顿
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 1000;

  // 桌面端无边框窗口初始化
  await windowManager.ensureInitialized();
  // #region debug-point A:window-ready
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:windowManager.ensureInitialized',
    'window_manager_ready',
    traceId: startupTraceId,
    data: <String, Object?>{
      'elapsedMs': startupStopwatch.elapsedMilliseconds,
    },
  ));
  // #endregion
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(360, 640),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 隐藏原生白色标题栏
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 0. 初始化全局视频 C++ 引擎 (必须在 App 启动的最早期)
  MediaKit.ensureInitialized();
  // #region debug-point A:mediakit-ready
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:MediaKit.ensureInitialized',
    'mediakit_ready',
    traceId: startupTraceId,
    data: <String, Object?>{
      'elapsedMs': startupStopwatch.elapsedMilliseconds,
    },
  ));
  // #endregion
  
  // 三端统一相机预热：让首次点击拍摄更接近秒开体感
  unawaited(CameraWarmupService.instance.warmup());
  // #region debug-point A:camera-warmup-fired
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:CameraWarmupService.warmup',
    'camera_warmup_fired',
    traceId: startupTraceId,
    data: <String, Object?>{
      'elapsedMs': startupStopwatch.elapsedMilliseconds,
    },
  ));
  // #endregion

  // 1. 初始化全球云端引擎 (Supabase)
  // 使用您专属的意大利节点项目密钥，正式接管云端！
  await SupabaseService.initialize(
    url: 'https://izpolbeqdttjffbemvjr.supabase.co',
    publishableKey: 'sb_publishable_MFLwIbZIgBmUAnP9rqcSVQ_zzTwpq3y',
  );
  // #region debug-point A:supabase-ready
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:SupabaseService.initialize',
    'supabase_ready',
    traceId: startupTraceId,
    data: <String, Object?>{
      'elapsedMs': startupStopwatch.elapsedMilliseconds,
    },
  ));
  // #endregion

  // 2. 初始化全局基础设置 (网络API、本地数据库引擎等)
  final apiClient = ApiClient(baseUrl: 'https://api.zhixuan.global');

  // 3. 启动超级 APP 主引擎，并注入 ProviderScope (Riverpod 的绝对中枢)
  runApp(
    ProviderScope(
      child: ZhixuanSuperApp(apiClient: apiClient),
    ),
  );
  // #region debug-point A:runapp
  unawaited(_debugStartupProbe(
    'A',
    'main.dart:runApp',
    'run_app_dispatched',
    traceId: startupTraceId,
    data: <String, Object?>{
      'elapsedMs': startupStopwatch.elapsedMilliseconds,
    },
  ));
  // #endregion

  unawaited(() async {
    await DiskVideoCacheManager.instance.initialize();
    // #region debug-point A:disk-cache-ready
    await _debugStartupProbe(
      'A',
      'main.dart:DiskVideoCacheManager.initialize',
      'disk_cache_ready',
      traceId: startupTraceId,
      data: <String, Object?>{
        'elapsedMs': startupStopwatch.elapsedMilliseconds,
      },
    );
    // #endregion
  }());
}

class ZhixuanSuperApp extends StatelessWidget {
  final ApiClient apiClient;

  const ZhixuanSuperApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return Listener(
      // 全局拦截所有交互事件（点击、滑动、移动），用于唤醒底层休眠动画
      onPointerDown: (_) => BackgroundManager.instance.notifyInteraction(),
      onPointerMove: (_) => BackgroundManager.instance.notifyInteraction(),
      onPointerUp: (_) => BackgroundManager.instance.notifyInteraction(),
      behavior: HitTestBehavior.translucent,
      child: MaterialApp.router(
        title: '智选 (Zhixuan)',
        // 强制使用底层设计系统中定义的主题，彻底杜绝 UI 碎片化
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
      ),
    );
  }
}

/// 超级 APP 的主外壳 (Shell)
/// 未来微信、淘宝、抖音模块都会被动态挂载到这里的不同 Tab 中
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 默认启动页修改为视频页（索引 2）
  int _currentIndex = 2;

  Future<void> _handleBottomNavigationTap(int index) async {
    if (index == 2) {
      if (_currentIndex == 2) {
        await InstantUI.showDialog<void>(
          context,
          barrierDismissible: false,
          barrierColor: Colors.black,
          builder: (context) => const VideoUploadScreen(),
        );
        return;
      }
      setState(() => _currentIndex = 2);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // 定义底部 Tab 对应的页面数组 (聊天, 购物, 视频, 预约, 我的)
    final List<Widget> pages = [
      const ChatScreen(), // 0: 挂载微信 IM 模块
      ShopFeedScreen(isTabActive: _currentIndex == 1), // 1: 挂载淘宝商城模块
      VideoFeedScreen(isTabActive: _currentIndex == 2), // 2: 挂载抖音短视频模块
      const BookingRecordsScreen(), // 3: 预约/消费记录模块 (已替换为全新极简 UI)
      ProfileScreen(
        onLoginSuccess: () {
          // 登录成功后跳转到视频页（索引 2）
          setState(() => _currentIndex = 2);
        },
      ), // 4: 挂载个人中心模块
    ];

    return Scaffold(
      extendBody: true, // 允许 body 延伸到底部导航栏下方
      // 彻底移除原生 AppBar，实现绝对沉浸
      appBar: null,
      // 使用 IndexedStack 保持页面状态，并在最顶层悬浮覆盖无边框窗口控制栏
      body: Stack(
        children: [
          // 【终极沉浸】：如果要在商城页让图片盖住甚至超越标题栏的视觉限制
          // IndexedStack 本身就会撑满整个 Scaffold（因为 extendBody: true 且没有 appBar）
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // 悬浮在壁纸最上方的自定义窗口控制栏
          // 彻底抛弃 WindowCaption，用最原始的 Container 覆盖拖拽区域
          // 这样既保留了拖拽移动窗口的能力，又绝对不会产生任何阻挡渲染的黑色安全区
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 32, // 原生 Windows 标题栏高度大约是 32
            child: Row(
              children: [
                // 左侧绝大部分区域用于拖拽窗口
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      windowManager.startDragging();
                    },
                    child: Container(
                      color: Colors.transparent, // 绝对透明
                    ),
                  ),
                ),
                // 右侧放置三个原生的控制按钮 (最小化、最大化、关闭)
                // 强制要求按钮也是绝对透明背景，只绘制白色线条图标
                Row(
                  children: [
                    _buildWindowButton(
                        Icons.minimize, () => windowManager.minimize()),
                    _buildWindowButton(Icons.crop_square, () async {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    }),
                    _buildWindowButton(Icons.close, () => windowManager.close(),
                        isClose: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent, // 移除点击水波纹
          highlightColor: Colors.transparent, // 移除点击高光
          hoverColor: Colors.transparent, // 移除 Windows 端鼠标悬停时的背景色块（解决切割感）
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _handleBottomNavigationTap,
          elevation: 0, // 移除阴影
          backgroundColor: Colors.transparent, // 完全透明背景
          showSelectedLabels: false, // 隐藏选中时的文字
          showUnselectedLabels: false, // 隐藏未选中时的文字
          // 绝对黑白原则：无论选中还是未选中，全部都是纯白，没有任何透明度！
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
                icon: Icon(_currentIndex == 0
                    ? Icons.chat_bubble
                    : Icons.chat_bubble_outline),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(_currentIndex == 1
                    ? Icons.shopping_bag
                    : Icons.shopping_bag_outlined),
                label: ''),
            BottomNavigationBarItem(
                icon: _currentIndex == 2
                    ? _buildVideoTabIcon(isSelected: true)
                    : const Icon(Icons.play_circle_outline),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(_currentIndex == 3
                    ? Icons.calendar_month
                    : Icons.calendar_today_outlined),
                label: ''),
            BottomNavigationBarItem(
                icon: _buildProfileTabIcon(isSelected: _currentIndex == 4),
                label: ''),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTabIcon({required bool isSelected}) {
    if (SupabaseService.currentSession == null) {
      return Icon(isSelected ? Icons.person : Icons.person_outline);
    }

    return CurrentUserAvatar(
      size: isSelected ? 24 : 22,
      fallbackIcon: isSelected ? Icons.person : Icons.person_outline,
      fallbackIconSize: isSelected ? 15 : 14,
    );
  }

  Widget _buildVideoTabIcon({required bool isSelected}) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 2.2 : 2.0,
            ),
          ),
          child: Center(
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 10,
                    height: isSelected ? 2.2 : 2.0,
                    color: Colors.white,
                  ),
                  Container(
                    width: isSelected ? 2.2 : 2.0,
                    height: 10,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 构建自定义的 Windows 窗口控制按钮
  Widget _buildWindowButton(IconData icon, VoidCallback onTap,
      {bool isClose = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 46,
        height: 32,
        color: Colors.transparent, // 绝对透明背景
        child: Center(
          child: Icon(
            icon,
            color: Colors.white, // 纯白图标
            size: 16, // 缩小图标尺寸，模仿原生
          ),
        ),
      ),
    );
  }
}
