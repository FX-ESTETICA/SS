import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win_plugin.dart'; // 添加这行
import 'dart:io';

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
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late ScrollController _pageController;
  final List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 如果是 Windows 桌面端，显式注册播放器插件以防崩溃
    if (Platform.isWindows) {
      WindowsVideoPlayer.registerWith();
    }
    _pageController = ScrollController();
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
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 视频流页面强制黑色背景
      body: _buildBody(),
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
            )
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
          child: ListView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical, // 上下滑动
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                child: _VideoPlayerItem(video: _videos[index]),
              );
            },
          ),
        ),

        // 顶部容错提示条
        if (_errorMessage != null)
          Positioned(
            top: 40,
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

/// 单个视频播放组件
class _VideoPlayerItem extends StatefulWidget {
  final VideoModel video;

  const _VideoPlayerItem({required this.video});

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    // 初始化视频控制器
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.url))
      ..initialize().then((_) {
        // 确保第一帧加载完成后重建状态
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _isPlaying = false;
      } else {
        _controller.play();
        _isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay, // 点击屏幕暂停/播放
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 视频底层渲染
          _controller.value.isInitialized
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover, // 裁切适应全屏（抖音模式）
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),

          // 2. 暂停图标蒙层
          if (!_isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, size: 80, color: Colors.white54),
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
                  widget.video.authorName,
                  style: AppTypography.h1.copyWith(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
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
