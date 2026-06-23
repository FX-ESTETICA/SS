import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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

  /// 核心状态机：滑动窗口预加载调度
  void focusIndex(int currentIndex, List<String> videoUrls) {
    if (videoUrls.isEmpty || !_isInitialized) return;

    // 遍历当前窗口的前中后三个位置
    for (int i = -1; i <= 1; i++) {
      final targetIndex = currentIndex + i;
      // 边界越界保护
      if (targetIndex < 0 || targetIndex >= videoUrls.length) continue;

      final poolIndex = targetIndex % poolSize;
      final player = _players[poolIndex];
      final url = videoUrls[targetIndex];

      // 如果当前槽位的 URL 发生变更，执行底层 I/O 加载
      if (_loadedUrls[poolIndex] != url) {
        // 【终极防卡顿修复】：如果是焦点视频 (i == 0)，必须在 open 时直接传入 play: true。
        // 绝对不能先 open(play: false) 紧接着再调用 play()，这会导致 C++ 底层时序撕裂，引发卡顿和假缓冲！
        player.open(Media(url), play: i == 0);
        _loadedUrls[poolIndex] = url;
      } else {
        // URL 没变，说明已经预热在显存中，直接秒切播放/暂停状态
        if (i == 0) {
          player.play();
        } else {
          player.pause();
        }
      }
    }
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
