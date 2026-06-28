import 'dart:io';
import 'dart:collection';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// 顶级商业级磁盘视频缓存引擎 (Commercial-Grade LRU Disk Cache)
/// 具备 LRU (最近最少使用) 淘汰算法、容量上限防爆机制、并发下载锁
class DiskVideoCacheManager {
  static final DiskVideoCacheManager instance = DiskVideoCacheManager._();
  DiskVideoCacheManager._();

  final Dio _dio = Dio();
  Directory? _cacheDir;
  final Set<String> _downloading = {};
  
  // 核心：使用 LinkedHashMap 实现 LRU 淘汰算法 (按插入和访问顺序排序)
  // 头部是最旧的 (即将被淘汰)，尾部是最新的
  final LinkedHashMap<String, String> _lruCache = LinkedHashMap<String, String>();

  // 商业级参数设定
  static const int maxCacheFiles = 100; // 最多缓存 100 个视频 (约 150MB-200MB)

  bool _isInitialized = false;

  /// 初始化缓存引擎并恢复 LRU 状态
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory('${tempDir.path}/video_cache_v2'); // 升级目录，废弃旧的无序缓存
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      } else {
        // 挂载已有的本地磁盘缓存，并按文件的最后修改时间进行 LRU 排序
        final files = _cacheDir!.listSync().whereType<File>().where((f) => f.path.endsWith('.mp4')).toList();
        
        // 按最后修改时间升序排列 (旧的在前，新的在后)
        files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
        
        for (var file in files) {
          _lruCache[file.path] = file.path;
        }
        
        // 启动时触发一次静默清理，防止上次崩溃导致超限
        _evictIfNeeded();
      }
      _isInitialized = true;
      debugPrint('【DiskCache】商业级视频缓存引擎初始化完成，当前挂载文件数: ${_lruCache.length}/$maxCacheFiles');
    } catch (e) {
      debugPrint('【DiskCache】初始化失败: $e');
    }
  }

  /// 获取 URL 映射的本地绝对路径
  String _getFilePath(String url) {
    // 简单高效的 URL 哈希映射
    final fileName = '${url.hashCode}.mp4';
    return '${_cacheDir!.path}/$fileName';
  }

  /// 预加载调度入口 (Fire and Forget)
  void preload(List<String> urls) {
    if (!_isInitialized || _cacheDir == null) return;
    for (var url in urls) {
      _download(url);
    }
  }

  /// 执行静默下载写入
  Future<void> _download(String url) async {
    if (url.startsWith('file://') || url.startsWith('assets/')) return;
    
    final filePath = _getFilePath(url);
    
    // 如果已经下载完毕，直接跳过 (不更新 LRU，因为后台预加载不代表用户真正看了)
    if (_lruCache.containsKey(filePath) && File(filePath).existsSync()) {
      return;
    }
    
    // 正在下载中的锁，防止重复并发请求 (防止网速抢占)
    if (_downloading.contains(url)) return;
    _downloading.add(url);

    try {
      // 极限压榨网速，直接写入磁盘临时文件
      final tempFilePath = '$filePath.downloading';
      await _dio.download(url, tempFilePath);
      
      // 下载完成后重命名，确保播放器读取时文件是完整的 (原子操作防撕裂)
      File(tempFilePath).renameSync(filePath);
      
      // 写入 LRU 缓存并触发淘汰检测
      _lruCache[filePath] = filePath;
      _evictIfNeeded();
      
    } catch (e) {
      // 下载中断，清理残留的碎片文件
      final tempFile = File('$filePath.downloading');
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    } finally {
      _downloading.remove(url);
    }
  }

  /// 拦截器：向上层返回可直接播放的 URL，并刷新 LRU 权重
  String getPlayableUrl(String originalUrl) {
    if (!_isInitialized || originalUrl.startsWith('file://')) return originalUrl;
    
    final filePath = _getFilePath(originalUrl);
    if (_lruCache.containsKey(filePath) && File(filePath).existsSync()) {
      // 【核心 LRU 逻辑】：用户真实观看了这个视频，权重拉满，移动到队列最末尾！
      // 这保证了用户反复回看的视频，永远不会被淘汰出硬盘。
      _lruCache.remove(filePath);
      _lruCache[filePath] = filePath;
      
      // 终极秒开：直接投喂本地磁盘物理文件
      return 'file:///$filePath';
    }
    
    // 兜底降级：如果用户滑得太快（预加载没赶上），走普通网络流
    return originalUrl;
  }
  
  /// LRU 淘汰算法 (残酷抹杀机制)
  void _evictIfNeeded() {
    while (_lruCache.length > maxCacheFiles) {
      // 取出队列头部最旧的文件 (最久未被观看的)
      final oldestFilePath = _lruCache.keys.first;
      _lruCache.remove(oldestFilePath);
      
      try {
        final file = File(oldestFilePath);
        if (file.existsSync()) {
          file.deleteSync();
          debugPrint('【DiskCache】LRU 触发: 物理抹杀极旧缓存文件 -> $oldestFilePath');
        }
      } catch (e) {
        debugPrint('【DiskCache】LRU 删除失败: $e');
      }
    }
  }
}
