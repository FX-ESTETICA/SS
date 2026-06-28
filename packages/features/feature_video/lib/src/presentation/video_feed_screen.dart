import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/video_engine_pool.dart'; // 引入底层引擎池
import 'video_upload_screen.dart'; // 引入上传页面

import 'package:cached_network_image/cached_network_image.dart';

/// 商业级短视频数据模型 (结合了封面、计数器等冗余字段)
class VideoModel {
  final String url;
  final String coverUrl; // 独立的封面链接
  final String authorName;
  final String description;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  VideoModel({
    required this.url,
    required this.coverUrl,
    required this.authorName,
    required this.description,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
  });

  // 从云端 JSON 数据解析的工厂方法
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      url: json['video_url'] ?? '',
      coverUrl: json['cover_url'] ?? '',
      // 注意：目前由于 UI 层还是写死的作者名逻辑，如果关联了 auth.users，
      // 顶级架构会通过 JOIN 把 users.raw_user_meta_data->>'full_name' 带出来。
      // 这里为了兼容过渡期，先从表里直接拿或者默认
      authorName: json['author_name'] ?? json['authorName'] ?? '@匿名用户',
      description: json['description'] ?? '',
      viewCount: json['view_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
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
  bool _isFetching = false; // 网络请求锁

  @override
  void initState() {
    super.initState();
    // 1. 初始化 C++ 引擎池
    VideoEnginePool.instance.initialize();

    _pageController = PageController();
    _fetchVideos();
  }

  Future<void> _fetchVideos({bool isLoadMore = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final offset = isLoadMore ? _videos.length : 0;
      final data = await SupabaseService.fetchVideos(offset: offset, limit: 10);

      if (mounted) {
        setState(() {
          if (data.isNotEmpty) {
            // 将新数据转换为模型，并进行打乱（模拟推荐系统的千人千面）
            final newVideos = data.map((e) => VideoModel.fromJson(e)).toList();
            newVideos.shuffle(); // 纯前端打乱模拟个性化分发
            _videos.addAll(newVideos);
          } else if (isLoadMore && _videos.isNotEmpty) {
            // 【终极无底洞策略】：如果云端真的没有更多数据了，我们从已有列表中随机抽取打乱并追加
            // 永远不让用户看到“到底了”，保持心流不被打断
            final loopVideos = List<VideoModel>.from(_videos);
            loopVideos.shuffle();
            _videos.addAll(loopVideos.take(10));
          }
          _isLoading = false;
        });

        // 数据到达后，将焦点锁定到当前索引，开始底层预加载
        if (!isLoadMore) {
          VideoEnginePool.instance
              .focusIndex(0, _videos.map((e) => e.url).toList());
        } else {
          // 如果是追加数据，通知引擎池更新 URL 列表，但不改变当前播放焦点
          VideoEnginePool.instance
              .focusIndex(_currentIndex, _videos.map((e) => e.url).toList());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!isLoadMore) {
            _errorMessage = '云端连接失败，已切换至离线缓存模式';
            _videos.addAll([
              VideoModel(
                url:
                    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
                coverUrl:
                    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.jpg',
                authorName: '@智选官方 (离线)',
                description: '极致丝滑！智选超级 APP 首次点火测试 🔥 #Flutter #Tech',
              ),
              VideoModel(
                url:
                    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
                coverUrl:
                    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.jpg',
                authorName: '@自然探索 (离线)',
                description: '大自然的美丽瞬间 🌸',
              ),
            ]);
            _isLoading = false;
            VideoEnginePool.instance
                .focusIndex(0, _videos.map((e) => e.url).toList());
          }
        });
      }
    } finally {
      _isFetching = false;
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

    if (_videos.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '暂无视频内容',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '数据库还是空的，先上传第一条视频吧',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: _openUploadEntry,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: const Text(
                    '上传第一条视频',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 118,
            child: _buildUploadActionButton(),
          ),
        ],
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

              // 【无感预加载】：当用户滑动到倒数第 3 个视频时，静默拉取下一页
              if (_currentIndex >= _videos.length - 3) {
                _fetchVideos(isLoadMore: true);
              }

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
                        _pageController.jumpToPage(_currentIndex + 1);
                        _isPaging = false;
                      } else if (e.scrollDelta.dy < 0 && _currentIndex > 0) {
                        _isPaging = true;
                        _pageController.jumpToPage(_currentIndex - 1);
                        _isPaging = false;
                      } else if (e.scrollDelta.dy > 0 &&
                          _currentIndex == _videos.length - 1) {
                        // 如果用户手速极快，撞到了最后一帧（预加载没赶上），主动触发拉取并翻页尝试
                        _fetchVideos(isLoadMore: true);
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

  void _openUploadEntry() {
    if (SupabaseService.currentSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发布视频')),
      );
      return;
    }
    context.pushInstant<void>(
      builder: (context) => const VideoUploadScreen(),
    );
  }

  Widget _buildUploadActionButton() {
    return GestureDetector(
      onTap: _openUploadEntry,
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
    );
  }
}

/// 极简无状态视频播放组件 (彻底接管自底层池)
class _VideoPlayerItem extends StatefulWidget {
  final VideoModel video;
  final int index;
  final bool isActive;

  const _VideoPlayerItem({
    required this.video,
    required this.index,
    required this.isActive,
  });

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  bool _isDragging = false; // 是否正在手动拖拽进度条

  @override
  Widget build(BuildContext context) {
    // 物理级映射：根据真实 index 获取底层被分配的 3 个常驻 C++ 引擎之一
    final controller = VideoEnginePool.instance.getController(widget.index);
    final player = VideoEnginePool.instance.getPlayer(widget.index);

    return GestureDetector(
      onTap: () =>
          VideoEnginePool.instance.togglePlay(widget.index), // 点击屏幕暂停/播放
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底层封面图 (Poster Layer) - 终极防残影机制
          // 当视频底层在异步加载或被系统回收时，使用模糊的首帧图兜底，绝对不能露黑屏或上一条视频的残影
          SizedBox.expand(
            child: widget.video.coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.video.coverUrl,
                    fit: BoxFit.cover,
                    // 骨架屏占位：在封面还没加载出来时，用纯黑打底
                    placeholder: (context, url) =>
                        Container(color: Colors.black),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.black),
                  )
                : Container(color: Colors.black), // 如果没有封面，使用物理级黑场遮罩
          ),

          // 2. 视频底层渲染 (Zero-copy 直出)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover, // 裁切适应全屏（抖音模式）
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: StreamBuilder<bool>(
                  stream: player.stream.playing,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return Opacity(
                      opacity: isPlaying ? 1.0 : 0.0,
                      child: Video(
                        controller: controller,
                        controls: NoVideoControls,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 2. 状态蒙层 (暂停图标)
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, playingSnapshot) {
              final isPlaying = playingSnapshot.data ?? false;
              if (isPlaying || !widget.isActive) return const SizedBox();
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
                  widget.video.authorName,
                  style: AppTypography.headlineLarge
                      .copyWith(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
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
                _buildActionIcon(
                  Icons.favorite_border,
                  _formatCount(widget.video.likeCount),
                ),
                const SizedBox(height: 20),
                _buildActionIcon(
                  Icons.comment_outlined,
                  _formatCount(widget.video.commentCount),
                ),
                const SizedBox(height: 20),
                _buildActionIcon(
                  Icons.share_outlined,
                  _formatCount(widget.video.shareCount, fallback: '分享'),
                ),
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
                    if (SupabaseService.currentSession == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先登录后再发布视频')),
                      );
                      return;
                    }
                    context.pushInstant<void>(
                      builder: (context) => const VideoUploadScreen(),
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

          // 5. 沉浸式动态进度条 (仅在主动暂停且非初始缓冲时显示，带平滑动画防闪烁)
          Positioned(
            bottom: 50, // 稍微上移一点，留出 Slider 的点击热区
            left: 0,
            right: 0,
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;

                return StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, positionSnapshot) {
                    final position = player.state.position;
                    final duration = player.state.duration;

                    // 【核心拦截逻辑升级：解决切后台闪烁与误触】：
                    // 1. 如果视频不是当前焦点 (isActive == false) -> 绝对隐藏。
                    // 2. 如果正在播放且没有被拖拽 -> 隐藏。
                    // 3. 如果是刚切换过来的视频（进度极小）-> 隐藏。
                    final isJustStarted = position.inMilliseconds < 100;
                    bool shouldShow = true;

                    if (!widget.isActive) {
                      shouldShow = false; // 非焦点视频（如刚滑走的那一个）绝对不显示
                    } else if (isPlaying && !_isDragging) {
                      shouldShow = false;
                    } else if (isJustStarted && !_isDragging) {
                      shouldShow = false;
                    }

                    double progress = 0;
                    if (duration.inMilliseconds > 0) {
                      progress =
                          position.inMilliseconds / duration.inMilliseconds;
                    }
                    progress = progress.clamp(0.0, 1.0);

                    if (!shouldShow) {
                      return const SizedBox.shrink();
                    }

                    return SizedBox(
                      height: 20, // 扩大 Slider 的触摸热区
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.2),
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: progress,
                          onChangeStart: (value) {
                            setState(() {
                              _isDragging = true;
                            });
                            player.pause(); // 拖拽开始时强制暂停
                          },
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).toInt(),
                            );
                            player.seek(newPosition); // 实时预览画面帧
                          },
                          onChangeEnd: (value) {
                            setState(() {
                              _isDragging = false;
                            });
                            player.play(); // 拖拽松手后恢复播放，进度条随后自动隐藏
                          },
                        ),
                      ),
                    );
                  },
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

  /// 商业级大厂数字格式化 (例如：10000 -> 1.0w)
  String _formatCount(int count, {String fallback = '0'}) {
    if (count == 0 && fallback != '0') return fallback;
    if (count < 10000) return count.toString();
    double wCount = count / 10000.0;
    // 保留一位小数
    return '${wCount.toStringAsFixed(1)}w';
  }
}
