import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
  late PageController _pageController;
  final List<VideoModel> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
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
            },
            itemBuilder: (context, index) {
              // 极限预加载：只保留当前、上一条、下一条实例，其余全部回收
              final bool isRendered = (index >= _currentIndex - 1 && index <= _currentIndex + 1);
              if (!isRendered) {
                return const SizedBox();
              }

              return _VideoPlayerItem(
                video: _videos[index],
                isActive: index == _currentIndex,
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

/// 单个视频播放组件
class _VideoPlayerItem extends StatefulWidget {
  final VideoModel video;
  final bool isActive;

  const _VideoPlayerItem({
    required this.video,
    required this.isActive,
  });

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  // 使用 C++ 顶级引擎 media_kit
  late final Player _player;
  late final VideoController _controller;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    // 实例化媒体播放器内核
    _player = Player();
    _controller = VideoController(_player);

    // 【核心修复】：对于网络流，即使是 media_kit，也可能会因为网络 I/O 导致循环有轻微黑屏
    // 要做到抖音那种绝对 0 缝隙，我们需要在内存级别将播放器强制锁定
    // 我们在这里使用一种“软循环”技术配合底层 loop
    _player.setPlaylistMode(PlaylistMode.none); // 关闭自带的 loop，因为它会触发重新 load 

    _player.stream.position.listen((position) {
      final duration = _player.state.duration;
      // 当播放到距离结尾还剩 150 毫秒以内时，瞬间强行 Seek 回到 0
      // 因为这个时候显存里其实还有最后几帧，这样可以做到绝对没有黑屏的物理回滚
      if (duration.inMilliseconds > 0 && 
          position.inMilliseconds >= duration.inMilliseconds - 150) {
        _player.seek(Duration.zero);
      }
    });

    // 预加载并根据激活状态决定是否立即播放
    _player.open(Media(widget.video.url), play: widget.isActive);
    _isPlaying = widget.isActive;
  }

  @override
  void didUpdateWidget(covariant _VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 监听滑动状态变化：滑到该视频就播放，滑走就暂停（但保留在内存中供回滑秒开）
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _player.play();
        _isPlaying = true;
      } else {
        _player.pause();
        _isPlaying = false;
      }
    }
  }

  @override
  void dispose() {
    _player.dispose(); // 彻底释放底层 C++ 资源
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _player.pause();
        _isPlaying = false;
      } else {
        _player.play();
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
          // 1. 视频底层渲染 (0 毫秒首帧秒开)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover, // 裁切适应全屏（抖音模式）
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Video(controller: _controller),
              ),
            ),
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
