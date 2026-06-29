import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'disk_cache_manager.dart'; // 引入磁盘级缓存调度中心

class VideoPlaybackSource {
  final String primaryUrl;
  final String? fallbackUrl;
  final bool prefersStreaming;

  const VideoPlaybackSource({
    required this.primaryUrl,
    this.fallbackUrl,
    this.prefersStreaming = false,
  });

  String get sourceKey => prefersStreaming ? '$primaryUrl|${fallbackUrl ?? ''}' : primaryUrl;
}

/// 核心域：短视频底层引擎池 (Ring Buffer)
/// 彻底接管 C++ 播放器生命周期，消灭 UI 滚动时的创建/销毁开销
class VideoEnginePool {
  static final VideoEnginePool instance = VideoEnginePool._internal();
  VideoEnginePool._internal();

  // 升级为 5 路实例：上二、上一、当前、下一、下二
  static const int poolSize = 5;
  static const Duration _streamPlaybackOpenTimeout = Duration(milliseconds: 1800);
  static const Duration _streamPreloadOpenTimeout = Duration(milliseconds: 1200);
  static const Duration _filePlaybackOpenTimeout = Duration(milliseconds: 2500);
  static const Duration _filePreloadOpenTimeout = Duration(milliseconds: 1500);

  final List<Player> _players = [];
  final List<VideoController> _controllers = [];

  // 记录当前每个底层播放器加载的 URL，防止重复 open 引发 IO 阻塞
  final List<String?> _loadedSourceKeys = List.filled(poolSize, null);
  final List<bool> _visualReady = List.filled(poolSize, false);
  final ValueNotifier<int> _stateVersion = ValueNotifier<int>(0);

  bool _isInitialized = false;
  int _focusGeneration = 0;
  int? _lastFocusedIndex;

  void initialize() {
    if (_isInitialized) return;

    for (int i = 0; i < poolSize; i++) {
      // 预先分配内存缓冲池，开启硬件加速
      final player = Player(
        configuration: const PlayerConfiguration(
          bufferSize: 64 * 1024 * 1024, // 64MB 硬件缓冲
        ),
      );
      // 硬件级循环，不经过 Dart
      player.setPlaylistMode(PlaylistMode.single);

      _players.add(player);
      _controllers.add(VideoController(player));
    }
    _isInitialized = true;
  }

  VideoController getController(int index) => _controllers[index % poolSize];
  Player getPlayer(int index) => _players[index % poolSize];
  ValueListenable<int> get stateVersion => _stateVersion;

  bool isVisualReady(int index, String sourceKey) {
    final poolIndex = index % poolSize;
    return _loadedSourceKeys[poolIndex] == sourceKey && _visualReady[poolIndex];
  }

  void _notifyStateChanged() {
    _stateVersion.value++;
  }

  /// 核心状态机：滑动窗口预加载调度 (终极重构版 - 结合磁盘预读)
  Future<void> focusIndex(
    int currentIndex,
    List<VideoPlaybackSource> playbackSources,
  ) async {
    if (playbackSources.isEmpty || !_isInitialized) return;
    final focusGeneration = ++_focusGeneration;
    final lastFocusedIndex = _lastFocusedIndex;
    _lastFocusedIndex = currentIndex;

    // 0. 触发本地磁盘极限预加载 (Fire and Forget)
    // 提前抓取当前及后面 3 个视频，丢给后台 Dio 线程去静默下载到硬盘
    final preloadSources = playbackSources.skip(currentIndex).take(6).toList();
    DiskVideoCacheManager.instance.preloadPlaybackSources(preloadSources);

    // 1. 绝对优先保证当前焦点视频的播放 (The Absolute Priority)
    final currentPoolIndex = currentIndex % poolSize;
    final currentPlayer = _players[currentPoolIndex];
    final currentSource = playbackSources[currentIndex];

    for (int i = 0; i < poolSize; i++) {
      if (i != currentPoolIndex) {
        _players[i].pause();
      }
    }

    if (_loadedSourceKeys[currentPoolIndex] != currentSource.sourceKey) {
      _loadedSourceKeys[currentPoolIndex] = currentSource.sourceKey;
      _visualReady[currentPoolIndex] = false;
      _notifyStateChanged();

      unawaited(
        _openSourceForSlot(
          poolIndex: currentPoolIndex,
          player: currentPlayer,
          source: currentSource,
          focusGeneration: focusGeneration,
          play: true,
        ),
      );
    } else {
      // 已经在内存中，瞬间拉起
      currentPlayer.play();
    }

    // 2. 异步静默处理池内前后指针的 C++ 引擎准备
    // 延迟 100ms 执行，把极其宝贵的 I/O 和 CPU 算力绝对让给当前视频的第一帧解码
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isInitialized || _focusGeneration != focusGeneration) return;
      
      // 优先根据滑动方向预热将要进入视野的视频，前向刷时先保下一条与下二条
      final preloadOffsets = switch ((lastFocusedIndex, currentIndex)) {
        (final int previous, final int current) when current < previous =>
          <int>[-1, -2, 1, 2],
        _ => <int>[1, 2, -1, -2],
      };

      for (final i in preloadOffsets) {
        if (i == 0) continue; // 当前焦点刚才已经处理过了

        final targetIndex = currentIndex + i;
        if (targetIndex < 0 || targetIndex >= playbackSources.length) continue;

        final poolIndex = targetIndex % poolSize;
        final player = _players[poolIndex];
        final source = playbackSources[targetIndex];

        if (_loadedSourceKeys[poolIndex] != source.sourceKey) {
          _loadedSourceKeys[poolIndex] = source.sourceKey;
          _visualReady[poolIndex] = false;
          _notifyStateChanged();
          unawaited(
            _openSourceForSlot(
              poolIndex: poolIndex,
              player: player,
              source: source,
              focusGeneration: focusGeneration,
              play: false,
            ),
          );
        } else {
          // 如果已经在池子里了，强制确保它是暂停的，绝对不能抢占焦点视频的算力和音频通道
          player.pause();
        }
      }
    });
  }

  /// 在非 Tab 激活时，强制冻结所有实例的解码
  void freezeAll() {
    for (var player in _players) {
      player.pause();
    }
  }

  void togglePlay(int currentIndex) {
    final player = getPlayer(currentIndex);
    player.state.playing ? player.pause() : player.play();
  }

  Future<void> _openSourceForSlot({
    required int poolIndex,
    required Player player,
    required VideoPlaybackSource source,
    required int focusGeneration,
    required bool play,
  }) async {
    final currentSourceKey = source.sourceKey;
    final primaryPlayableUrl = DiskVideoCacheManager.instance.getPlayableUrl(
      source.primaryUrl,
    );
    final openTimeout = _resolveOpenTimeout(source, play);

    Future<void> markReadyIfCurrent() async {
      if (!_isInitialized || _focusGeneration != focusGeneration) return;
      if (_loadedSourceKeys[poolIndex] != currentSourceKey) return;
      _visualReady[poolIndex] = true;
      _notifyStateChanged();
    }

    Future<void> markFailedIfCurrent() async {
      if (_loadedSourceKeys[poolIndex] != currentSourceKey) return;
      _visualReady[poolIndex] = false;
      _notifyStateChanged();
    }

    try {
      await player
          .open(Media(primaryPlayableUrl), play: play)
          .timeout(openTimeout);
      await markReadyIfCurrent();
    } catch (_) {
      final fallbackUrl = source.fallbackUrl;
      if (fallbackUrl == null || fallbackUrl.isEmpty) {
        await markFailedIfCurrent();
        return;
      }

      final fallbackPlayableUrl = DiskVideoCacheManager.instance.getPlayableUrl(
        fallbackUrl,
      );

      try {
        await player
            .open(Media(fallbackPlayableUrl), play: play)
            .timeout(_filePlaybackOpenTimeout);
        await markReadyIfCurrent();
      } catch (_) {
        await markFailedIfCurrent();
      }
    }
  }

  Duration _resolveOpenTimeout(VideoPlaybackSource source, bool play) {
    if (source.prefersStreaming) {
      return play ? _streamPlaybackOpenTimeout : _streamPreloadOpenTimeout;
    }
    return play ? _filePlaybackOpenTimeout : _filePreloadOpenTimeout;
  }

  void dispose() {
    for (var p in _players) {
      p.dispose();
    }
    _players.clear();
    _controllers.clear();
    _loadedSourceKeys.fillRange(0, poolSize, null);
    _visualReady.fillRange(0, poolSize, false);
    _isInitialized = false;
    _lastFocusedIndex = null;
    _stateVersion.value = 0;
  }
}
