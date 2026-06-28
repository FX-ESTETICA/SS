import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:core_media/core_media.dart'; // 引入我们刚才写的底层处理引擎
import 'package:video_player_win/video_player_win.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core_network/core_network.dart';

/// 15秒时间轴截取与转码编辑器
class VideoEditorScreen extends ConsumerStatefulWidget {
  final File file;

  const VideoEditorScreen({super.key, required this.file});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late final VideoEditorController _controller;
  bool _isExporting = false;
  String _exportStatus = '';

  String _guessContentType(String path, {required String fallback}) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.mp4')) return 'video/mp4';
    if (lowerPath.endsWith('.mov')) return 'video/quicktime';
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      WindowsVideoPlayer.registerWith();
    }
    // 初始化控制器：强制最大截取时间为 15 秒 (核心红线)
    _controller = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 15),
    );

    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((error) {
      debugPrint('VideoEditorController init error: $error');
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
      final session = SupabaseService.currentSession;
      final user = SupabaseService.currentUser;
      if (session == null || user == null) {
        throw Exception('请先登录后再上传和发布视频');
      }

      IdentityHub? identityHub =
          ref.read(identityControllerProvider).asData?.value;
      if (identityHub == null) {
        await ref.read(identityControllerProvider.notifier).refresh();
        identityHub = ref.read(identityControllerProvider).asData?.value;
      }
      if (identityHub == null) {
        throw Exception('身份系统尚未准备完成，请稍后重试');
      }

      // 1. 获取用户在时间轴上截取的起止时间 (秒)
      final double start = _controller.startTrim.inMilliseconds / 1000.0;
      final double end = _controller.endTrim.inMilliseconds / 1000.0;
      final double duration = end - start;

      // 2. 获取用户选定的封面所在秒数
      final double coverTime = _controller.selectedCoverVal?.timeMs != null
          ? _controller.selectedCoverVal!.timeMs / 1000.0
          : start;

      // 3. 调用我们封装的底层 C++/FFmpeg 引擎进行硬件转码
      final result = await VideoProcessor.transcodeAndExtractCover(
        sourcePath: widget.file.path,
        startTimeSeconds: start,
        coverTimeSeconds: coverTime,
        maxDurationSeconds:
            duration.toInt() == 0 ? 1 : duration.toInt(), // 实际截取的长度 (最大15s)
      );

      if (result != null) {
        setState(() {
          _exportStatus = '转码成功！正在上传至云端节点...';
        });

        final videoBytes = await result.videoFile.readAsBytes();
        final videoFileName =
            'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final coverFile = result.coverFile;

        final videoUpload = await SupabaseService.uploadMedia(
          fileName: videoFileName,
          fileBytes: videoBytes,
          mediaKind: 'video',
          accessToken: session.accessToken,
          contentType: _guessContentType(
            result.videoFile.path,
            fallback: 'video/mp4',
          ),
        );

        UploadedMedia? coverUpload;
        if (coverFile != null && await coverFile.exists()) {
          final coverBytes = await coverFile.readAsBytes();
          final coverFileName =
              'cover_${DateTime.now().millisecondsSinceEpoch}.webp';
          coverUpload = await SupabaseService.uploadMedia(
            fileName: coverFileName,
            fileBytes: coverBytes,
            mediaKind: 'cover',
            accessToken: session.accessToken,
            contentType: _guessContentType(
              coverFile.path,
              fallback: 'image/webp',
            ),
          );
        }

        setState(() {
          _exportStatus = '上传完成，正在发布动态...';
        });

        final activeIdentity = identityHub.activeIdentity;
        final authorName = activeIdentity.displayName.trim().isNotEmpty
            ? activeIdentity.displayName
            : (user.email?.split('@').first ?? '匿名用户');

        await SupabaseService.publishVideo(
          videoUpload: videoUpload,
          coverUpload: coverUpload,
          description: '刚刚通过智选超级 APP 极限压缩上传了这条视频！🚀',
          authorId: user.id,
          authorIdentityId: activeIdentity.id,
          authorName: authorName,
          durationSeconds: duration <= 0 ? 1 : duration,
        );

        setState(() {
          _exportStatus = '发布成功！';
        });

        // 等待1秒后返回
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context); // 返回上一页
        }
      } else {
        setState(() {
          _exportStatus = '转码失败，请检查视频格式';
        });
      }
    } catch (e) {
      debugPrint('Export error: $e');
      setState(() {
        _exportStatus = '发生错误: $e';
      });
      // 延迟 3 秒让用户看到错误信息
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
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
                                    _controller.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: TrimSlider(
                                controller: _controller,
                                height: 60,
                                horizontalMargin: 0,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // 核心：封面抽取选择器
                            const Text(
                              '滑动选择封面 (将抽取为高清 WebP)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 40,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                            const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _exportStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                height: 1.5,
                              ),
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
          const Text(
            '截取 15 秒',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          GestureDetector(
            onTap: _isExporting ? null : _exportVideo,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white, // 纯白发布按钮
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '发布',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
