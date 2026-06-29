import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'disk_cache_manager.dart'; // 引入磁盘级缓存调度中心

// #region debug-point B:video-pool-probe
Future<void> _debugVideoPoolProbe(
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

class VideoPlaybackSource {
  final String primaryUrl;
  final String? playableUrlOverride;

  const VideoPlaybackSource({
    required this.primaryUrl,
    this.playableUrlOverride,
  });

  String get sourceKey => primaryUrl;
}

enum VideoSlotLoadState {
  idle,
  opening,
  ready,
  failed,
}

/// 核心域：短视频底层引擎池 (Ring Buffer)
/// 彻底接管 C++ 播放器生命周期，消灭 UI 滚动时的创建/销毁开销
class VideoEnginePool {
  static final VideoEnginePool instance = VideoEnginePool._internal();
  VideoEnginePool._internal();

  // 升级为 5 路实例：上二、上一、当前、下一、下二
  static const int poolSize = 5;
  static const Duration _playbackOpenTimeout = Duration(milliseconds: 2500);
  static const Duration _preloadOpenTimeout = Duration(milliseconds: 1500);
  static const Duration _renderablePlaybackWaitTimeout = Duration(seconds: 8);
  static const Duration _renderablePreloadWaitTimeout = Duration(seconds: 4);
  static const Duration _renderablePollInterval = Duration(milliseconds: 33);

  final List<Player> _players = [];
  final List<VideoController> _controllers = [];

  // 记录当前每个底层播放器加载的 URL，防止重复 open 引发 IO 阻塞
  final List<String?> _loadedSourceKeys = List.filled(poolSize, null);
  final List<bool> _visualReady = List.filled(poolSize, false);
  final List<VideoSlotLoadState> _slotLoadStates = List.filled(
    poolSize,
    VideoSlotLoadState.idle,
  );
  final ValueNotifier<int> _stateVersion = ValueNotifier<int>(0);

  bool _isInitialized = false;
  int _focusGeneration = 0;
  int? _lastFocusedIndex;

  void initialize() {
    if (_isInitialized) return;
    // #region debug-point B:pool-init
    unawaited(
      _debugVideoPoolProbe(
        'B',
        'video_engine_pool.dart:initialize',
        'player_pool_initialize_start',
        data: <String, Object?>{
          'poolSize': poolSize,
        },
      ),
    );
    // #endregion

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
    // #region debug-point B:pool-init-ready
    unawaited(
      _debugVideoPoolProbe(
        'B',
        'video_engine_pool.dart:initialize',
        'player_pool_initialize_ready',
        data: <String, Object?>{
          'playerCount': _players.length,
        },
      ),
    );
    // #endregion
  }

  VideoController getController(int index) => _controllers[index % poolSize];
  Player getPlayer(int index) => _players[index % poolSize];
  ValueListenable<int> get stateVersion => _stateVersion;

  bool isVisualReady(int index, String sourceKey) {
    final poolIndex = index % poolSize;
    return _loadedSourceKeys[poolIndex] == sourceKey && _visualReady[poolIndex];
  }

  VideoSlotLoadState getLoadState(int index, String sourceKey) {
    final poolIndex = index % poolSize;
    if (_loadedSourceKeys[poolIndex] != sourceKey) {
      return VideoSlotLoadState.idle;
    }
    return _slotLoadStates[poolIndex];
  }

  void _notifyStateChanged() {
    _stateVersion.value++;
  }

  bool _hasRenderableVideoSize(Player player) {
    final width = player.state.width;
    final height = player.state.height;
    return width != null && height != null && width > 0 && height > 0;
  }

  Future<bool> _waitForRenderableVideoSize(
    Player player, {
    required bool play,
  }) async {
    final timeout =
        play ? _renderablePlaybackWaitTimeout : _renderablePreloadWaitTimeout;
    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      if (_hasRenderableVideoSize(player)) {
        return true;
      }
      await Future.delayed(_renderablePollInterval);
    }
    return _hasRenderableVideoSize(player);
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
    final focusTraceId = 'focus-$focusGeneration-$currentIndex';
    // #region debug-point B:focus-index
    unawaited(
      _debugVideoPoolProbe(
        'B',
        'video_engine_pool.dart:focusIndex',
        'focus_index_requested',
        traceId: focusTraceId,
        data: <String, Object?>{
          'currentIndex': currentIndex,
          'lastFocusedIndex': lastFocusedIndex,
          'sourceCount': playbackSources.length,
        },
      ),
    );
    // #endregion

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

    final shouldOpenCurrent =
        _loadedSourceKeys[currentPoolIndex] != currentSource.sourceKey ||
            _slotLoadStates[currentPoolIndex] == VideoSlotLoadState.failed ||
            _slotLoadStates[currentPoolIndex] == VideoSlotLoadState.idle;
    if (shouldOpenCurrent) {
      _loadedSourceKeys[currentPoolIndex] = currentSource.sourceKey;
      _visualReady[currentPoolIndex] = false;
      _slotLoadStates[currentPoolIndex] = VideoSlotLoadState.opening;
      _notifyStateChanged();
      // #region debug-point B:focus-open-current
      unawaited(
        _debugVideoPoolProbe(
          'B',
          'video_engine_pool.dart:focusIndex',
          'focus_open_current_slot',
          traceId: focusTraceId,
          data: <String, Object?>{
            'poolIndex': currentPoolIndex,
            'sourceKey': currentSource.sourceKey,
          },
        ),
      );
      // #endregion

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
      // #region debug-point B:focus-reuse-current
      unawaited(
        _debugVideoPoolProbe(
          'B',
          'video_engine_pool.dart:focusIndex',
          'focus_reuse_loaded_slot',
          traceId: focusTraceId,
          data: <String, Object?>{
            'poolIndex': currentPoolIndex,
            'sourceKey': currentSource.sourceKey,
          },
        ),
      );
      // #endregion
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

        final shouldPreload =
            _loadedSourceKeys[poolIndex] != source.sourceKey ||
                _slotLoadStates[poolIndex] == VideoSlotLoadState.failed ||
                _slotLoadStates[poolIndex] == VideoSlotLoadState.idle;
        if (shouldPreload) {
          _loadedSourceKeys[poolIndex] = source.sourceKey;
          _visualReady[poolIndex] = false;
          _slotLoadStates[poolIndex] = VideoSlotLoadState.opening;
          _notifyStateChanged();
          // #region debug-point B:preload-open-slot
          unawaited(
            _debugVideoPoolProbe(
              'B',
              'video_engine_pool.dart:focusIndex',
              'preload_open_slot',
              traceId: focusTraceId,
              data: <String, Object?>{
                'targetIndex': targetIndex,
                'poolIndex': poolIndex,
                'sourceKey': source.sourceKey,
              },
            ),
          );
          // #endregion
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
          // #region debug-point B:preload-reuse-slot
          unawaited(
            _debugVideoPoolProbe(
              'B',
              'video_engine_pool.dart:focusIndex',
              'preload_reuse_slot',
              traceId: focusTraceId,
              data: <String, Object?>{
                'targetIndex': targetIndex,
                'poolIndex': poolIndex,
                'sourceKey': source.sourceKey,
              },
            ),
          );
          // #endregion
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

  void retrySlot(int index, VideoPlaybackSource source, {bool play = true}) {
    if (!_isInitialized) return;
    final focusGeneration = ++_focusGeneration;
    _lastFocusedIndex = index;
    final poolIndex = index % poolSize;
    for (int i = 0; i < poolSize; i++) {
      if (i != poolIndex) {
        _players[i].pause();
      }
    }
    _loadedSourceKeys[poolIndex] = source.sourceKey;
    _visualReady[poolIndex] = false;
    _slotLoadStates[poolIndex] = VideoSlotLoadState.opening;
    _notifyStateChanged();
    unawaited(
      _openSourceForSlot(
        poolIndex: poolIndex,
        player: _players[poolIndex],
        source: source,
        focusGeneration: focusGeneration,
        play: play,
      ),
    );
  }

  Future<void> _openSourceForSlot({
    required int poolIndex,
    required Player player,
    required VideoPlaybackSource source,
    required int focusGeneration,
    required bool play,
  }) async {
    final currentSourceKey = source.sourceKey;
    final primaryPlayableUrl = source.playableUrlOverride ??
        DiskVideoCacheManager.instance.getPlayableUrl(source.primaryUrl);
    final openTimeout = _resolveOpenTimeout(source, play);
    final openTraceId =
        'slot-$poolIndex-$focusGeneration-${DateTime.now().microsecondsSinceEpoch}';
    final openStopwatch = Stopwatch()..start();
    // #region debug-point C:open-start
    unawaited(
      _debugVideoPoolProbe(
        'C',
        'video_engine_pool.dart:_openSourceForSlot',
        'open_source_start',
        traceId: openTraceId,
        data: <String, Object?>{
          'poolIndex': poolIndex,
          'focusGeneration': focusGeneration,
          'play': play,
          'sourceKey': currentSourceKey,
          'primaryUrl': source.primaryUrl,
          'primaryPlayableUrl': primaryPlayableUrl,
          'openTimeoutMs': openTimeout.inMilliseconds,
        },
      ),
    );
    // #endregion

    Future<void> markReadyIfCurrent() async {
      if (!_isInitialized) return;
      if (_loadedSourceKeys[poolIndex] != currentSourceKey) return;
      _visualReady[poolIndex] = true;
      _slotLoadStates[poolIndex] = VideoSlotLoadState.ready;
      _notifyStateChanged();
      // #region debug-point C:visual-ready
      unawaited(
        _debugVideoPoolProbe(
          'C',
          'video_engine_pool.dart:markReadyIfCurrent',
          'slot_visual_ready',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'focusGeneration': focusGeneration,
            'elapsedMs': openStopwatch.elapsedMilliseconds,
            'sourceKey': currentSourceKey,
          },
        ),
      );
      // #endregion
    }

    Future<void> markFailedIfCurrent() async {
      if (_loadedSourceKeys[poolIndex] != currentSourceKey) return;
      _visualReady[poolIndex] = false;
      _slotLoadStates[poolIndex] = VideoSlotLoadState.failed;
      _notifyStateChanged();
      // #region debug-point E:visual-failed
      unawaited(
        _debugVideoPoolProbe(
          'E',
          'video_engine_pool.dart:markFailedIfCurrent',
          'slot_visual_failed',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'focusGeneration': focusGeneration,
            'elapsedMs': openStopwatch.elapsedMilliseconds,
            'sourceKey': currentSourceKey,
          },
        ),
      );
      // #endregion
    }

    try {
      await player
          .open(Media(primaryPlayableUrl), play: play)
          .timeout(openTimeout);
      // #region debug-point C:open-primary-success
      unawaited(
        _debugVideoPoolProbe(
          'C',
          'video_engine_pool.dart:_openSourceForSlot',
          'open_primary_success',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'elapsedMs': openStopwatch.elapsedMilliseconds,
            'play': play,
            'playableUrl': primaryPlayableUrl,
            'sourceKey': currentSourceKey,
          },
        ),
      );
      // #endregion
      // #region debug-point C:player-state-after-open
      unawaited(
        _debugVideoPoolProbe(
          'C',
          'video_engine_pool.dart:_openSourceForSlot',
          'player_state_after_open',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'sourceKey': currentSourceKey,
            'playlistIndex': player.state.playlist.index,
            'playing': player.state.playing,
            'completed': player.state.completed,
            'durationMs': player.state.duration.inMilliseconds,
            'positionMs': player.state.position.inMilliseconds,
            'width': player.state.width,
            'height': player.state.height,
          },
        ),
      );
      // #endregion
      final renderableReady = await _waitForRenderableVideoSize(
        player,
        play: play,
      );
      // #region debug-point C:renderable-size-check
      unawaited(
        _debugVideoPoolProbe(
          'C',
          'video_engine_pool.dart:_openSourceForSlot',
          renderableReady
              ? 'renderable_video_size_ready'
              : 'renderable_video_size_timeout',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'sourceKey': currentSourceKey,
            'play': play,
            'elapsedMs': openStopwatch.elapsedMilliseconds,
            'width': player.state.width,
            'height': player.state.height,
            'durationMs': player.state.duration.inMilliseconds,
            'positionMs': player.state.position.inMilliseconds,
          },
        ),
      );
      // #endregion
      if (!renderableReady) {
        await markFailedIfCurrent();
        return;
      }
      await markReadyIfCurrent();
    } catch (error) {
      // #region debug-point C:open-primary-fail
      unawaited(
        _debugVideoPoolProbe(
          'C',
          'video_engine_pool.dart:_openSourceForSlot',
          'open_primary_fail',
          traceId: openTraceId,
          data: <String, Object?>{
            'poolIndex': poolIndex,
            'elapsedMs': openStopwatch.elapsedMilliseconds,
            'play': play,
            'playableUrl': primaryPlayableUrl,
            'sourceKey': currentSourceKey,
            'error': error.toString(),
            'errorType': error.runtimeType.toString(),
          },
        ),
      );
      // #endregion
      await markFailedIfCurrent();
    }
  }

  Duration _resolveOpenTimeout(VideoPlaybackSource source, bool play) {
    return play ? _playbackOpenTimeout : _preloadOpenTimeout;
  }

  void dispose() {
    for (var p in _players) {
      p.dispose();
    }
    _players.clear();
    _controllers.clear();
    _loadedSourceKeys.fillRange(0, poolSize, null);
    _visualReady.fillRange(0, poolSize, false);
    _slotLoadStates.fillRange(0, poolSize, VideoSlotLoadState.idle);
    _isInitialized = false;
    _lastFocusedIndex = null;
    _stateVersion.value = 0;
  }
}
