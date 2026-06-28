import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'disk_cache_manager.dart'; // 引入磁盘级缓存调度中心

/// 核心域：短视频底层引擎池 (Ring Buffer)
/// 彻底接管 C++ 播放器生命周期，消灭 UI 滚动时的创建/销毁开销
class VideoEnginePool {
  static final VideoEnginePool instance = VideoEnginePool._internal();
  VideoEnginePool._internal();

  // 严格限制为 3 个实例：上一个、当前、下一个
  static const int poolSize = 3;

  final List<Player> _players = [];
  final List<VideoController> _controllers = [];

  // 记录当前每个底层播放器加载的 URL，防止重复 open 引发 IO 阻塞
  final List<String?> _loadedUrls = List.filled(poolSize, null);

  bool _isInitialized = false;

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

  /// 核心状态机：滑动窗口预加载调度 (终极重构版 - 结合磁盘预读)
  void focusIndex(int currentIndex, List<String> videoUrls) {
    if (videoUrls.isEmpty || !_isInitialized) return;

    // 0. 触发本地磁盘极限预加载 (Fire and Forget)
    // 提前抓取当前及后面 3 个视频，丢给后台 Dio 线程去静默下载到硬盘
    final preloadUrls = videoUrls.skip(currentIndex).take(4).toList();
    DiskVideoCacheManager.instance.preload(preloadUrls);

    // 1. 绝对优先保证当前焦点视频的播放 (The Absolute Priority)
    final currentPoolIndex = currentIndex % poolSize;
    final currentPlayer = _players[currentPoolIndex];
    final currentUrl = videoUrls[currentIndex];

    if (_loadedUrls[currentPoolIndex] != currentUrl) {
      // 拦截器：向磁盘管理器请求终极播放地址
      // 如果已经预下载完了，这里返回的就是 file:/// 绝对路径（0延迟，无网络开销）
      final playUrl = DiskVideoCacheManager.instance.getPlayableUrl(currentUrl);
      
      // 焦点视频发生了物理替换，直接暴力 open 并播放
      currentPlayer.open(Media(playUrl), play: true);
      _loadedUrls[currentPoolIndex] = currentUrl;
    } else {
      // 已经在内存中，瞬间拉起
      currentPlayer.play();
    }

    // 2. 异步静默处理池内前后指针的 C++ 引擎准备
    // 延迟 100ms 执行，把极其宝贵的 I/O 和 CPU 算力绝对让给当前视频的第一帧解码
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isInitialized) return;
      
      // 准备前一个和后一个视频的引擎状态
      for (int i = -1; i <= 1; i++) {
        if (i == 0) continue; // 当前焦点刚才已经处理过了

        final targetIndex = currentIndex + i;
        if (targetIndex < 0 || targetIndex >= videoUrls.length) continue;

        final poolIndex = targetIndex % poolSize;
        final player = _players[poolIndex];
        final url = videoUrls[targetIndex];

        if (_loadedUrls[poolIndex] != url) {
          final playUrl = DiskVideoCacheManager.instance.getPlayableUrl(url);
          // 预加载视频：静音、不自动播放、让底层去嗅探 metadata
          player.open(Media(playUrl), play: false);
          _loadedUrls[poolIndex] = url;
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

  void dispose() {
    for (var p in _players) {
      p.dispose();
    }
    _players.clear();
    _controllers.clear();
    _loadedUrls.fillRange(0, poolSize, null);
    _isInitialized = false;
  }
}
