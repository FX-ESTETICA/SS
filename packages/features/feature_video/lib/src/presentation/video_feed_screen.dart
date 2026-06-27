import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/video_engine_pool.dart'; // 引入底层引擎池
import 'video_upload_screen.dart'; // 引入上传页面

/// 模拟从后端拉取的短视频数据模型
class VideoModel {
  final String url;
  final String authorName;
  final String description;

  VideoModel({
    required this.url,
    required this.authorName,
    required this.description,
  });

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
  bool _isPaging = false; // 翻页状态锁

  @override
  void initState() {
    super.initState();
    // 1. 初始化 C++ 引擎池
    VideoEnginePool.instance.initialize();

    _pageController = PageController();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    try {
      final data = await SupabaseService.fetchVideos();
      if (mounted) {
        setState(() {
          _videos.addAll(data.map((e) => VideoModel.fromJson(e)).toList());
          _isLoading = false;
        });
        // 数据到达后，将焦点锁定到索引 0，开始底层预加载
        VideoEnginePool.instance
            .focusIndex(0, _videos.map((e) => e.url).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '云端连接失败，已切换至离线缓存模式';
          _videos.addAll([
            VideoModel(
              url:
                  'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
              authorName: '@智选官方 (离线)',
              description: '极致丝滑！智选超级 APP 首次点火测试 🔥 #Flutter #Tech',
            ),
            VideoModel(
              url:
                  'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
              authorName: '@自然探索 (离线)',
              description: '大自然的美丽瞬间 🌸',
            ),
          ]);
          _isLoading = false;
        });
        VideoEnginePool.instance
            .focusIndex(0, _videos.map((e) => e.url).toList());
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // @AI_CONTEXT: [生命周期解耦] 监听外层 Tab 切换状态，控制视频引擎的冻结与恢复
    // 如果 Tab 切换导致非激活，强制暂停视频并冻结所有 C++ 解码
    if (oldWidget.isTabActive != widget.isTabActive) {
      if (widget.isTabActive) {
        // Tab 激活：恢复焦点视频播放并重新准备缓存池
        VideoEnginePool.instance
            .focusIndex(_currentIndex, _videos.map((e) => e.url).toList());
      } else {
        // Tab 离开：静默冻结所有视频，实现物理隔离，解决跨 Tab 依然有声音的问题
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
                _fetchVideos();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text(
                '点击重试 (刷新)',
                style: TextStyle(color: Colors.white),
              ),
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
            await _fetchVideos();
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical, // 上下滑动
            physics:
                const NeverScrollableScrollPhysics(), // 【绝对拦截】：完全禁用系统默认滚动，一切交由代码控制
            itemCount: _videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              // 将滑动焦点事件抛给底层 C++ 引擎池进行物理指针偏移
              if (widget.isTabActive) {
                VideoEnginePool.instance
                    .focusIndex(index, _videos.map((e) => e.url).toList());
              }
            },
            itemBuilder: (context, index) {
              // 极限预加载：只渲染当前和前后 1 个
              final bool isRendered =
                  (index >= _currentIndex - 1 && index <= _currentIndex + 1);
              if (!isRendered) {
                return const SizedBox();
              }

              return Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    // 【终极降维打击】：必须将 Listener 放在 PageView 内部！
                    // 强制接管滚轮事件，让它永远不被原生 Scrollable 捕获！
                    GestureBinding.instance.pointerSignalResolver
                        .register(pointerSignal, (PointerSignalEvent event) {
                      final e = event as PointerScrollEvent;

                      // 【唯一的锁】：只要正在翻页动画中，任何滚轮事件全部静默吃掉
                      if (_isPaging) return;

                      // 只要收到了明确的上下滚动指令，立刻触发翻页并上锁
                      if (e.scrollDelta.dy > 0 &&
                          _currentIndex < _videos.length - 1) {
                        _isPaging = true;
                        _pageController
                            .animateToPage(
                              _currentIndex + 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                            .then((_) => _isPaging = false);
                      } else if (e.scrollDelta.dy < 0 && _currentIndex > 0) {
                        _isPaging = true;
                        _pageController
                            .animateToPage(
                              _currentIndex - 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                            )
                            .then((_) => _isPaging = false);
                      } else if (e.scrollDelta.dy > 0 &&
                          _currentIndex == _videos.length - 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已经到底啦，没有更多视频了')),
                        );
                      }
                    });
                  }
                },
                child: _VideoPlayerItem(
                  video: _videos[index],
                  index: index, // 传入实际索引
                  isActive: index == _currentIndex && widget.isTabActive,
                ),
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
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
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
                child: Video(
                  controller: controller,
                  controls: NoVideoControls, // 禁用默认的控制器，使用我们自己写的沉浸式 UI
                ),
              ),
            ),
          ),

          // 2. 状态蒙层 (暂停图标)
          // 【极致体验重构】：彻底抛弃基于 `buffering` 的粗暴 Loading 圈。
          // 因为底层 C++ 引擎池已经提前 1 个位置 open 预载了视频，
          // 滑动过来时已经有画面了。微小的 I/O 缓冲不应该打断视觉连贯性，
          // 真正的国民级 App 宁可画面静止一瞬间，也绝不闪烁 Loading 圈。
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, playingSnapshot) {
              final isPlaying = playingSnapshot.data ?? false;
              if (isPlaying || !isActive) return const SizedBox();
              return const Center(
                child: Icon(Icons.play_arrow, size: 80, color: Colors.white),
              );
            },
          ),

          // 3. 底部信息层 (作者、文案)
          Positioned(
            bottom: 80, // 避开最底部的进度条和底部导航栏
            left: 16,
            right: 80, // 给右侧的点赞按钮留出空间
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.authorName,
                  style: AppTypography.headlineLarge
                      .copyWith(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  video.description,
                  style: AppTypography.bodyLarge.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 4. 右侧操作区 (点赞、评论、分享、发布)
          Positioned(
            bottom: 80, // 和底部信息层对齐，避开进度条和底部导航栏
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
                const SizedBox(height: 30),
                // 发布/添加视频按钮，作为最顶端的UI设计重构，放在最末尾
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VideoUploadScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 32),
                  ),
                ),
              ],
            ),
          ),

          // 5. 最底部进度条 (完全沉浸，极其微小)
          Positioned(
            bottom: 60, // 刚好在底部导航栏上方
            left: 0,
            right: 0,
            height: 2,
            child: StreamBuilder<Duration>(
              stream: player.stream.position,
              builder: (context, snapshot) {
                // 绝对同步读取底层状态，拒绝 StreamBuilder 嵌套导致的 state 丢失
                final position = player.state.position;
                final duration = player.state.duration;

                double progress = 0;
                if (duration.inMilliseconds > 0) {
                  progress = position.inMilliseconds / duration.inMilliseconds;
                }
                progress = progress.clamp(0.0, 1.0);

                return LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
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
          style: AppTypography.labelLarge
              .copyWith(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
