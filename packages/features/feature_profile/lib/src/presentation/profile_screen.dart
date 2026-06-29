import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'current_user_avatar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_media/core_media.dart';
import 'package:core_network/core_network.dart';
import 'package:feature_video/feature_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      canvas.drawCircle(point, radius, starCorePaint); // 亮核
    }
  }

  // 双子座 (Gemini) 的相对坐标点阵 (形似两个火柴人手拉手)
  List<Offset> _getGeminiPoints(Size size) {
    final w = size.width;
    final h = size.height;
    return [
      // 左侧小人 (Castor)
      Offset(w * 0.2, h * 0.1), // 0: 头部
      Offset(w * 0.3, h * 0.3), // 1: 脖子/肩膀
      Offset(w * 0.15, h * 0.4), // 2: 左手
      Offset(w * 0.45, h * 0.35), // 3: 右手 (牵手点)
      Offset(w * 0.25, h * 0.6), // 4: 腰部
      Offset(w * 0.1, h * 0.8), // 5: 左脚
      Offset(w * 0.35, h * 0.85), // 6: 右脚

      // 右侧小人 (Pollux)
      Offset(w * 0.7, h * 0.15), // 7: 头部
      Offset(w * 0.65, h * 0.35), // 8: 脖子/肩膀
      Offset(w * 0.85, h * 0.45), // 9: 右手
      Offset(w * 0.6, h * 0.65), // 10: 腰部
      Offset(w * 0.5, h * 0.9), // 11: 左脚
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

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLoginSuccess;

  const ProfileScreen({super.key, this.onLoginSuccess});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
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
      math.pi, // 扫描角度 (画半圆到顶部)
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
    final angles = [
      math.pi / 2,
      math.pi * 3 / 4,
      math.pi,
      math.pi * 5 / 4,
      math.pi * 3 / 2,
    ];

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

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _showPasswordInput = false;
  bool _obscurePassword = true;
  bool _isSettingsOpen = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  late final PageController _themePageController;
  Timer? _autoScrollTimer;
  bool _isLoggingIn = false;
  List<PlatformVideoRecord> _myVideos = [];
  final Map<String, List<PlatformVideoRecord>> _videosByIdentity = {};
  bool _isLoadingVideos = false;
  String? _lastFetchedIdentityId;
  String? _scheduledIdentityFetchId;
  late final PublishOverlayStore _publishOverlayStore;
  String? _lastHandledPublishJobId;

  void _scheduleIdentityRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(identityControllerProvider.notifier).refresh();
    });
  }

  @override
  void initState() {
    super.initState();
    _publishOverlayStore = PublishOverlayStore.instance;
    _publishOverlayStore.addListener(_handlePublishOverlayChanged);
    _themePageController = PageController(
      viewportFraction: 0.54,
      initialPage:
          _themeIndexOf(BackgroundManager.instance.currentBackground.value),
    );

    if (_checkIsLoggedIn()) {
      _scheduleIdentityRefresh();
    } else {
      _resetIdentityScopedVideos();
    }
  }

  void _resetIdentityScopedVideos() {
    _myVideos = [];
    _videosByIdentity.clear();
    _isLoadingVideos = false;
    _lastFetchedIdentityId = null;
    _scheduledIdentityFetchId = null;
  }

  void _showCachedVideosForIdentity(String authorIdentityId) {
    setState(() {
      _lastFetchedIdentityId = authorIdentityId;
      _myVideos = List<PlatformVideoRecord>.from(
        _videosByIdentity[authorIdentityId] ?? const [],
      );
      _isLoadingVideos = !_videosByIdentity.containsKey(authorIdentityId);
    });
  }

  Future<void> _fetchMyVideos({
    required String authorIdentityId,
    bool showLoadingIndicator = true,
  }) async {
    if (showLoadingIndicator) {
      setState(() {
        _isLoadingVideos = true;
      });
    }
    try {
      final user = SupabaseService.currentUser;
      final authorId = user?.id ?? '';
      if (authorId.isNotEmpty) {
        final videos = await SupabaseService.fetchMyVideos(
          authorId,
          authorIdentityId: authorIdentityId,
        );
        if (mounted) {
          setState(() {
            _videosByIdentity[authorIdentityId] = videos;
            if (_lastFetchedIdentityId == authorIdentityId) {
              _myVideos = videos;
            }
            _lastFetchedIdentityId = authorIdentityId;
            _scheduledIdentityFetchId = null;
          });
        }
      }
    } catch (e) {
      debugPrint('获取我的视频失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVideos = false;
          if (_scheduledIdentityFetchId == authorIdentityId) {
            _scheduledIdentityFetchId = null;
          }
        });
      }
    }
  }

  // 暂时移除未使用的 _startAutoScroll

  @override
  void dispose() {
    _publishOverlayStore.removeListener(_handlePublishOverlayChanged);
    _autoScrollTimer?.cancel();
    _feedScrollController.dispose();
    _themePageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 检查是否已登录 (真实连接 Supabase Auth)
  bool _checkIsLoggedIn() =>
      ref.read(supabaseProvider).auth.currentSession != null;

  void _handlePublishOverlayChanged() {
    if (!mounted) {
      return;
    }
    final state = _publishOverlayStore.state;
    if (state.isActive && state.pendingVideo != null) {
      _upsertProfileVideo(state.pendingVideo!);
    }
    if (state.stage == PublishOverlayStage.completed &&
        state.completedVideo != null &&
        state.jobId != null &&
        state.jobId != _lastHandledPublishJobId) {
      _lastHandledPublishJobId = state.jobId;
      _upsertProfileVideo(state.completedVideo!);
    }
    if (state.stage == PublishOverlayStage.failed && state.pendingVideo != null) {
      _upsertProfileVideo(state.pendingVideo!);
    }
  }

  void _upsertProfileVideo(PendingPublishedVideo publishedVideo) {
    final authorIdentityId = publishedVideo.authorIdentityId;
    final records = List<PlatformVideoRecord>.from(
      _videosByIdentity[authorIdentityId] ?? const [],
    );
    final record = _recordFromPendingPublishedVideo(publishedVideo);
    final existingIndex = records.indexWhere(
      (item) =>
          item.id == record.id ||
          item.videoUrl == record.videoUrl ||
          _extractLocalPublishJobId(item.id) == publishedVideo.jobId,
    );
    if (existingIndex == -1) {
      records.insert(0, record);
    } else {
      records[existingIndex] = record;
    }

    setState(() {
      _videosByIdentity[authorIdentityId] = records;
      if (_lastFetchedIdentityId == authorIdentityId) {
        _myVideos = records;
        _isLoadingVideos = false;
      }
    });
  }

  PlatformVideoRecord _recordFromPendingPublishedVideo(
    PendingPublishedVideo video,
  ) {
    final user = SupabaseService.currentUser;
    final isPending = video.isPending;
    final isFailed = video.isFailed;
    return PlatformVideoRecord(
      id: isPending
          ? 'pending_${video.jobId}'
          : isFailed
              ? 'failed_${video.jobId}'
              : 'published_${video.jobId}',
      authorId: user?.id ?? '',
      authorIdentityId: video.authorIdentityId,
      authorName: video.authorName,
      description: video.description,
      videoUrl: video.fallbackPlaybackUrl ?? video.primaryPlaybackUrl,
      coverUrl: video.coverUrl,
      streamUrl: video.prefersStreaming ? video.primaryPlaybackUrl : '',
      streamFormat: video.prefersStreaming ? 'hls' : '',
      videoObjectKey: '',
      coverObjectKey: null,
      streamObjectPrefix: null,
      contentOrientation: video.contentOrientation,
      aspectRatioLabel:
          video.contentOrientation == 'landscape' ? '16:9' : '9:16',
      workflowStatus: isPending
          ? 'processing'
          : isFailed
              ? 'failed'
              : 'ready',
      moderationStatus: isPending ? 'pending' : 'approved',
      distributionStatus: isPending
          ? 'pending'
          : isFailed
              ? 'offline'
              : 'ready',
      distributionChannel:
          video.contentOrientation == 'landscape'
              ? 'landscape'
              : 'recommendation',
      primaryDistributionKind: video.prefersStreaming ? 'hls' : 'direct_file',
      processingStatus: isPending
          ? 'processing'
          : isFailed
              ? 'failed'
              : 'ready',
      lifecycleStatus: 'active',
      viewCount: 0,
      likeCount: 0,
      commentCount: 0,
      shareCount: 0,
      durationSeconds: 0,
      assetSchemaVersion: 1,
      width: video.width,
      height: video.height,
      createdAt: DateTime.now(),
      publishedAt: isPending ? null : DateTime.now(),
    );
  }

  String? _extractLocalPublishJobId(String id) {
    if (id.startsWith('pending_')) {
      return id.substring('pending_'.length);
    }
    if (id.startsWith('failed_')) {
      return id.substring('failed_'.length);
    }
    if (id.startsWith('published_')) {
      return id.substring('published_'.length);
    }
    return null;
  }

  int _themeIndexOf(BackgroundType type) {
    final index = BackgroundManager.availableThemes.indexWhere(
      (preset) => preset.type == type,
    );
    return index == -1 ? 0 : index;
  }

  void _syncThemeCarousel(BackgroundType currentType) {
    if (!_themePageController.hasClients) return;
    final targetPage = _themeIndexOf(currentType);
    final currentPage = _themePageController.page?.round();
    if (currentPage == targetPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_themePageController.hasClients) return;
      _themePageController.jumpToPage(targetPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _checkIsLoggedIn();
    final identityHub = ref.watch(identityControllerProvider).asData?.value;
    if (isLoggedIn &&
        identityHub != null &&
        _lastFetchedIdentityId != identityHub.activeIdentity.id &&
        _scheduledIdentityFetchId != identityHub.activeIdentity.id) {
      _scheduledIdentityFetchId = identityHub.activeIdentity.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final activeIdentityId = identityHub.activeIdentity.id;
        _showCachedVideosForIdentity(activeIdentityId);
        unawaited(
          _fetchMyVideos(
            authorIdentityId: activeIdentityId,
            showLoadingIndicator:
                !_videosByIdentity.containsKey(activeIdentityId),
          ),
        );
      });
    } else if (!isLoggedIn &&
        (_myVideos.isNotEmpty ||
            _videosByIdentity.isNotEmpty ||
            _lastFetchedIdentityId != null)) {
      _resetIdentityScopedVideos();
    }

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
              child: isLoggedIn
                  ? (identityHub == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : (_isSettingsOpen
                          ? const SizedBox.shrink()
                          : _buildLoggedInProfile(identityHub)))
                  : _buildLoginView(),
            ),
            if (isLoggedIn && _isSettingsOpen) _buildSettingsDrawerOverlay(),
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

          // 底部：输入框或第三方登录区域即时切换
          _showPasswordInput
              ? _buildPasswordSection()
              : _buildEmailAndThirdPartySection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// 已登录状态的“我的页”视图 (无边框悬浮风格)
  Widget _buildLoggedInProfile(IdentityHub identityHub) {
    return Stack(
      children: [
        // 主内容滚动区
        SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // 顶部：左星座 + 中头像 + 右ID
              _buildLoggedInHeader(identityHub),

              const SizedBox(height: 16),
              // 名字与动态
              _buildUserInfo(identityHub),

              const SizedBox(height: 32),
              // 底部瀑布流内容
              _buildContentFeed(),
            ],
          ),
        ),

        // 右上角悬浮设置按钮 (向下偏移，避开窗口控制栏)
        Positioned(
          top: 40, // 增加 top 偏移，避开 40px 高度的 WindowCaption
          right: 16,
          child: IconButton(
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _openSettingsDrawer,
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
            image: isLoggedIn
                ? const DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
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
                      fontWeight: FontWeight.w500,
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
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        // 问候语
        Text(
          isLoggedIn
              ? '晚上好，${SupabaseService.currentUser?.email?.split('@').first ?? ''}！'
              : '欢迎，请登录',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// 登录后的顶部 Header：左侧星座、居中头像、右侧生活ID
  Widget _buildLoggedInHeader(IdentityHub identityHub) {
    final avatarUrl = resolveCurrentUserAvatarUrl(
      sharedAvatarUrl: identityHub.profile.avatarUrl,
    );
    final activeIdentity = identityHub.activeIdentity;
    final nextIdentity = _nextEnabledIdentity(identityHub);

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
                  Text(
                    identityHub.profile.zodiacSign,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 居中：带星图半边框的大头像
          GestureDetector(
            onTap: _pickAndUpdateAvatar,
            child: SizedBox(
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
                      image: DecorationImage(
                        image: NetworkImage(avatarUrl),
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
          ),

          // 右侧：单标签身份切换 + 独立 ID
          Expanded(
            child: Center(
              child: MouseRegion(
                cursor: nextIdentity != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: nextIdentity == null
                      ? null
                      : () => _switchIdentity(nextIdentity),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          key: ValueKey(activeIdentity.id),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              activeIdentity.kind.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2.2,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'ID: ${activeIdentity.publicId}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w300,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        if (nextIdentity != null) ...[
                          const SizedBox(width: 8),
                          Transform.translate(
                            offset: const Offset(0, -9),
                            child: Icon(
                              Icons.sync_rounded,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.42),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpdateAvatar() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      if (!mounted) return;
      // 调用 core_media 极致压缩
      final compressedFile = await ImageProcessor.cropAndCompress(
        sourcePath: pickedFile.path,
        context: context,
        maxLongSide: 500, // 头像不需要太大
      );

      if (compressedFile == null) return;

      // 上传到 Supabase Storage
      final user = SupabaseService.currentUser;
      if (user == null) return;

      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.webp';
      final fileBytes = await compressedFile.readAsBytes();
      final avatarChecksum = SupabaseService.computeSha256Hex(fileBytes);
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) return;

      final reusableAvatar = await SupabaseService.findReusableUploadedMedia(
        mediaKind: 'avatar',
        checksumSha256: avatarChecksum,
      );
      final avatarUpload =
          reusableAvatar ??
          await (() async {
            final avatarUploadSession =
                await SupabaseService.issueUploadSession(
                  mediaKind: 'avatar',
                  sourceFilename: fileName,
                  contentType: 'image/webp',
                  fileSizeBytes: fileBytes.length,
                  idempotencyKey: 'avatar_${user.id}_$avatarChecksum',
                  preferredObjectPrefix: 'avatar_${user.id}',
                  uploadPurpose: 'shared_avatar',
                  checksumSha256: avatarChecksum,
                  uploadMetadata: {
                    'surface': 'profile',
                  },
                );
            return SupabaseService.uploadMedia(
              fileName: fileName,
              fileBytes: fileBytes,
              mediaKind: 'avatar',
              accessToken: session.accessToken,
              contentType: 'image/webp',
              objectPrefix: avatarUploadSession.objectPrefix,
              uploadSessionId: avatarUploadSession.id,
            );
          })();

      await ref
          .read(identityControllerProvider.notifier)
          .updateSharedAvatar(avatarUpload.publicUrl);
      await SupabaseService.consumeUploadSessions([
        avatarUpload.uploadSessionId,
      ]);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('头像更新失败: $e')));
      }
    }
  }

  /// 登录后的名字与个性签名
  Widget _buildUserInfo(IdentityHub identityHub) {
    final activeIdentity = identityHub.activeIdentity;
    return Column(
      children: [
        // 名字
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              activeIdentity.displayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _updateDisplayName(activeIdentity),
              child: Icon(
                Icons.history_edu,
                color: Colors.white.withValues(alpha: 0.8),
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 个性签名（生活动态）
        Text(
          identityHub.profile.sharedStatus,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Future<void> _switchIdentity(UserIdentityRecord identity) async {
    _showCachedVideosForIdentity(identity.id);
    try {
      await ref
          .read(identityControllerProvider.notifier)
          .switchActiveIdentity(identity.id);
      if (!mounted) return;
      unawaited(
        _fetchMyVideos(
          authorIdentityId: identity.id,
          showLoadingIndicator: !_videosByIdentity.containsKey(identity.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('身份切换失败: $e')));
      }
    }
  }

  UserIdentityRecord? _nextEnabledIdentity(IdentityHub identityHub) {
    final enabledIdentities =
        identityHub.identities.where((identity) => identity.isEnabled).toList();
    if (enabledIdentities.length < 2) {
      return null;
    }

    final activeIndex = enabledIdentities.indexWhere(
      (identity) => identity.id == identityHub.activeIdentity.id,
    );
    if (activeIndex == -1) {
      return enabledIdentities.first;
    }

    return enabledIdentities[(activeIndex + 1) % enabledIdentities.length];
  }

  Future<void> _updateDisplayName(UserIdentityRecord identity) async {
    final TextEditingController nameController = TextEditingController();
    final result = await context.showInstantDialog<String>(
      barrierDismissible: true,
      barrierLabel: 'edit-identity-name',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            '修改${identity.kind.label}名称',
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '请输入新的${identity.kind.label}名称',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, nameController.text),
              child: const Text('保存', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await ref
            .read(identityControllerProvider.notifier)
            .updateIdentityDisplayName(
              identityId: identity.id,
              displayName: result.trim(),
            );
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('更新失败: $e')));
        }
      }
    }
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
      final identityLabel =
          ref.watch(activeIdentityProvider)?.kind.label ?? '当前身份';
      return SizedBox(
        height: 240,
        child: Center(
          child: Text(
            '$identityLabel 暂无发布内容\n点击底部 "+" 号发布第一条短视频吧',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
              fontWeight: FontWeight.w300,
            ),
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
          final localPublishJobId = _extractLocalPublishJobId(video.id);
          final isFailedVideo = video.statusLabel == '处理失败';
          return GestureDetector(
            onTap: isFailedVideo
                ? null
                : () => context.pushImmersive<void>(
                    builder: (context) => ImmersiveVideoGalleryScreen(
                      videos: _myVideos,
                      initialIndex: index,
                      title: '我的作品',
                    ),
                  ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 2), // 极窄边距
              color: Colors.white.withValues(alpha: 0.05),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (video.coverUrl.isNotEmpty)
                    Image.network(
                      video.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildProfileVideoPlaceholder(),
                    )
                  else
                    _buildProfileVideoPlaceholder(),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildVideoMetaBadge(video.statusLabel),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildVideoMetaBadge(video.primaryDistributionLabel),
                  ),
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
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 28,
                    left: 8,
                    right: 8,
                    child: Text(
                      video.description,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: _buildVideoMetaBadge(video.distributionChannelLabel),
                  ),
                  if (isFailedVideo && localPublishJobId != null)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '发布失败',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _publishOverlayStore.retryFailedPublish(
                                localPublishJobId,
                              ),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '重试发布',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSettingsDrawer() {
    setState(() {
      _isSettingsOpen = true;
    });
  }

  void _closeSettingsDrawer() {
    setState(() {
      _isSettingsOpen = false;
    });
  }

  Widget _buildVideoMetaBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProfileVideoPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.video_library_outlined,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildSettingsDrawerOverlay() {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeSettingsDrawer,
              child: const SizedBox.expand(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(
                top: 28,
                right: 20,
                bottom: 28,
              ),
              child: SizedBox(
                width: 300,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: CurrentUserAvatar(
                                size: 52,
                                onTap: _pickAndUpdateAvatar,
                                fallbackIconSize: 24,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _closeSettingsDrawer,
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildThemeSelector(),
                    const SizedBox(height: 28),
                    _buildSettingsItem('账号安全', Icons.security),
                    _buildSettingsItem('更改邮箱', Icons.email_outlined),
                    _buildSettingsItem('项目记忆桥接', Icons.memory_outlined),
                    const Spacer(),
                    _buildSettingsItem(
                      '退出账号',
                      Icons.logout,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    _buildSettingsItem(
                      '注销账号',
                      Icons.delete_forever,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return ValueListenableBuilder<BackgroundType>(
      valueListenable: BackgroundManager.instance.currentBackground,
      builder: (context, currentType, _) {
        _syncThemeCarousel(currentType);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                '背景主题',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 126,
              child: PageView.builder(
                controller: _themePageController,
                padEnds: true,
                itemCount: BackgroundManager.availableThemes.length,
                onPageChanged: (index) {
                  final preset = BackgroundManager.availableThemes[index];
                  BackgroundManager.instance.setBackground(preset.type);
                },
                itemBuilder: (context, index) {
                  final preset = BackgroundManager.availableThemes[index];
                  return _buildThemePreviewCard(
                    index: index,
                    preset: preset,
                    isSelected: preset.type == currentType,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemePreviewCard({
    required int index,
    required BackgroundThemePreset preset,
    required bool isSelected,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: isSelected ? 0 : 10,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _themePageController.jumpToPage(index);
          BackgroundManager.instance.setBackground(preset.type);
        },
        child: Transform.scale(
          scale: isSelected ? 1.0 : 0.88,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackgroundThemePreview(backgroundType: preset.type),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Text(
                        preset.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSelected ? 17 : 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    String title,
    IconData icon, {
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      onTap: () async {
        _closeSettingsDrawer();
        if (title == '项目记忆桥接') {
          if (!mounted) return;
          context.push('/memory-bridge');
          return;
        }
        // 如果是退出，调用真实的退出逻辑
        if (title == '退出账号') {
          // @AI_CONTEXT: [2026-06-26] 使用 fpdart 的 fold 来处理退出登录的返回结果
          final result = await ref.read(authRepositoryProvider).signOut().run();
          result.fold(
            (failure) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failure.message)),
                );
              }
            },
            (_) {
              // 登出成功，UI 会通过 _authSubscription 自动重绘，这里不需要额外操作
            },
          );
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
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: Colors.black,
                    size: 20,
                  ),
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
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.1)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '或使用以下方式',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            Expanded(
              child: Divider(color: Colors.white.withValues(alpha: 0.1)),
            ),
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
        // 邮箱和更改图标一行显示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _emailController.text,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPasswordInput = false; // 返回修改邮箱
                });
              },
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.white54,
                size: 18,
              ),
            ),
          ],
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
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '请输入密码',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              // 小眼睛图标
              IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              // 登录按钮
              _isLoggingIn
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.black,
                          size: 20,
                        ),
                        onPressed: _performLoginOrRegister,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  /// 执行注册逻辑
  Future<void> _performSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoggingIn = true;
    });

    // @AI_CONTEXT: [2026-06-26] 彻底摒弃 try-catch，使用 Riverpod 注入的 AuthRepository 与 TaskEither 进行纯函数式处理
    final result = await ref
        .read(authRepositoryProvider)
        .signUpWithEmailPassword(
          email: email,
          password: password,
        )
        .run();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoggingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (authResponse) {
        setState(() => _isLoggingIn = false);
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      },
    );
  }

  Future<void> _performLoginOrRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    setState(() {
      _isLoggingIn = true;
    });

    // @AI_CONTEXT: [2026-06-26] 彻底摒弃 try-catch，使用 Riverpod + fpdart 进行安全处理
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmailPassword(
          email: email,
          password: password,
        )
        .run();

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() => _isLoggingIn = false);
        // 如果错误提示是未注册（这里可以更优雅地通过错误码判断，为演示简写）
        if (failure.message.contains('Invalid login credentials')) {
          _performSignUp();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (authResponse) {
        setState(() => _isLoggingIn = false);
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      },
    );
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
