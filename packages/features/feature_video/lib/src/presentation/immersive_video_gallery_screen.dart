import 'dart:async';

import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../domain/video_engine_pool.dart';

class ImmersiveVideoGalleryScreen extends StatefulWidget {
  const ImmersiveVideoGalleryScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.title = '作品',
  });

  final List<PlatformVideoRecord> videos;
  final int initialIndex;
  final String title;

  @override
  State<ImmersiveVideoGalleryScreen> createState() =>
      _ImmersiveVideoGalleryScreenState();
}

class _ImmersiveVideoGalleryScreenState extends State<ImmersiveVideoGalleryScreen> {
  late final PageController _pageController;
  late final List<_GalleryVideoModel> _videos;
  late int _currentIndex;
  bool _showSwipeHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _videos = widget.videos.map(_GalleryVideoModel.fromRecord).toList();
    _currentIndex = widget.initialIndex.clamp(0, _videos.isEmpty ? 0 : _videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    VideoEnginePool.instance.initialize();
    if (_videos.length <= 1) {
      _showSwipeHint = false;
    } else {
      _hintTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() {
            _showSwipeHint = false;
          });
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFocus(resetToCurrent: true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pageController.dispose();
    VideoEnginePool.instance.freezeAll();
    super.dispose();
  }

  void _syncFocus({bool resetToCurrent = false}) {
    if (_videos.isEmpty) {
      VideoEnginePool.instance.freezeAll();
      return;
    }
    final playbackSources = _videos.map((video) => video.playbackSource).toList();
    unawaited(
      VideoEnginePool.instance.focusIndex(_currentIndex, playbackSources),
    );
    if (resetToCurrent && _pageController.hasClients) {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_videos.isEmpty)
              const Center(
                child: Text(
                  '暂无可播放作品',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: (index) {
                  _currentIndex = index;
                  if (_showSwipeHint) {
                    _showSwipeHint = false;
                  }
                  _syncFocus();
                  setState(() {});
                },
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  return _ImmersiveVideoItem(
                    video: video,
                    index: index,
                    isActive: index == _currentIndex,
                  );
                },
              ),
            Positioned(
              top: 8,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _buildCircleAction(
                    icon: Icons.close,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      '${widget.title} ${_videos.isEmpty ? 0 : _currentIndex + 1}/${_videos.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSwipeHint)
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const Text(
                      '上下滑动查看作品',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.24),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _GalleryVideoModel {
  const _GalleryVideoModel({
    required this.primaryPlaybackUrl,
    required this.coverUrl,
    required this.authorName,
    required this.description,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.width,
    required this.height,
    required this.contentOrientation,
    required this.distributionChannelLabel,
    required this.primaryDistributionLabel,
    required this.statusLabel,
    required this.isPending,
    required this.isFailed,
    required this.pendingMessage,
    required this.failureMessage,
  });

  final String primaryPlaybackUrl;
  final String coverUrl;
  final String authorName;
  final String description;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int? width;
  final int? height;
  final String contentOrientation;
  final String distributionChannelLabel;
  final String primaryDistributionLabel;
  final String statusLabel;
  final bool isPending;
  final bool isFailed;
  final String pendingMessage;
  final String failureMessage;

  bool get isLandscape => contentOrientation == 'landscape';

  String get playbackSourceKey => primaryPlaybackUrl;

  VideoPlaybackSource get playbackSource => VideoPlaybackSource(
        primaryUrl: primaryPlaybackUrl,
      );

  factory _GalleryVideoModel.fromRecord(PlatformVideoRecord record) {
    final isPending = record.statusLabel == '处理中' ||
        record.statusLabel == '封装中' ||
        record.statusLabel == '排队中' ||
        record.statusLabel == '已上传';
    final isFailed = record.statusLabel == '处理失败' ||
        record.statusLabel == '发布失败' ||
        record.processingStatus == 'failed';
    return _GalleryVideoModel(
      primaryPlaybackUrl: record.primaryPlaybackUrl,
      coverUrl: record.coverUrl,
      authorName: record.authorName,
      description: record.description,
      likeCount: record.likeCount,
      commentCount: record.commentCount,
      shareCount: record.shareCount,
      width: record.width,
      height: record.height,
      contentOrientation: record.contentOrientation,
      distributionChannelLabel: record.distributionChannelLabel,
      primaryDistributionLabel: record.primaryDistributionLabel,
      statusLabel: record.statusLabel,
      isPending: isPending,
      isFailed: isFailed,
      pendingMessage: isPending ? record.statusLabel : '',
      failureMessage: isFailed ? '作品暂未发布成功，可返回重试' : '',
    );
  }
}

class _ImmersiveVideoItem extends StatefulWidget {
  const _ImmersiveVideoItem({
    required this.video,
    required this.index,
    required this.isActive,
  });

  final _GalleryVideoModel video;
  final int index;
  final bool isActive;

  @override
  State<_ImmersiveVideoItem> createState() => _ImmersiveVideoItemState();
}

class _ImmersiveVideoItemState extends State<_ImmersiveVideoItem> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final controller = VideoEnginePool.instance.getController(widget.index);
    final player = VideoEnginePool.instance.getPlayer(widget.index);
    final videoWidth =
        (widget.video.width ?? (widget.video.isLandscape ? 1920 : 1080))
            .toDouble();
    final videoHeight =
        (widget.video.height ?? (widget.video.isLandscape ? 1080 : 1920))
            .toDouble();
    final fit = widget.video.isLandscape ? BoxFit.contain : BoxFit.cover;

    return GestureDetector(
      onTap: () => VideoEnginePool.instance.togglePlay(widget.index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
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
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.56),
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
            ),
          ),
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              final shouldShow =
                  widget.isActive && !isPlaying && !widget.video.isPending;
              return IgnorePointer(
                child: AnimatedOpacity(
                  opacity: shouldShow ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: Center(
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (widget.video.isPending)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '发布中',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.video.pendingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.video.isFailed)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                    const SizedBox(height: 12),
                    const Text(
                      '发布失败',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.video.failureMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 92,
            left: 16,
            right: 80,
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaBadge(widget.video.statusLabel),
                    _buildMetaBadge(widget.video.distributionChannelLabel),
                    _buildMetaBadge(
                      widget.video.isPending
                          ? widget.video.pendingMessage
                          : widget.video.isFailed
                              ? '返回重试'
                          : widget.video.primaryDistributionLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 92,
            right: 8,
            child: Column(
              children: [
                if (!widget.video.isPending && !widget.video.isFailed) ...[
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
                ],
              ],
            ),
          ),
          Positioned(
            bottom: 58,
            left: 0,
            right: 0,
            child: StreamBuilder<bool>(
              stream: player.stream.playing,
              builder: (context, playingSnapshot) {
                final isPlaying = playingSnapshot.data ?? false;
                return StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, _) {
                    final position = player.state.position;
                    final duration = player.state.duration;
                    final isJustStarted = position.inMilliseconds < 100;
                    final shouldShow = widget.isActive &&
                        (!isPlaying || _isDragging) &&
                        (!isJustStarted || _isDragging);
                    if (!shouldShow) {
                      return const SizedBox.shrink();
                    }

                    double progress = 0;
                    if (duration.inMilliseconds > 0) {
                      progress =
                          position.inMilliseconds / duration.inMilliseconds;
                    }
                    progress = progress.clamp(0.0, 1.0);

                    return SizedBox(
                      height: 20,
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
                            player.pause();
                          },
                          onChanged: (value) {
                            final newPosition = Duration(
                              milliseconds:
                                  (value * duration.inMilliseconds).toInt(),
                            );
                            player.seek(newPosition);
                          },
                          onChangeEnd: (value) {
                            setState(() {
                              _isDragging = false;
                            });
                            player.play();
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

  String _formatCount(int count, {String fallback = '0'}) {
    if (count == 0 && fallback != '0') return fallback;
    if (count < 10000) return count.toString();
    final wCount = count / 10000.0;
    return '${wCount.toStringAsFixed(1)}w';
  }
}
