import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:core_media/core_media.dart'; // 引入我们刚才写的底层处理引擎

/// 15秒时间轴截取与转码编辑器
class VideoEditorScreen extends StatefulWidget {
  final File file;

  const VideoEditorScreen({super.key, required this.file});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late final VideoEditorController _controller;
  bool _isExporting = false;
  String _exportStatus = '';

  @override
  void initState() {
    super.initState();
    // 初始化控制器：强制最大截取时间为 15 秒 (核心红线)
    _controller = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 15),
    );

    _controller.initialize().then((_) => setState(() {})).catchError((error) {
      // 处理无法解码的视频格式
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 核心逻辑：触发端侧转码与上传
  Future<void> _exportVideo() async {
    setState(() {
      _isExporting = true;
      _exportStatus = '正在压榨手机算力转码中...';
    });

    try {
      // 1. 获取用户在时间轴上截取的起止时间 (秒)
      final double start = _controller.minTrim; // video_editor 返回的直接是 double 类型的比例/秒数
      final double end = _controller.maxTrim;
      final double duration = end - start;
      
      // 2. 获取用户选定的封面所在秒数
      final double coverTime = _controller.selectedCoverVal?.timeMs != null 
          ? _controller.selectedCoverVal!.timeMs / 1000.0 
          : start;

      // 3. 调用我们封装的底层 C++/FFmpeg 引擎进行硬件转码
      final result = await VideoProcessor.transcodeAndExtractCover(
        sourcePath: widget.file.path,
        coverTimeSeconds: coverTime,
        maxDurationSeconds: duration.toInt(), // 实际截取的长度 (最大15s)
      );

      if (result != null) {
        // 转码成功，拿到了极限压缩的 .mp4 和 高清 .webp 封面
        // 接下来就可以直接把这两个 File 上传到 Cloudflare R2 了！
        setState(() {
          _exportStatus = '转码成功！\n视频大小已极限压缩\n封面已抽取';
        });
        
        // 演示用：等待2秒后返回
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context); // 返回上一页
        }
      } else {
        setState(() {
          _exportStatus = '转码失败，请检查视频格式';
        });
      }
    } catch (e) {
      setState(() {
        _exportStatus = '发生错误: $e';
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 编辑器必须是纯黑环境
      body: _controller.initialized
          ? SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildTopBar(),
                      // 视频预览区
                      Expanded(
                        child: CropGridViewer.preview(controller: _controller),
                      ),
                      // 底部编辑控制区
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 控制按钮 (播放/暂停)
                            AnimatedBuilder(
                              animation: _controller.video,
                              builder: (_, __) {
                                return IconButton(
                                  onPressed: () {
                                    if (_controller.isPlaying) {
                                      _controller.video.pause();
                                    } else {
                                      _controller.video.play();
                                    }
                                  },
                                  icon: Icon(
                                    _controller.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            // 核心：15秒时间轴截取器
                            Container(
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: TrimSlider(
                                controller: _controller,
                                height: 60,
                                horizontalMargin: 0,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 核心：封面抽取选择器
                            const Text('滑动选择封面 (将抽取为高清 WebP)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              height: 40,
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              child: CoverSelection(
                                controller: _controller,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 转码中的全屏遮罩
                  if (_isExporting)
                    Container(
                      color: Colors.black.withValues(alpha: 0.8),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(height: 24),
                            Text(
                              _exportStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('截取 15 秒', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          GestureDetector(
            onTap: _isExporting ? null : _exportVideo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white, // 纯白发布按钮
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('发布', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
