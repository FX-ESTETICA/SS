import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';

import 'package:core_network/core_network.dart';

/// 真正的十二星座几何连线图绘制器 (Constellation Art)
class ZodiacConstellationPainter extends CustomPainter {
  final String sign;

  ZodiacConstellationPainter({required this.sign});

  @override
  void paint(Canvas canvas, Size size) {
    // 根据星座获取相对坐标点阵 (0.0 到 1.0) 和连线逻辑
    // 这里以双子座 (Gemini) 的经典连线为例，形似两个并排的火柴人
    final List<Offset> points = _getGeminiPoints(size);
    final List<List<int>> connections = _getGeminiConnections();

    // 1. 画极细的半透明连线
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (var connection in connections) {
      final start = points[connection[0]];
      final end = points[connection[1]];
      canvas.drawLine(start, end, linePaint);
    }

    // 2. 画发光的星星节点
    final starGlowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0); // 外围光晕

    final starCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      // 随机给几颗主星更大的尺寸和光晕
      final bool isMajorStar = i == 0 || i == 4 || i == 7 || i == 11;
      final double radius = isMajorStar ? 2.5 : 1.5;

      canvas.drawCircle(point, radius + 2, starGlowPaint); // 光晕
      canvas.drawCircle(point, radius, starCorePaint);     // 亮核
    }
  }

  // 双子座 (Gemini) 的相对坐标点阵 (形似两个火柴人手拉手)
  List<Offset> _getGeminiPoints(Size size) {
    final w = size.width;
    final h = size.height;
    return [
      // 左侧小人 (Castor)
      Offset(w * 0.2, h * 0.1),  // 0: 头部
      Offset(w * 0.3, h * 0.3),  // 1: 脖子/肩膀
      Offset(w * 0.15, h * 0.4), // 2: 左手
      Offset(w * 0.45, h * 0.35),// 3: 右手 (牵手点)
      Offset(w * 0.25, h * 0.6), // 4: 腰部
      Offset(w * 0.1, h * 0.8),  // 5: 左脚
      Offset(w * 0.35, h * 0.85),// 6: 右脚

      // 右侧小人 (Pollux)
      Offset(w * 0.7, h * 0.15), // 7: 头部
      Offset(w * 0.65, h * 0.35),// 8: 脖子/肩膀
      Offset(w * 0.85, h * 0.45),// 9: 右手
      Offset(w * 0.6, h * 0.65), // 10: 腰部
      Offset(w * 0.5, h * 0.9),  // 11: 左脚
      Offset(w * 0.8, h * 0.85), // 12: 右脚
    ];
  }

  // 定义哪些点之间需要连线 (索引对应上面的 List)
  List<List<int>> _getGeminiConnections() {
    return [
      // 左侧小人连线
      [0, 1], [1, 2], [1, 3], [1, 4], [4, 5], [4, 6],
      // 右侧小人连线
      [7, 8], [8, 3], [8, 9], [8, 10], [10, 11], [10, 12],
      // 两人牵手连线
      [3, 8], 
    ];
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const ProfileScreen({super.key, this.onLoginSuccess});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// 绘制头像外围的极光半边框与星图连线
class ConstellationBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. 恢复左侧的半弧形蓝紫色渐变光晕边框
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Colors.purpleAccent, Colors.blueAccent, Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi / 2, // 起始角度 (底部)
      math.pi,     // 扫描角度 (画半圆到顶部)
      false,
      arcPaint,
    );

    // 2. 绘制星图节点 (星星) 与连线 (保留纯白发光点)
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2); // 发光效果
      
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 计算几个星星的坐标 (分布在左半圆弧上)
    final List<Offset> stars = [];
    final angles = [math.pi / 2, math.pi * 3 / 4, math.pi, math.pi * 5 / 4, math.pi * 3 / 2];
    
    for (var angle in angles) {
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      stars.add(Offset(x, y));
    }

    // 画连线
    for (int i = 0; i < stars.length - 1; i++) {
      canvas.drawLine(stars[i], stars[i + 1], linePaint);
    }

    // 画星星节点
    for (var star in stars) {
      canvas.drawCircle(star, 3.0, starPaint);
      // 内部亮核
      canvas.drawCircle(star, 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _showPasswordInput = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  Timer? _autoScrollTimer;
  StreamSubscription? _authSubscription;
  bool _isLoggingIn = false;
  List<Map<String, dynamic>> _myVideos = [];
  bool _isLoadingVideos = false;

  @override
  void initState() {
    super.initState();
    
    // 监听全局登录状态变化
    _authSubscription = SupabaseService.instance.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {}); // 刷新 UI
        if (_checkIsLoggedIn()) {
          _fetchMyVideos();
        }
      }
    });

    if (_checkIsLoggedIn()) {
      _fetchMyVideos();
    }
  }

  Future<void> _fetchMyVideos() async {
    setState(() {
      _isLoadingVideos = true;
    });
    try {
      final user = SupabaseService.instance.currentUser;
      final authorName = user?.email?.split('@').first ?? '';
      if (authorName.isNotEmpty) {
        final videos = await SupabaseService.instance.fetchMyVideos(authorName);
        if (mounted) {
          setState(() {
            _myVideos = videos;
          });
        }
      }
    } catch (e) {
      debugPrint('获取我的视频失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
        });
      }
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_feedScrollController.hasClients) {
        final maxScroll = _feedScrollController.position.maxScrollExtent;
        final currentScroll = _feedScrollController.offset;
        if (currentScroll < maxScroll) {
          _feedScrollController.jumpTo(currentScroll + 1.0); // 极度平滑的偏移
        } else {
          _feedScrollController.jumpTo(0); // 触底回滚
        }
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _feedScrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  // 检查是否已登录 (真实连接 Supabase Auth)
  bool _checkIsLoggedIn() => SupabaseService.instance.currentSession != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 必须透明以露出全局流光
      body: AnimatedSpatialBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 背景层：图片 + 毛玻璃虚化效果
            _buildBackground(),

            // 2. 内容层
            SafeArea(
              child: _checkIsLoggedIn() ? _buildLoggedInProfile() : _buildLoginView(),
            ),
          ],
        ),
      ),
    );
  }

  /// 未登录状态的视图
  Widget _buildLoginView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 60),
          // 顶部：头像、日期、问候语
          _buildHeaderInfo(isLoggedIn: false),
          
          const Spacer(), 
          
          // 底部：输入框或第三方登录区域的动态切换
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showPasswordInput ? _buildPasswordSection() : _buildEmailAndThirdPartySection(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 已登录状态的“我的页”视图 (无边框悬浮风格)
  Widget _buildLoggedInProfile() {
    return Stack(
      children: [
        // 主内容滚动区
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // 顶部：左星座 + 中头像 + 右ID
              _buildLoggedInHeader(),
              
              const SizedBox(height: 16),
              // 名字与动态
              _buildUserInfo(),
              
              const SizedBox(height: 32),
              // 底部瀑布流内容
              _buildContentFeed(),
            ],
          ),
        ),

        // 右上角悬浮设置按钮
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
            onPressed: _showSettingsSheet,
          ),
        ),
      ],
    );
  }

  /// 背景层 (修改为完全透明，因为底层已经有流光了)
  Widget _buildBackground() {
    return const SizedBox(); // 彻底移除原有的星座图蒙版和纯黑背景
  }

  Widget _buildHeaderInfo({required bool isLoggedIn}) {
    final now = DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${now.month}月${now.day}日';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black, // 未登录状态的纯黑背景
            image: isLoggedIn ? const DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80'), 
              fit: BoxFit.cover,
            ) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: !isLoggedIn 
            ? const Center(
                child: Text(
                  'SS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              )
            : null,
        ),
        const SizedBox(height: 24),
        // 日期
        Text(
          dateStr,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // 问候语
        Text(
          isLoggedIn ? '晚上好，${SupabaseService.instance.currentUser?.email?.split('@').first ?? ''}！' : '欢迎，请登录',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// 登录后的顶部 Header：左侧星座、居中头像、右侧生活ID
  Widget _buildLoggedInHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // 左侧：极具视觉冲击力的大尺寸无色星图（镶嵌感）
          Expanded(
            child: Center(
              child: Column(
                children: [
                  SizedBox(
                    width: 70,
                    height: 70,
                    // 完全使用纯代码手工绘制星图连线，彻底抛弃图片
                    child: CustomPaint(
                      painter: ZodiacConstellationPainter(sign: 'gemini'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('双子座', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, letterSpacing: 2)),
                ],
              ),
            ),
          ),
          
          // 居中：带星图半边框的大头像
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: ConstellationBorderPainter(),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80'),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // 右侧：生活 ID（居中于右半边）
          Expanded(
            child: Center(
              child: Column(
                children: [
                  const Text('生活', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('ID: 8848', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 登录后的名字与个性签名
  Widget _buildUserInfo() {
    final user = SupabaseService.instance.currentUser;
    final userName = user?.email?.split('@').first ?? '匿名极客';
    
    return Column(
      children: [
        // 名字
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, color: Colors.white.withValues(alpha: 0.4), size: 18),
          ],
        ),
        const SizedBox(height: 12),
        // 个性签名（生活动态）
        const Text(
          '“今天又是充满代码的一天...”',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// 底部内容流（展示用户发布的视频）
  Widget _buildContentFeed() {
    if (_isLoadingVideos) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_myVideos.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text('暂无发布动态\n点击底部 "+" 号发布第一条短视频吧', 
            textAlign: TextAlign.center, 
            style: TextStyle(color: Colors.white54, height: 1.5)
          ),
        ),
      );
    }

    return SizedBox(
      height: 240, // 横向滑动内容的高度
      child: ListView.builder(
        controller: _feedScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _myVideos.length, 
        itemBuilder: (context, index) {
          final video = _myVideos[index];
          // 如果没有专门的封面图，我们就用视频链接假装一下（在真实业务中需要展示封面）
          // 由于我们已经有了视频，这里可以使用视频组件或封面组件
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 2), // 极窄边距
            color: Colors.white.withValues(alpha: 0.05),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 暂时用占位符展示，因为我们的极速压缩只上传了视频文件，在云端还没有配专门的图片字段，或者你可以用 R2 里的占位图
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.video_library_outlined, color: Colors.white24, size: 48),
                  ),
                ),
                // 底部信息遮罩
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      ),
                    ),
                  ),
                ),
                // 描述信息
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    video['description'] ?? '', 
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 弹出右侧抽屉式的设置面板
  void _showSettingsSheet() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭设置',
      barrierColor: Colors.transparent, // 移除左侧黑色遮罩，让其完全透明
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight, // 靠右对齐
          child: Material(
            color: Colors.transparent, // 材质背景透明
            child: Container(
              width: 280, // 抽屉宽度
              decoration: const BoxDecoration(
                color: Colors.transparent, // 彻底移除黑色背景
                // border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.1))), // 移除左侧细线，更纯粹
              ),
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Text('设置', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 16),
                  
                  // 背景主题切换功能
                  _buildThemeSelector(),
                  
                  const Divider(color: Colors.white10, height: 32),
                  _buildSettingsItem('账号安全', Icons.security),
                  _buildSettingsItem('更改邮箱', Icons.email_outlined),
                  const Spacer(),
                  const Divider(color: Colors.white10, height: 32),
                  _buildSettingsItem('退出账号', Icons.logout, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  _buildSettingsItem('注销账号', Icons.delete_forever, color: Colors.white38),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), // 从右向左滑入
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildThemeSelector() {
    return ValueListenableBuilder<BackgroundType>(
      valueListenable: BackgroundManager.instance.currentBackground,
      builder: (context, currentType, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text('背景主题', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            _buildThemeOption('极简纯黑', BackgroundType.pureBlack, currentType),
            _buildThemeOption('动态流光', BackgroundType.dynamicAurora, currentType),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption(String title, BackgroundType type, BackgroundType currentType) {
    final isSelected = currentType == type;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? Colors.white : Colors.white54,
      ),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 16)),
      onTap: () {
        BackgroundManager.instance.setBackground(type);
      },
    );
  }

  Widget _buildSettingsItem(String title, IconData icon, {Color color = Colors.white}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      onTap: () async {
        Navigator.pop(context);
        // 如果是退出，调用真实的退出逻辑
        if (title == '退出账号') {
          await SupabaseService.instance.signOut();
        }
      },
    );
  }

  /// 邮箱输入框 + 第三方登录入口（第一步显示）
  Widget _buildEmailAndThirdPartySection() {
    return Column(
      key: const ValueKey('EmailSection'),
      children: [
        // 邮箱输入框
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 6),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '输入邮箱地址获取验证码',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              // 发送箭头按钮
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                  onPressed: () {
                    if (_emailController.text.isNotEmpty) {
                      setState(() {
                        _showPasswordInput = true; // 切换到密码视图
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // 分割线
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('或使用以下方式', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          ],
        ),
        const SizedBox(height: 24),
        
        // 第三方登录按钮（小型化处理，只显示图标和简短名字）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSmallButton(Icons.language, '谷歌'),
            _buildSmallButton(Icons.apple, '苹果'),
            _buildSmallButton(Icons.chat_bubble_outline, 'WhatsApp'),
            _buildSmallButton(Icons.wechat, '微信'),
          ],
        ),
      ],
    );
  }

  /// 密码输入与登录/注册操作
  Widget _buildPasswordSection() {
    return Column(
      key: const ValueKey('PasswordSection'),
      children: [
        Text(
          '欢迎回来\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        // 密码输入框
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 6),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '请输入密码',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              // 登录按钮
              _isLoggingIn 
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                      onPressed: _performLoginOrRegister,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            setState(() {
              _showPasswordInput = false; // 返回修改邮箱
            });
          },
          child: const Text('修改邮箱地址', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  Future<void> _performLoginOrRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() { _isLoggingIn = true; });

    try {
      // 尝试登录
      await SupabaseService.instance.signInWithEmailPassword(email, password);
      if (mounted && widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      }
    } catch (e) {
      // 如果登录失败，尝试直接作为新用户注册
      try {
        await SupabaseService.instance.signUpWithEmailPassword(email, password);
        if (mounted && widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      } catch (signUpError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('登录/注册失败: ${signUpError.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() { _isLoggingIn = false; });
      }
    }
  }

  /// 小型化第三方按钮
  Widget _buildSmallButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}