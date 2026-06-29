import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/video_engine_pool.dart'; // 引入底层引擎池
import 'video_upload_screen.dart'; // 引入上传页面

enum VideoFeedMode {
  portrait(
    tabLabel: '推荐',
    distributionChannel: 'recommendation',
    contentOrientation: 'portrait',
  ),
  landscape(
    tabLabel: '横屏',
    distributionChannel: 'landscape',
    contentOrientation: 'landscape',
  );

  const VideoFeedMode({
    required this.tabLabel,
    required this.distributionChannel,
    required this.contentOrientation,
  });

  final String tabLabel;
  final String distributionChannel;
  final String contentOrientation;
}

/// 商业级短视频数据模型 (结合了封面、计数器等冗余字段)
class VideoModel {
  final String url;
  final String primaryPlaybackUrl;
  final String? fallbackPlaybackUrl;
  final bool prefersStreaming;
  final String coverUrl; // 独立的封面链接
  final String authorName;
  final String description;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int? width;
  final int? height;
  final String contentOrientation;
  final String distributionChannelLabel;
  final String primaryDistributionLabel;
  final String statusLabel;

  VideoModel({
    required this.url,
    required this.primaryPlaybackUrl,
    this.fallbackPlaybackUrl,
    this.prefersStreaming = false,
    required this.coverUrl,
    required this.authorName,
    required this.description,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.width,
    this.height,
    this.contentOrientation = 'portrait',
    this.distributionChannelLabel = '推荐',
    this.primaryDistributionLabel = 'MP4直出',
    this.statusLabel = '已发布',
  });

  bool get isLandscape => contentOrientation == 'landscape';
  String get playbackSourceKey => prefersStreaming
      ? '$primaryPlaybackUrl|${fallbackPlaybackUrl ?? ''}'
      : primaryPlaybackUrl;
  VideoPlaybackSource get playbackSource => VideoPlaybackSource(
        primaryUrl: primaryPlaybackUrl,
        fallbackUrl: fallbackPlaybackUrl,
        prefersStreaming: prefersStreaming,
      );

  factory VideoModel.fromRecord(PlatformVideoRecord record) {
    return VideoModel(
      url: record.primaryPlaybackUrl,
      primaryPlaybackUrl: record.primaryPlaybackUrl,
      fallbackPlaybackUrl: record.fallbackPlaybackUrl,
      prefersStreaming: record.prefersStreaming,
      coverUrl: record.coverUrl,
      authorName: record.authorName,
      description: record.description,
      viewCount: record.viewCount,
      likeCount: record.likeCount,
      commentCount: record.commentCount,
      shareCount: record.shareCount,
      width: record.width,
      height: record.height,
      contentOrientation: record.contentOrientation,
      distributionChannelLabel: record.distributionChannelLabel,
      primaryDistributionLabel: record.primaryDistributionLabel,
      statusLabel: record.statusLabel,
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
  final Map<VideoFeedMode, List<VideoModel>> _videosByMode = {
    VideoFeedMode.portrait: [],
    VideoFeedMode.landscape: [],
  };
  final Map<VideoFeedMode, int> _currentIndexByMode = {
    VideoFeedMode.portrait: 0,
    VideoFeedMode.landscape: 0,
  };
  final Map<VideoFeedMode, String?> _errorMessageByMode = {
    VideoFeedMode.portrait: null,
    VideoFeedMode.landscape: null,
  };
  final Map<VideoFeedMode, bool> _loadedByMode = {
    VideoFeedMode.portrait: false,
    VideoFeedMode.landscape: false,
  };
  final Set<VideoFeedMode> _fetchingModes = <VideoFeedMode>{};
  VideoFeedMode _currentFeedMode = VideoFeedMode.portrait;
  bool _isLoading = true;
  bool _isPaging = false; // 翻页状态锁

  List<VideoModel> get _videos => _videosByMode[_currentFeedMode]!;
  String? get _errorMessage => _errorMessageByMode[_currentFeedMode];
  int get _currentIndex => _currentIndexByMode[_currentFeedMode]!;

  @override
  void initState() {
    super.initState();
    // 1. 初始化 C++ 引擎池
    VideoEnginePool.instance.initialize();

    _pageController = PageController();
    _fetchVideos();
  }

  Future<void> _fetchVideos({
    bool isLoadMore = false,
    VideoFeedMode? mode,
  }) async {
    final targetMode = mode ?? _currentFeedMode;
    if (_fetchingModes.contains(targetMode)) return;
    _fetchingModes.add(targetMode);

    try {
      if (!isLoadMore && mounted && targetMode == _currentFeedMode) {
        setState(() {
          _isLoading = true;
          _errorMessageByMode[targetMode] = null;
        });
      }

      final existingVideos = _videosByMode[targetMode]!;
      final offset = isLoadMore ? existingVideos.length : 0;
      final data = await SupabaseService.fetchVideos(
        offset: offset,
        limit: 10,
        distributionChannel: targetMode.distributionChannel,
      );

      if (mounted) {
        setState(() {
          final currentList = _videosByMode[targetMode]!;
          if (!isLoadMore) {
            currentList.clear();
          }
          if (data.isNotEmpty) {
            final newVideos = data.map(VideoModel.fromRecord).toList();
            newVideos.shuffle(); // 纯前端打乱模拟个性化分发
            currentList.addAll(newVideos);
          } else if (isLoadMore && currentList.isNotEmpty) {
            // 【终极无底洞策略】：如果云端真的没有更多数据了，我们从已有列表中随机抽取打乱并追加
            // 永远不让用户看到“到底了”，保持心流不被打断
            final loopVideos = List<VideoModel>.from(currentList);
            loopVideos.shuffle();
            currentList.addAll(loopVideos.take(10));
          }
          _loadedByMode[targetMode] = true;
          if (targetMode == _currentFeedMode) {
            _isLoading = false;
          }
        });

        if (targetMode == _currentFeedMode) {
          _syncFocusForCurrentFeed(resetToFirst: !isLoadMore);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (!isLoadMore && targetMode == _currentFeedMode) {
            _errorMessageByMode[targetMode] = '云端连接失败，请稍后重试';
            _videosByMode[targetMode]!.clear();
            _isLoading = false;
            _loadedByMode[targetMode] = true;
          }
        });
        if (targetMode == _currentFeedMode) {
          _syncFocusForCurrentFeed(resetToFirst: true);
        }
      }
    } finally {
      _fetchingModes.remove(targetMode);
    }
  }

  @override
  void didUpdateWidget(covariant VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // @AI_CONTEXT: [生命周期解耦] 监听外层 Tab 切换状态，控制视频引擎的冻结与恢复
    // 如果 Tab 切换导致非激活，强制暂停视频并冻结所有 C++ 解码
    if (oldWidget.isTabActive != widget.isTabActive) {
      if (widget.isTabActive) {
        _syncFocusForCurrentFeed();
      } else {
        // Tab 离开：静默冻结所有视频，实现物理隔离，解决跨 Tab 依然有声音的问题
        VideoEnginePool.instance.freezeAll();
      }
    }
  }

  void _syncFocusForCurrentFeed({bool resetToFirst = false}) {
    if (!widget.isTabActive) {
      VideoEnginePool.instance.freezeAll();
      return;
    }

    final videos = _videosByMode[_currentFeedMode]!;
    if (videos.isEmpty) {
      VideoEnginePool.instance.freezeAll();
      return;
    }

    final safeIndex = resetToFirst
        ? 0
        : _currentIndexByMode[_currentFeedMode]!.clamp(0, videos.length - 1);
    _currentIndexByMode[_currentFeedMode] = safeIndex;
    VideoEnginePool.instance.focusIndex(
      safeIndex,
      videos.map((video) => video.playbackSource).toList(),
    );
  }

  void _replacePageController(int initialPage) {
    final previous = _pageController;
    _pageController = PageController(initialPage: initialPage);
    previous.dispose();
  }

  void _switchFeedMode(VideoFeedMode mode) {
    if (_currentFeedMode == mode) {
      return;
    }

    final initialPage = _currentIndexByMode[mode]!;
    setState(() {
      _currentFeedMode = mode;
      _isPaging = false;
      _isLoading = !_loadedByMode[mode]!;
    });
    _replacePageController(initialPage);

    if (_loadedByMode[mode]!) {
      _syncFocusForCurrentFeed();
      return;
    }
    unawaited(_fetchVideos(mode: mode));
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
    return Stack(
      children: [
        Positioned.fill(child: _buildContentLayer()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: _buildFeedSwitcher(),
            ),
          ),
        ),
        if (_errorMessage != null)
          Positioned(
            top: 86,
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

  Widget _buildContentLayer() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchVideos(mode: _currentFeedMode),
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
      final title = _currentFeedMode == VideoFeedMode.portrait
          ? '暂无竖屏视频'
          : '暂无横屏视频';
      final subtitle = _currentFeedMode == VideoFeedMode.portrait
          ? '数据库还是空的，先上传第一条视频吧'
          : '横屏专区还没有内容，先上传一条横屏视频吧';
      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: const TextStyle(
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

    return RefreshIndicator(
      onRefresh: () => _fetchVideos(mode: _currentFeedMode),
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndexByMode[_currentFeedMode] = index;
          });

          if (index >= _videos.length - 3) {
            _fetchVideos(isLoadMore: true, mode: _currentFeedMode);
          }

          if (widget.isTabActive) {
            VideoEnginePool.instance.focusIndex(
              index,
              _videos.map((video) => video.playbackSource).toList(),
            );
          }
        },
        itemBuilder: (context, index) {
          final bool isRendered =
              (index >= _currentIndex - 1 && index <= _currentIndex + 1);
          if (!isRendered) {
            return const SizedBox();
          }

          return Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(
                  pointerSignal,
                  (PointerSignalEvent event) {
                    final e = event as PointerScrollEvent;

                    if (_isPaging) return;

                    if (e.scrollDelta.dy > 0 && _currentIndex < _videos.length - 1) {
                      _isPaging = true;
                      _pageController.jumpToPage(_currentIndex + 1);
                      _isPaging = false;
                    } else if (e.scrollDelta.dy < 0 && _currentIndex > 0) {
                      _isPaging = true;
                      _pageController.jumpToPage(_currentIndex - 1);
                      _isPaging = false;
                    } else if (e.scrollDelta.dy > 0 &&
                        _currentIndex == _videos.length - 1) {
                      _fetchVideos(isLoadMore: true, mode: _currentFeedMode);
                    }
                  },
                );
              }
            },
            child: _VideoPlayerItem(
              video: _videos[index],
              index: index,
              isActive: index == _currentIndex && widget.isTabActive,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: VideoFeedMode.values.map((mode) {
          final isSelected = mode == _currentFeedMode;
          return GestureDetector(
            onTap: () => _switchFeedMode(mode),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                mode.tabLabel,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
      ),
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
    // 物理级映射：根据真实 index 获取底层被分配的常驻 C++ 引擎槽位
    final controller = VideoEnginePool.instance.getController(widget.index);
    final player = VideoEnginePool.instance.getPlayer(widget.index);
    final videoWidth = (widget.video.width ?? (widget.video.isLandscape ? 1920 : 1080))
        .toDouble();
    final videoHeight =
        (widget.video.height ?? (widget.video.isLandscape ? 1080 : 1920))
            .toDouble();
    final fit = widget.video.isLandscape ? BoxFit.contain : BoxFit.cover;

    return GestureDetector(
      onTap: () =>
          VideoEnginePool.instance.togglePlay(widget.index), // 点击屏幕暂停/播放
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          // 1. 视频真实帧直出：切换时不再回退到封面层，暂停和卡住都保留最后一帧
          ValueListenableBuilder<int>(
            valueListenable: VideoEnginePool.instance.stateVersion,
            builder: (context, _, __) {
              final showVideo = VideoEnginePool.instance.isVisualReady(
                widget.index,
                widget.video.playbackSourceKey,
              );
              if (!showVideo) {
                return const SizedBox.expand();
              }

              return SizedBox.expand(
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: videoWidth,
                    height: videoHeight,
                    child: Video(
                      controller: controller,
                      controls: NoVideoControls,
                    ),
                  ),
                ),
              );
            },
          ),

          // 2. 底部信息层 (作者、文案)
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaBadge(widget.video.statusLabel),
                    _buildMetaBadge(widget.video.distributionChannelLabel),
                    _buildMetaBadge(widget.video.primaryDistributionLabel),
                  ],
                ),
              ],
            ),
          ),

          // 3. 右侧操作区 (点赞、评论、分享、发布)
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

          // 4. 沉浸式动态进度条 (仅在主动暂停且非初始缓冲时显示，带平滑动画防闪烁)
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

  Widget _buildMetaBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
