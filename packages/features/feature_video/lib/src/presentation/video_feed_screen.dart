import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart'; // 引入云端服务
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import '../domain/camera_warmup_service.dart';
import '../domain/disk_cache_manager.dart';
import '../domain/video_engine_pool.dart'; // 引入底层引擎池
import '../domain/publish_overlay_store.dart';
import 'video_upload_screen.dart'; // 引入上传页面

// #region debug-point B:feed-probe
Future<void> _debugFeedProbe(
  String hypothesisId,
  String location,
  String msg, {
  Map<String, Object?> data = const <String, Object?>{},
  String? traceId,
}) async {
  try {
    final logFile = File(
      r'c:\Users\49975\Desktop\智选\.dbg\trae-debug-log-startup-black-screen.ndjson',
    );
    final event = <String, Object?>{
      'sessionId': 'video-black-frame',
      'runId': 'post-fix',
      'hypothesisId': hypothesisId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'location': location,
      'msg': '[DEBUG] $msg',
      'data': data,
      if (traceId != null) 'traceId': traceId,
    };
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString(
      '${jsonEncode(event)}\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}
// #endregion

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
  final String? launchPlaybackUrl;
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
  final bool isPending;
  final bool isFailed;
  final String? publishJobId;
  final String pendingMessage;
  final String? errorMessage;

  VideoModel({
    required this.url,
    required this.primaryPlaybackUrl,
    this.launchPlaybackUrl,
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
    this.isPending = false,
    this.isFailed = false,
    this.publishJobId,
    this.pendingMessage = '',
    this.errorMessage,
  });

  bool get isLandscape => contentOrientation == 'landscape';
  String get playbackSourceKey => primaryPlaybackUrl;
  VideoPlaybackSource get playbackSource => VideoPlaybackSource(
        primaryUrl: primaryPlaybackUrl,
        playableUrlOverride: launchPlaybackUrl,
      );

  factory VideoModel.fromRecord(PlatformVideoRecord record) {
    return VideoModel(
      url: record.primaryPlaybackUrl,
      primaryPlaybackUrl: record.primaryPlaybackUrl,
      launchPlaybackUrl: null,
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

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      url: json['url'] as String? ?? '',
      primaryPlaybackUrl: json['primaryPlaybackUrl'] as String? ?? '',
      launchPlaybackUrl: null,
      coverUrl: json['coverUrl'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      viewCount: json['viewCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      width: json['width'] as int?,
      height: json['height'] as int?,
      contentOrientation: json['contentOrientation'] as String? ?? 'portrait',
      distributionChannelLabel:
          json['distributionChannelLabel'] as String? ?? '',
      primaryDistributionLabel:
          json['primaryDistributionLabel'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      isPending: json['isPending'] as bool? ?? false,
      isFailed: json['isFailed'] as bool? ?? false,
      publishJobId: json['publishJobId'] as String?,
      pendingMessage: json['pendingMessage'] as String? ?? '',
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'url': url,
      'primaryPlaybackUrl': primaryPlaybackUrl,
      'coverUrl': coverUrl,
      'authorName': authorName,
      'description': description,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'width': width,
      'height': height,
      'contentOrientation': contentOrientation,
      'distributionChannelLabel': distributionChannelLabel,
      'primaryDistributionLabel': primaryDistributionLabel,
      'statusLabel': statusLabel,
      'isPending': isPending,
      'isFailed': isFailed,
      'publishJobId': publishJobId,
      'pendingMessage': pendingMessage,
      'errorMessage': errorMessage,
    };
  }

  VideoModel copyWith({
    String? launchPlaybackUrl,
  }) {
    return VideoModel(
      url: url,
      primaryPlaybackUrl: primaryPlaybackUrl,
      launchPlaybackUrl: launchPlaybackUrl ?? this.launchPlaybackUrl,
      coverUrl: coverUrl,
      authorName: authorName,
      description: description,
      viewCount: viewCount,
      likeCount: likeCount,
      commentCount: commentCount,
      shareCount: shareCount,
      width: width,
      height: height,
      contentOrientation: contentOrientation,
      distributionChannelLabel: distributionChannelLabel,
      primaryDistributionLabel: primaryDistributionLabel,
      statusLabel: statusLabel,
      isPending: isPending,
      isFailed: isFailed,
      publishJobId: publishJobId,
      pendingMessage: pendingMessage,
      errorMessage: errorMessage,
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
  static const int _initialFetchLimit = 3;
  static const int _pagingFetchLimit = 10;
  static const Duration _initialRenderableWait = Duration(milliseconds: 1400);
  static const Duration _initialRenderablePoll = Duration(milliseconds: 40);
  static const String _launchSnapshotDirectoryName = 'zhixuan_launch_feed';
  late PageController _pageController;
  late final PublishOverlayStore _publishOverlayStore;
  final Map<VideoFeedMode, List<VideoModel>> _videosByMode = {
    VideoFeedMode.portrait: [],
    VideoFeedMode.landscape: [],
  };
  final Map<VideoFeedMode, bool> _didPrimeMoreByMode = {
    VideoFeedMode.portrait: false,
    VideoFeedMode.landscape: false,
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
  String? _lastHandledPublishJobId;
  final Stopwatch _screenStopwatch = Stopwatch()..start();

  List<VideoModel> get _videos => _videosByMode[_currentFeedMode]!;
  String? get _errorMessage => _errorMessageByMode[_currentFeedMode];
  int get _currentIndex => _currentIndexByMode[_currentFeedMode]!;

  @override
  void initState() {
    super.initState();
    // #region debug-point B:feed-init
    unawaited(
      _debugFeedProbe(
        'B',
        'video_feed_screen.dart:initState',
        'feed_init_state',
        data: <String, Object?>{
          'isTabActive': widget.isTabActive,
        },
      ),
    );
    // #endregion
    // 1. 初始化 C++ 引擎池
    VideoEnginePool.instance.initialize();

    _publishOverlayStore = PublishOverlayStore.instance;
    _publishOverlayStore.addListener(_handlePublishOverlayChanged);
    _pageController = PageController();
    unawaited(CameraWarmupService.instance.warmup());
    unawaited(_bootstrapFeed());
  }

  Future<void> _bootstrapFeed() async {
    await _restoreLaunchSnapshot(_currentFeedMode);
    await _fetchHeadVideo(_currentFeedMode);
    await _fetchVideos();
  }

  Future<VideoModel> _prepareLaunchReadyVideo(
    VideoModel video, {
    Duration maxWait = const Duration(milliseconds: 900),
  }) async {
    await DiskVideoCacheManager.instance.initialize();
    final launchPlayableUrl =
        await DiskVideoCacheManager.instance.prepareLaunchPlayableUrl(
      video.playbackSource,
      maxWait: maxWait,
    );
    return video.copyWith(
      launchPlaybackUrl: launchPlayableUrl == video.primaryPlaybackUrl
          ? null
          : launchPlayableUrl,
    );
  }

  Future<void> _fetchHeadVideo(VideoFeedMode mode) async {
    if (_fetchingModes.contains(mode)) return;
    final headTraceId =
        'feed-head-${mode.name}-${DateTime.now().microsecondsSinceEpoch}';
    final stopwatch = Stopwatch()..start();
    // #region debug-point B:head-fetch-start
    unawaited(
      _debugFeedProbe(
        'B',
        'video_feed_screen.dart:_fetchHeadVideo',
        'fetch_head_video_start',
        traceId: headTraceId,
        data: <String, Object?>{
          'mode': mode.name,
          'existingCount': _videosByMode[mode]!.length,
        },
      ),
    );
    // #endregion
    try {
      final record = await SupabaseService.fetchHeadVideo(
        distributionChannel: mode.distributionChannel,
      );
      if (record == null) {
        return;
      }
      final headVideo = await _prepareLaunchReadyVideo(
        VideoModel.fromRecord(record),
        maxWait: const Duration(milliseconds: 1200),
      );
      DiskVideoCacheManager.instance
          .preloadPlaybackSource(headVideo.playbackSource);
      if (!mounted) {
        return;
      }
      final existingList = _videosByMode[mode]!;
      final existingHead = existingList.isNotEmpty ? existingList.first : null;
      final currentHeadKey =
          existingList.isNotEmpty ? existingList.first.playbackSourceKey : null;
      final shouldRefreshHeadPlayableUrl = existingHead != null &&
          existingHead.playbackSourceKey == headVideo.playbackSourceKey &&
          existingHead.launchPlaybackUrl != headVideo.launchPlaybackUrl;
      if (currentHeadKey == headVideo.playbackSourceKey &&
          !shouldRefreshHeadPlayableUrl) {
        return;
      }
      setState(() {
        if (shouldRefreshHeadPlayableUrl && existingList.isNotEmpty) {
          existingList[0] = headVideo;
        } else {
          existingList
            ..removeWhere(
              (video) => video.playbackSourceKey == headVideo.playbackSourceKey,
            )
            ..insert(0, headVideo);
        }
        _loadedByMode[mode] = true;
        if (mode == _currentFeedMode) {
          _currentIndexByMode[mode] = 0;
          _isLoading = false;
        }
      });
      if (mode == _currentFeedMode) {
        _replacePageController(0);
        VideoEnginePool.instance.focusIndex(
          0,
          _videosByMode[mode]!.map((video) => video.playbackSource).toList(),
        );
      }
      unawaited(_persistLaunchSnapshot(mode, headVideo));
      // #region debug-point B:head-fetch-success
      unawaited(
        _debugFeedProbe(
          'B',
          'video_feed_screen.dart:_fetchHeadVideo',
          'fetch_head_video_success',
          traceId: headTraceId,
          data: <String, Object?>{
            'mode': mode.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'sourceKey': headVideo.playbackSourceKey,
            'isCached': DiskVideoCacheManager.instance.hasCachedUrl(
              headVideo.primaryPlaybackUrl,
            ),
          },
        ),
      );
      // #endregion
    } catch (e) {
      // #region debug-point E:head-fetch-fail
      unawaited(
        _debugFeedProbe(
          'E',
          'video_feed_screen.dart:_fetchHeadVideo',
          'fetch_head_video_fail',
          traceId: headTraceId,
          data: <String, Object?>{
            'mode': mode.name,
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'error': e.toString(),
            'errorType': e.runtimeType.toString(),
          },
        ),
      );
      // #endregion
    }
  }

  Future<void> _fetchVideos({
    bool isLoadMore = false,
    VideoFeedMode? mode,
  }) async {
    final targetMode = mode ?? _currentFeedMode;
    if (_fetchingModes.contains(targetMode)) return;
    _fetchingModes.add(targetMode);
    final fetchTraceId =
        'feed-fetch-${targetMode.name}-${DateTime.now().microsecondsSinceEpoch}';
    final fetchStopwatch = Stopwatch()..start();
    // #region debug-point B:fetch-start
    unawaited(
      _debugFeedProbe(
        'B',
        'video_feed_screen.dart:_fetchVideos',
        'fetch_videos_start',
        traceId: fetchTraceId,
        data: <String, Object?>{
          'mode': targetMode.name,
          'isLoadMore': isLoadMore,
          'existingCount': _videosByMode[targetMode]!.length,
        },
      ),
    );
    // #endregion

    try {
      if (!isLoadMore &&
          mounted &&
          targetMode == _currentFeedMode &&
          _videosByMode[targetMode]!.isEmpty) {
        setState(() {
          _isLoading = true;
          _errorMessageByMode[targetMode] = null;
        });
      }

      final existingVideos = _videosByMode[targetMode]!;
      final offset = isLoadMore ? existingVideos.length : 0;
      final limit = isLoadMore ? _pagingFetchLimit : _initialFetchLimit;
      final data = await SupabaseService.fetchVideos(
        offset: offset,
        limit: limit,
        distributionChannel: targetMode.distributionChannel,
      );
      // #region debug-point B:fetch-success
      unawaited(
        _debugFeedProbe(
          'B',
          'video_feed_screen.dart:_fetchVideos',
          'fetch_videos_success',
          traceId: fetchTraceId,
          data: <String, Object?>{
            'mode': targetMode.name,
            'isLoadMore': isLoadMore,
            'offset': offset,
            'resultCount': data.length,
            'elapsedMs': fetchStopwatch.elapsedMilliseconds,
          },
        ),
      );
      // #endregion

      var newVideos = data.map(VideoModel.fromRecord).toList();
      if (!isLoadMore && newVideos.isNotEmpty) {
        newVideos = <VideoModel>[
          await _prepareLaunchReadyVideo(newVideos.first),
          ...newVideos.skip(1),
        ];
      }
      int nextFocusIndex = _currentIndexByMode[targetMode]!;
      if (targetMode == _currentFeedMode && newVideos.isNotEmpty) {
        final previewList = isLoadMore
            ? <VideoModel>[..._videosByMode[targetMode]!, ...newVideos]
            : newVideos;
        if (isLoadMore) {
          nextFocusIndex = _currentIndexByMode[targetMode]!.clamp(
            0,
            previewList.length - 1,
          );
          VideoEnginePool.instance.focusIndex(
            nextFocusIndex,
            previewList.map((video) => video.playbackSource).toList(),
          );
        } else {
          nextFocusIndex = await _resolveInitialRenderableIndex(previewList);
        }
      }

      if (mounted) {
        setState(() {
          final currentList = _videosByMode[targetMode]!;
          if (!isLoadMore) {
            currentList.clear();
            _didPrimeMoreByMode[targetMode] = false;
          }
          if (newVideos.isNotEmpty) {
            currentList.addAll(newVideos);
          }
          _loadedByMode[targetMode] = true;
          if (targetMode == _currentFeedMode) {
            _currentIndexByMode[targetMode] = nextFocusIndex;
            _isLoading = false;
          }
        });

        if (targetMode == _currentFeedMode) {
          if (!isLoadMore) {
            _replacePageController(nextFocusIndex);
          }
          _syncFocusForCurrentFeed(resetToFirst: false);
        }
        if (!isLoadMore && _videosByMode[targetMode]!.isNotEmpty) {
          unawaited(
            _persistLaunchSnapshot(
              targetMode,
              _videosByMode[targetMode]!.first,
            ),
          );
        }
        if (!isLoadMore && _videosByMode[targetMode]!.isNotEmpty) {
          DiskVideoCacheManager.instance.preloadPlaybackSource(
            _videosByMode[targetMode]!.first.playbackSource,
          );
        }
        if (!isLoadMore &&
            newVideos.length == limit &&
            !_didPrimeMoreByMode[targetMode]!) {
          _didPrimeMoreByMode[targetMode] = true;
          unawaited(_fetchVideos(isLoadMore: true, mode: targetMode));
        }
      }
    } catch (e) {
      // #region debug-point E:fetch-fail
      unawaited(
        _debugFeedProbe(
          'E',
          'video_feed_screen.dart:_fetchVideos',
          'fetch_videos_fail',
          traceId: fetchTraceId,
          data: <String, Object?>{
            'mode': targetMode.name,
            'isLoadMore': isLoadMore,
            'elapsedMs': fetchStopwatch.elapsedMilliseconds,
            'error': e.toString(),
            'errorType': e.runtimeType.toString(),
          },
        ),
      );
      // #endregion
      if (mounted) {
        setState(() {
          if (!isLoadMore && targetMode == _currentFeedMode) {
            _errorMessageByMode[targetMode] = e.toString();
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
        unawaited(CameraWarmupService.instance.warmup());
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
      // #region debug-point D:sync-focus-frozen
      unawaited(
        _debugFeedProbe(
          'D',
          'video_feed_screen.dart:_syncFocusForCurrentFeed',
          'sync_focus_skipped_inactive_tab',
          data: <String, Object?>{
            'mode': _currentFeedMode.name,
          },
        ),
      );
      // #endregion
      return;
    }

    final videos = _videosByMode[_currentFeedMode]!;
    if (videos.isEmpty) {
      VideoEnginePool.instance.freezeAll();
      // #region debug-point D:sync-focus-empty
      unawaited(
        _debugFeedProbe(
          'D',
          'video_feed_screen.dart:_syncFocusForCurrentFeed',
          'sync_focus_skipped_empty_feed',
          data: <String, Object?>{
            'mode': _currentFeedMode.name,
          },
        ),
      );
      // #endregion
      return;
    }

    final safeIndex = resetToFirst
        ? 0
        : _currentIndexByMode[_currentFeedMode]!.clamp(0, videos.length - 1);
    _currentIndexByMode[_currentFeedMode] = safeIndex;
    // #region debug-point B:sync-focus
    unawaited(
      _debugFeedProbe(
        'B',
        'video_feed_screen.dart:_syncFocusForCurrentFeed',
        'sync_focus_for_feed',
        data: <String, Object?>{
          'mode': _currentFeedMode.name,
          'safeIndex': safeIndex,
          'videoCount': videos.length,
          'resetToFirst': resetToFirst,
          'elapsedMs': _screenStopwatch.elapsedMilliseconds,
        },
      ),
    );
    // #endregion
    VideoEnginePool.instance.focusIndex(
      safeIndex,
      videos.map((video) => video.playbackSource).toList(),
    );
  }

  Future<int> _resolveInitialRenderableIndex(
    List<VideoModel> previewList,
  ) async {
    if (previewList.isEmpty) {
      return 0;
    }
    final sources = previewList.map((video) => video.playbackSource).toList();
    VideoEnginePool.instance.focusIndex(0, sources);

    final startedAt = DateTime.now();
    final candidateCount = previewList.length.clamp(1, 3);
    while (DateTime.now().difference(startedAt) < _initialRenderableWait) {
      for (int index = 0; index < candidateCount; index++) {
        final sourceKey = previewList[index].playbackSourceKey;
        if (VideoEnginePool.instance.isVisualReady(index, sourceKey)) {
          if (index != 0) {
            VideoEnginePool.instance.focusIndex(index, sources);
          }
          return index;
        }
      }
      await Future.delayed(_initialRenderablePoll);
    }

    for (int index = 0; index < candidateCount; index++) {
      final sourceKey = previewList[index].playbackSourceKey;
      if (VideoEnginePool.instance.isVisualReady(index, sourceKey)) {
        if (index != 0) {
          VideoEnginePool.instance.focusIndex(index, sources);
        }
        return index;
      }
    }
    return 0;
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
    _publishOverlayStore.removeListener(_handlePublishOverlayChanged);
    _pageController.dispose();
    VideoEnginePool.instance.freezeAll();
    super.dispose();
  }

  void _handlePublishOverlayChanged() {
    if (!mounted) {
      return;
    }
    final state = _publishOverlayStore.state;
    if (state.isActive && state.pendingVideo != null) {
      _upsertPendingVideo(state.pendingVideo!);
    }
    if (state.stage == PublishOverlayStage.completed &&
        state.completedVideo != null &&
        state.jobId != null &&
        state.jobId != _lastHandledPublishJobId) {
      _lastHandledPublishJobId = state.jobId;
      _injectPublishedVideo(state.completedVideo!);
    }
    if (state.stage == PublishOverlayStage.failed &&
        state.pendingVideo != null) {
      _upsertPendingVideo(state.pendingVideo!);
    }
    setState(() {});
  }

  void _injectPublishedVideo(PendingPublishedVideo completedVideo) {
    final targetMode = completedVideo.contentOrientation == 'landscape'
        ? VideoFeedMode.landscape
        : VideoFeedMode.portrait;
    final targetList = _videosByMode[targetMode]!;
    final primaryUrl = completedVideo.primaryPlaybackUrl;
    final exists = targetList.any(
      (video) => video.primaryPlaybackUrl == primaryUrl,
    );
    if (exists) {
      return;
    }

    final video = _videoModelFromPublishedVideo(completedVideo);

    setState(() {
      final pendingIndex = targetList.indexWhere(
        (item) => item.publishJobId == completedVideo.jobId,
      );
      if (pendingIndex != -1) {
        targetList[pendingIndex] = video;
      } else {
        final insertIndex = targetMode == _currentFeedMode
            ? (_currentIndexByMode[targetMode]! + 1).clamp(0, targetList.length)
            : 0;
        targetList.insert(insertIndex, video);
      }
      _loadedByMode[targetMode] = true;
      _errorMessageByMode[targetMode] = null;
      if (_currentFeedMode == targetMode) {
        _isLoading = false;
      }
      if (targetList.length == 1) {
        _currentIndexByMode[targetMode] = 0;
        if (_currentFeedMode == targetMode) {
          _replacePageController(0);
        }
      }
    });

    if (_currentFeedMode == targetMode) {
      _syncFocusForCurrentFeed();
    }
  }

  Future<File> _launchSnapshotFile(VideoFeedMode mode) async {
    final tempDir = await getTemporaryDirectory();
    final directory = Directory(
      '${tempDir.path}${Platform.pathSeparator}$_launchSnapshotDirectoryName',
    );
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}${mode.name}_head.json',
    );
  }

  Future<void> _restoreLaunchSnapshot(VideoFeedMode mode) async {
    try {
      final file = await _launchSnapshotFile(mode);
      if (!await file.exists()) {
        return;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return;
      }
      final snapshot = await _prepareLaunchReadyVideo(
        VideoModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(content) as Map),
        ),
        maxWait: const Duration(milliseconds: 500),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _videosByMode[mode]!
          ..clear()
          ..add(snapshot);
        _loadedByMode[mode] = true;
        _errorMessageByMode[mode] = null;
        if (mode == _currentFeedMode) {
          _currentIndexByMode[mode] = 0;
          _isLoading = false;
        }
      });
      if (mode == _currentFeedMode) {
        _replacePageController(0);
        VideoEnginePool.instance.focusIndex(
          0,
          <VideoPlaybackSource>[snapshot.playbackSource],
        );
      }
    } catch (_) {}
  }

  Future<void> _persistLaunchSnapshot(
    VideoFeedMode mode,
    VideoModel headVideo,
  ) async {
    try {
      final file = await _launchSnapshotFile(mode);
      await file.writeAsString(jsonEncode(headVideo.toJson()), flush: true);
    } catch (_) {}
  }

  void _focusPublishedVideo(PendingPublishedVideo video) {
    final targetMode = video.contentOrientation == 'landscape'
        ? VideoFeedMode.landscape
        : VideoFeedMode.portrait;
    final targetList = _videosByMode[targetMode]!;
    final targetIndex = targetList.indexWhere(
      (item) =>
          item.publishJobId == video.jobId ||
          item.primaryPlaybackUrl == video.primaryPlaybackUrl,
    );
    if (targetIndex == -1) {
      return;
    }

    if (_currentFeedMode != targetMode) {
      _switchFeedMode(targetMode);
    }

    setState(() {
      _currentIndexByMode[targetMode] = targetIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_currentFeedMode != targetMode) {
        _replacePageController(targetIndex);
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
      _syncFocusForCurrentFeed();
    });
  }

  void _upsertPendingVideo(PendingPublishedVideo pendingVideo) {
    final targetMode = pendingVideo.contentOrientation == 'landscape'
        ? VideoFeedMode.landscape
        : VideoFeedMode.portrait;
    final targetList = _videosByMode[targetMode]!;
    final pendingModel = _videoModelFromPublishedVideo(pendingVideo);
    final existingIndex = targetList.indexWhere(
      (video) => video.publishJobId == pendingVideo.jobId,
    );
    setState(() {
      if (existingIndex == -1) {
        final insertIndex = targetMode == _currentFeedMode
            ? (_currentIndexByMode[targetMode]! + 1).clamp(0, targetList.length)
            : 0;
        targetList.insert(insertIndex, pendingModel);
      } else {
        targetList[existingIndex] = pendingModel;
      }
      _loadedByMode[targetMode] = true;
      if (_currentFeedMode == targetMode) {
        _isLoading = false;
      }
    });
  }

  VideoModel _videoModelFromPublishedVideo(PendingPublishedVideo video) {
    return VideoModel(
      url: video.primaryPlaybackUrl,
      primaryPlaybackUrl: video.primaryPlaybackUrl,
      coverUrl: video.coverUrl,
      authorName: video.authorName,
      description: video.description,
      width: video.width,
      height: video.height,
      contentOrientation: video.contentOrientation,
      distributionChannelLabel: video.distributionChannelLabel,
      primaryDistributionLabel: video.primaryDistributionLabel,
      statusLabel: video.statusLabel,
      isPending: video.isPending,
      isFailed: video.isFailed,
      publishJobId: video.jobId,
      pendingMessage: video.pendingMessage,
      errorMessage: video.errorMessage,
    );
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
        if (_publishOverlayStore.state.isVisible)
          Positioned(
            top: 86,
            left: 16,
            child: _buildPublishOverlay(),
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
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }

    if (_errorMessage != null && _videos.isEmpty) {
      return Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (_videos.isEmpty) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
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
          // #region debug-point B:page-changed
          unawaited(
            _debugFeedProbe(
              'B',
              'video_feed_screen.dart:onPageChanged',
              'feed_page_changed',
              data: <String, Object?>{
                'mode': _currentFeedMode.name,
                'index': index,
                'videoCount': _videos.length,
                'elapsedMs': _screenStopwatch.elapsedMilliseconds,
              },
            ),
          );
          // #endregion
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

  Widget _buildPublishOverlay() {
    final state = _publishOverlayStore.state;
    final isCompleted = state.stage == PublishOverlayStage.completed;
    final isFailed = state.stage == PublishOverlayStage.failed;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Column(
          key: ValueKey(state.stage),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted ? Colors.white : Colors.transparent,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.black, size: 12)
                        : isFailed
                            ? const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              )
                            : const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    isCompleted
                        ? state.message
                        : isFailed
                            ? (state.error ?? state.message)
                            : state.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (isCompleted && state.completedVideo != null) ...[
              const SizedBox(height: 10),
              _buildOverlayAction(
                label: '查看作品',
                filled: true,
                onTap: () => _focusPublishedVideo(state.completedVideo!),
              ),
            ],
            if (isFailed && state.jobId != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildOverlayAction(
                    label: '重试',
                    filled: true,
                    onTap: () => _publishOverlayStore.retryFailedPublish(
                      state.jobId!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildOverlayAction(
                    label: '关闭',
                    onTap: () => _publishOverlayStore.dismissFailure(
                      state.jobId!,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayAction({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
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
  bool _lastShowVideo = false;
  bool _didLogInitialTextureState = false;

  @override
  Widget build(BuildContext context) {
    // 物理级映射：根据真实 index 获取底层被分配的常驻 C++ 引擎槽位
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
              if (showVideo && !_lastShowVideo) {
                // #region debug-point C:first-frame-visible
                unawaited(
                  _debugFeedProbe(
                    'C',
                    'video_feed_screen.dart:_VideoPlayerItem',
                    'feed_first_frame_visible',
                    data: <String, Object?>{
                      'index': widget.index,
                      'isActive': widget.isActive,
                      'sourceKey': widget.video.playbackSourceKey,
                    },
                  ),
                );
                // #endregion
              }
              if (!showVideo && _lastShowVideo) {
                // #region debug-point E:first-frame-lost
                unawaited(
                  _debugFeedProbe(
                    'E',
                    'video_feed_screen.dart:_VideoPlayerItem',
                    'feed_visual_lost',
                    data: <String, Object?>{
                      'index': widget.index,
                      'isActive': widget.isActive,
                      'sourceKey': widget.video.playbackSourceKey,
                    },
                  ),
                );
                // #endregion
              }
              _lastShowVideo = showVideo;
              if (!_didLogInitialTextureState && widget.isActive) {
                _didLogInitialTextureState = true;
                unawaited(
                  _debugFeedProbe(
                    'C',
                    'video_feed_screen.dart:_VideoPlayerItem',
                    'active_slot_texture_state',
                    data: <String, Object?>{
                      'index': widget.index,
                      'showVideo': showVideo,
                      'sourceKey': widget.video.playbackSourceKey,
                      'videoWidth': videoWidth,
                      'videoHeight': videoHeight,
                      'playerPlaying': player.state.playing,
                      'playerCompleted': player.state.completed,
                      'playerDurationMs': player.state.duration.inMilliseconds,
                      'playerPositionMs': player.state.position.inMilliseconds,
                      'playerWidth': player.state.width,
                      'playerHeight': player.state.height,
                    },
                  ),
                );
              }
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

          if (widget.video.isPending)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                      widget.video.errorMessage ?? '网络或上传中断，可直接重试',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: widget.video.publishJobId == null
                          ? null
                          : () =>
                              PublishOverlayStore.instance.retryFailedPublish(
                                widget.video.publishJobId!,
                              ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
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
                    _buildMetaBadge(
                      widget.video.isPending
                          ? widget.video.pendingMessage
                          : widget.video.isFailed
                              ? '可重试'
                              : widget.video.primaryDistributionLabel,
                    ),
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
                  const SizedBox(height: 20),
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
                ],
                // 发布/添加视频按钮，作为最顶端的UI设计重构，放在最末尾
                GestureDetector(
                  onTap: () async {
                    if (SupabaseService.currentSession == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请先登录后再发布视频')),
                      );
                      return;
                    }
                    CameraWarmupLease? warmLease;
                    try {
                      warmLease = await CameraWarmupService.instance
                          .takeWarmController(
                        userInitiated: true,
                      );
                    } catch (_) {}
                    if (!context.mounted) {
                      return;
                    }
                    context.pushImmersive<void>(
                      builder: (context) =>
                          VideoUploadScreen(initialWarmLease: warmLease),
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
