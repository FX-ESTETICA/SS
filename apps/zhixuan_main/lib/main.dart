import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_video/feature_video.dart';
import 'package:feature_shop/feature_shop.dart';
import 'package:feature_im/feature_im.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:media_kit/media_kit.dart'; // 引入顶级播放器引擎
import 'package:window_manager/window_manager.dart';

void main() async {
  // 确保 Flutter 引擎完全绑定，这是初始化云端服务的前提
  WidgetsFlutterBinding.ensureInitialized();
  
  // 桌面端无边框窗口初始化
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
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
  
  // 3. 启动超级 APP 主引擎
  runApp(ZhixuanSuperApp(apiClient: apiClient));
}

class ZhixuanSuperApp extends StatelessWidget {
  final ApiClient apiClient;

  const ZhixuanSuperApp({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智选 (Zhixuan)',
      // 强制使用底层设计系统中定义的主题，彻底杜绝 UI 碎片化
      theme: AppTheme.lightTheme, 
      debugShowCheckedModeBanner: false,
      home: const SuperAppShell(),
    );
  }
}

/// 超级 APP 的主外壳 (Shell)
/// 未来微信、淘宝、抖音模块都会被动态挂载到这里的不同 Tab 中
class SuperAppShell extends StatefulWidget {
  const SuperAppShell({super.key});

  @override
  State<SuperAppShell> createState() => _SuperAppShellState();
}

class _SuperAppShellState extends State<SuperAppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 定义底部 Tab 对应的页面数组
    final List<Widget> pages = [
      const ChatScreen(),      // 挂载微信 IM 模块
      const VideoFeedScreen(), // 挂载抖音短视频模块
      const ShopFeedScreen(),  // 挂载淘宝商城模块
      ProfileScreen(
        onLoginSuccess: () {
          // 登录成功后跳转到视频页（索引 1）
          setState(() => _currentIndex = 1);
        },
      ), // 挂载个人中心模块
    ];

    return Scaffold(
      extendBody: true, // 允许 body 延伸到底部导航栏下方
      // 彻底移除原生 AppBar，实现绝对沉浸
      appBar: null,
      // 使用 IndexedStack 保持页面状态，并在最顶层悬浮覆盖无边框窗口控制栏
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          // 悬浮在壁纸最上方的自定义窗口控制栏
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 40,
            child: WindowCaption(
              brightness: Brightness.dark, // 强制按钮图标为纯白色
              backgroundColor: Colors.transparent, // 绝对透明，融入底层流光
            ),
          ),
        ],
      ),
      // 中间的发布按钮 (绝对居中悬浮)
      floatingActionButton: _currentIndex == 1 ? FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          // 跳转到短视频上传入口
          Navigator.push(context, MaterialPageRoute(builder: (context) => const VideoUploadScreen()));
        },
        child: const Icon(Icons.add, color: Colors.black, size: 32),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            BottomNavigationBarItem(icon: Icon(_currentIndex == 0 ? Icons.chat_bubble : Icons.chat_bubble_outline), label: ''),
            BottomNavigationBarItem(icon: Icon(_currentIndex == 1 ? Icons.play_circle : Icons.play_circle_outline), label: ''),
            BottomNavigationBarItem(icon: Icon(_currentIndex == 2 ? Icons.shopping_bag : Icons.shopping_bag_outlined), label: ''),
            BottomNavigationBarItem(icon: Icon(_currentIndex == 3 ? Icons.person : Icons.person_outline), label: ''),
          ],
        ),
      ),
    );
  }
}
