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

void main() async {
  // 确保 Flutter 引擎完全绑定，这是初始化云端服务的前提
  WidgetsFlutterBinding.ensureInitialized();

  // 扩大底层 C++ 纹理缓存池 (ImageCache) 到 256MB 和 1000 张图片。
  // 彻底消灭因缓存太小导致的图片频繁 GC (垃圾回收) 和滑动时的主线程重新解码卡顿
  PaintingBinding.instance.imageCache.maximumSizeBytes = 256 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 1000;

  // 桌面端无边框窗口初始化
  await windowManager.ensureInitialized();
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

  // 1. 初始化全球云端引擎 (Supabase)
  // 使用您专属的意大利节点项目密钥，正式接管云端！
  await SupabaseService.initialize(
    url: 'https://izpolbeqdttjffbemvjr.supabase.co',
    publishableKey: 'sb_publishable_MFLwIbZIgBmUAnP9rqcSVQ_zzTwpq3y',
  );

  // 2. 初始化全局基础设置 (网络API、本地数据库引擎等)
  final apiClient = ApiClient(baseUrl: 'https://api.zhixuan.global');

  // 3. 启动超级 APP 主引擎，并注入 ProviderScope (Riverpod 的绝对中枢)
  runApp(
    ProviderScope(
      child: ZhixuanSuperApp(apiClient: apiClient),
    ),
  );
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
  int _currentIndex = 0;

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
          onTap: (index) => setState(() => _currentIndex = index),
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
                icon: Icon(_currentIndex == 2
                    ? Icons.play_circle
                    : Icons.play_circle_outline),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(_currentIndex == 3
                    ? Icons.calendar_month
                    : Icons.calendar_today_outlined),
                label: ''),
            BottomNavigationBarItem(
                icon: Icon(
                    _currentIndex == 4 ? Icons.person : Icons.person_outline),
                label: ''),
          ],
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
