import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/video_engine_pool.dart'; // 引入底层引擎池

/// 模拟从后端拉取的短视频数据模型
class VideoModel {
  final String url;
  final String authorName;
  final String description;

  VideoModel({required this.url, required this.authorName, required this.description});

  // 从云端 JSON 数据解析的工厂方法
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      url: json['video_url'] ?? '',
      authorName: json['author_name'] ?? '@未知作者',
      description: json['description'] ?? '',
    );
  }
}

/// 抖音风格短视频瀑布流主页面
class VideoFeedScreen extends StatefulWidget {
  final bool isTabActive;
  const VideoFeedScreen({super.key, this.isTabActive = true});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late PageController _pageController;
  final List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // 1. 初始化 C++ 引擎池
    VideoEnginePool.instance.initialize();
    
    _pageController = PageController();
    _fetchVideosFromCloud();
  }

  Future<void> _fetchVideosFromCloud() async {
    try {
      final data = await SupabaseService.instance.fetchVideos();
      if (mounted) {
        setState(() {
          _videos.addAll(data.map((e) => VideoModel.fromJson(e)).toList());
          _isLoading = false;
        });
        // 数据到达后，将焦点锁定到索引 0，开始底层预加载
        VideoEnginePool.instance.focusIndex(0, _videos.map((e) => e.url).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '云端连接失败，已切换至离线缓存模式';
          _videos.addAll([
            VideoModel(
              url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
              authorName: '@智选官方 (离线)',
              description: '极致丝滑！智选超级 APP 首次点火测试 🔥 #Flutter #Tech',
            ),
            VideoModel(
              url: 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
              authorName: '@自然探索 (离线)',
              description: '大自然的美丽瞬间 🌸',
            ),
          ]);
          _isLoading = false;
        });
        VideoEnginePool.instance.focusIndex(0, _videos.map((e) => e.url).toList());
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 Tab 切换导致非激活，强制冻结所有 C++ 解码
    if (oldWidget.isTabActive != widget.isTabActive) {
      if (widget.isTabActive) {
        VideoEnginePool.instance.focusIndex(_currentIndex, _videos.map((e) => e.url).toList());
      } else {
        VideoEnginePool.instance.freezeAll();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    VideoEnginePool.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 必须透明以露出全局流光
      extendBodyBehindAppBar: true,
      body: AnimatedSpatialBackground(
        child: _buildBody(), // 主体内容
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _videos.clear();
                _fetchVideosFromCloud();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('点击重试 (刷新)', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // 核心降维打击：使用 PageView.builder 实现极致复用的全屏滚动
        RefreshIndicator(
          onRefresh: () async {
            setState(() => _isLoading = true);
            _videos.clear();
            await _fetchVideosFromCloud();
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical, // 上下滑动
            itemCount: _videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              // 将滑动焦点事件抛给底层 C++ 引擎池进行物理指针偏移
              if (widget.isTabActive) {
                VideoEnginePool.instance.focusIndex(index, _videos.map((e) => e.url).toList());
              }
            },
            itemBuilder: (context, index) {
              // 极限预加载：只渲染当前和前后 1 个
              final bool isRendered = (index >= _currentIndex - 1 && index <= _currentIndex + 1);
              if (!isRendered) {
                return const SizedBox();
              }

              return _VideoPlayerItem(
                video: _videos[index],
                index: index, // 传入实际索引
                isActive: index == _currentIndex && widget.isTabActive,
              );
            },
          ),
        ),

        // 顶部容错提示条
        if (_errorMessage != null)
          Positioned(
            top: 40, // 已经在 40，刚好避开 WindowCaption
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.error.withValues(alpha: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

/// 极简无状态视频播放组件 (彻底接管自底层池)
class _VideoPlayerItem extends StatelessWidget {
  final VideoModel video;
  final int index;
  final bool isActive;

  const _VideoPlayerItem({
    required this.video,
    required this.index,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    // 物理级映射：根据真实 index 获取底层被分配的 3 个常驻 C++ 引擎之一
    final controller = VideoEnginePool.instance.getController(index);
    final player = VideoEnginePool.instance.getPlayer(index);

    return GestureDetector(
      onTap: () => VideoEnginePool.instance.togglePlay(index), // 点击屏幕暂停/播放
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 视频底层渲染 (Zero-copy 直出)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover, // 裁切适应全屏（抖音模式）
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Video(controller: controller),
              ),
            ),
          ),

          // 2. 暂停图标蒙层 (通过 StreamBuilder 监听底层状态，不再需要 setState)
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              if (isPlaying || !isActive) return const SizedBox();
              return const Center(
                child: Icon(Icons.play_arrow, size: 80, color: Colors.white),
              );
            },
          ),

          // 3. 底部信息层 (作者、文案)
          Positioned(
            bottom: 20,
            left: 16,
            right: 80, // 给右侧的点赞按钮留出空间
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.authorName,
                  style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  video.description,
                  style: AppTypography.body.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 4. 右侧操作区 (点赞、评论、分享)
          Positioned(
            bottom: 20,
            right: 8,
            child: Column(
              children: [
                _buildActionIcon(Icons.favorite_border, '8.6w'),
                const SizedBox(height: 20),
                _buildActionIcon(Icons.comment_outlined, '1024'),
                const SizedBox(height: 20),
                _buildActionIcon(Icons.share_outlined, '分享'),
                const SizedBox(height: 20),
                // 模拟旋转的光盘头像
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.grey[800],
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
