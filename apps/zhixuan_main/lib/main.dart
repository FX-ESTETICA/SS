import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_video/feature_video.dart';
import 'package:feature_shop/feature_shop.dart';
import 'package:feature_im/feature_im.dart';

void main() async {
  // 确保 Flutter 引擎完全绑定，这是初始化云端服务的前提
  WidgetsFlutterBinding.ensureInitialized();

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
      _buildPlaceholder('个人中心尚未挂载'),
    ];

    return Scaffold(
      // 短视频页面不需要 AppBar，如果是视频页则隐藏 AppBar
      appBar: _currentIndex == 1 
          ? null 
          : AppBar(title: const Text('智选', style: AppTypography.h1)),
      // 使用 IndexedStack 保持页面状态（比如刷视频切到消息，切回来视频还在继续播）
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        // 抖音模式下，底部导航栏背景为黑色
        backgroundColor: _currentIndex == 1 ? Colors.black : AppColors.surface,
        selectedItemColor: _currentIndex == 1 ? Colors.white : AppColors.primary,
        unselectedItemColor: _currentIndex == 1 ? Colors.white54 : AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: '消息 (IM)'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_outline), label: '短视频'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), label: '商城'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '我的'),
        ],
      ),
    );
  }

  // 临时占位页面
  Widget _buildPlaceholder(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(text, style: AppTypography.body),
        ],
      ),
    );
  }
}
