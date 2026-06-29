import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:core_media/core_media.dart'; // 引入我们刚才写的底层处理引擎
import 'package:video_player_win/video_player_win.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:core_network/core_network.dart';

enum _VideoAspectPreset {
  portrait(
    label: '9:16',
    ratio: 9 / 16,
    outputLayout: VideoOutputLayout.portrait,
  ),
  landscape(
    label: '16:9',
    ratio: 16 / 9,
    outputLayout: VideoOutputLayout.landscape,
  );

  const _VideoAspectPreset({
    required this.label,
    required this.ratio,
    required this.outputLayout,
  });

  final String label;
  final double ratio;
  final VideoOutputLayout outputLayout;
}

/// 15秒时间轴截取与转码编辑器
class VideoEditorScreen extends ConsumerStatefulWidget {
  final File file;

  const VideoEditorScreen({super.key, required this.file});

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoEditorController? _controller;
  VideoPlayerController? _windowsPreviewController;
  bool _isExporting = false;
  String _exportStatus = '';
  _VideoAspectPreset _selectedAspectPreset = _VideoAspectPreset.portrait;
  bool get _isWindowsDesktop => Platform.isWindows;
  bool get _supportsThumbnailTimeline => !_isWindowsDesktop;
  bool get _isEditorReady => _isWindowsDesktop
      ? (_windowsPreviewController?.value.isInitialized ?? false)
      : (_controller?.initialized ?? false);
  VideoEditorController get _editorController => _controller!;
  VideoPlayerController get _windowsController => _windowsPreviewController!;

  VideoOutputLayout get _currentOutputLayout =>
      _selectedAspectPreset.outputLayout;

  String get _distributionPreviewLabel =>
      _currentOutputLayout.contentOrientation == 'landscape' ? '横屏' : '推荐';

  String get _primaryDistributionPreviewLabel => 'HLS主链';

  String get _fallbackDistributionPreviewLabel => 'MP4兜底';

  String _guessContentType(String path, {required String fallback}) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
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
    if (_isWindowsDesktop) {
      WindowsVideoPlayer.registerWith();
      _initializeWindowsPreview();
      return;
    }
    _initializeTimelineEditor();
  }

  Future<void> _initializeTimelineEditor() async {
    final controller = VideoEditorController.file(
      widget.file,
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 15),
    );
    _controller = controller;

    controller.initialize().then((_) {
      final autoPreset = _resolveAutoAspectPreset(
        sourceWidth: controller.videoWidth,
        sourceHeight: controller.videoHeight,
      );
      controller.cropAspectRatio(autoPreset.ratio);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAspectPreset = autoPreset;
      });
    }).catchError((error) {
      debugPrint('VideoEditorController init error: $error');
      // 处理无法解码的视频格式
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _initializeWindowsPreview() async {
    final controller = VideoPlayerController.file(widget.file);
    _windowsPreviewController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      final sourceSize = controller.value.size;
      final autoPreset = _resolveAutoAspectPreset(
        sourceWidth: sourceSize.width,
        sourceHeight: sourceSize.height,
      );
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _selectedAspectPreset = autoPreset;
      });
    } catch (error) {
      debugPrint('Windows preview init error: $error');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  _VideoAspectPreset _resolveAutoAspectPreset({
    required double sourceWidth,
    required double sourceHeight,
  }) {
    final sourceRatio = sourceWidth / sourceHeight;
    if (!sourceRatio.isFinite) {
      return _VideoAspectPreset.portrait;
    }
    return sourceRatio >= 1
        ? _VideoAspectPreset.landscape
        : _VideoAspectPreset.portrait;
  }

  void _applyAspectPreset(
    _VideoAspectPreset preset, {
    bool updateState = true,
  }) {
    if (!_isWindowsDesktop) {
      _editorController.cropAspectRatio(preset.ratio);
    }
    if (updateState && mounted) {
      setState(() {
        _selectedAspectPreset = preset;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _windowsPreviewController?.dispose();
    super.dispose();
  }

  Duration _resolvedTrimStart() {
    if (_isWindowsDesktop) {
      return Duration.zero;
    }
    return _editorController.startTrim;
  }

  Duration _resolvedTrimEnd() {
    if (!_isWindowsDesktop) {
      return _editorController.endTrim;
    }
    final sourceDuration = _windowsController.value.duration;
    final sourceMs = sourceDuration.inMilliseconds;
    if (sourceMs <= 0) {
      return const Duration(seconds: 1);
    }
    final boundedMs = sourceMs > 15000 ? 15000 : sourceMs;
    return Duration(milliseconds: boundedMs);
  }

  double _resolvedCoverTimeSeconds(double startSeconds) {
    if (_isWindowsDesktop) {
      return startSeconds;
    }
    final coverMs = _editorController.selectedCoverVal?.timeMs;
    if (coverMs == null) {
      return startSeconds;
    }
    return coverMs / 1000.0;
  }

  VideoCropSelection? _resolvedCropSelection() {
    if (_isWindowsDesktop) {
      return null;
    }
    return VideoCropSelection(
      sourceWidth: _editorController.videoWidth.round(),
      sourceHeight: _editorController.videoHeight.round(),
      leftFraction: _editorController.minCrop.dx,
      topFraction: _editorController.minCrop.dy,
      rightFraction: _editorController.maxCrop.dx,
      bottomFraction: _editorController.maxCrop.dy,
    );
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
      final activeIdentity = identityHub.activeIdentity;

      // 1. 获取用户在时间轴上截取的起止时间 (秒)
      final trimStart = _resolvedTrimStart();
      final trimEnd = _resolvedTrimEnd();
      final double start = trimStart.inMilliseconds / 1000.0;
      final double end = trimEnd.inMilliseconds / 1000.0;
      final double duration = end - start;

      // 2. 获取用户选定的封面所在秒数
      final double coverTime = _resolvedCoverTimeSeconds(start);

      // 3. 调用我们封装的底层 C++/FFmpeg 引擎进行硬件转码
      final outputLayout = _selectedAspectPreset.outputLayout;
      final cropSelection = _resolvedCropSelection();
      final result = await VideoProcessor.transcodeAndExtractCover(
        sourcePath: widget.file.path,
        outputLayout: outputLayout,
        cropSelection: cropSelection,
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
        final uploadBatchPrefix = 'publish_${DateTime.now().millisecondsSinceEpoch}';
        final coverFile = result.coverFile;
        final streamManifestFile = result.streamManifestFile;
        final streamSegmentFiles = result.streamSegmentFiles;
        final publishedWidth = result.width ?? outputLayout.targetWidth;
        final publishedHeight = result.height ?? outputLayout.targetHeight;
        final videoContentType = _guessContentType(
          result.videoFile.path,
          fallback: 'video/mp4',
        );
        final videoChecksum = SupabaseService.computeSha256Hex(videoBytes);
        UploadedMedia videoUpload =
            await SupabaseService.findReusableUploadedMedia(
              mediaKind: 'video',
              checksumSha256: videoChecksum,
            ) ??
            const UploadedMedia(
              ownerId: '',
              objectKey: '',
              publicUrl: '',
              mediaKind: 'video',
              contentType: 'video/mp4',
              bytes: 0,
              checksumSha256: '',
              sourceFilename: '',
            );
        if (videoUpload.publicUrl.isEmpty) {
          final videoUploadSession = await SupabaseService.issueUploadSession(
            mediaKind: 'video',
            sourceFilename: videoFileName,
            contentType: videoContentType,
            fileSizeBytes: videoBytes.length,
            ownerIdentityId: activeIdentity.id,
            idempotencyKey: '${uploadBatchPrefix}_video',
            preferredObjectPrefix: uploadBatchPrefix,
            uploadPurpose: 'video_publish_primary',
            checksumSha256: videoChecksum,
            expectedWidth: publishedWidth,
            expectedHeight: publishedHeight,
            uploadMetadata: {
              'contentOrientation': outputLayout.contentOrientation,
              'aspectRatioLabel': outputLayout.aspectRatioLabel,
            },
          );

          videoUpload = await SupabaseService.uploadMedia(
            fileName: videoFileName,
            fileBytes: videoBytes,
            mediaKind: 'video',
            accessToken: session.accessToken,
            contentType: videoContentType,
            width: publishedWidth,
            height: publishedHeight,
            objectPrefix: videoUploadSession.objectPrefix,
            uploadSessionId: videoUploadSession.id,
          );
        } else {
          setState(() {
            _exportStatus = '命中已存在主视频资产，跳过重复上传...';
          });
        }

        UploadedMedia? coverUpload;
        if (coverFile != null && await coverFile.exists()) {
          final coverBytes = await coverFile.readAsBytes();
          final coverFileName =
              'cover_${DateTime.now().millisecondsSinceEpoch}.webp';
          final coverContentType = _guessContentType(
            coverFile.path,
            fallback: 'image/webp',
          );
          final coverChecksum = SupabaseService.computeSha256Hex(coverBytes);
          coverUpload = await SupabaseService.findReusableUploadedMedia(
            mediaKind: 'cover',
            checksumSha256: coverChecksum,
          );
          if (coverUpload == null) {
            final coverUploadSession = await SupabaseService.issueUploadSession(
              mediaKind: 'cover',
              sourceFilename: coverFileName,
              contentType: coverContentType,
              fileSizeBytes: coverBytes.length,
              ownerIdentityId: activeIdentity.id,
              idempotencyKey: '${uploadBatchPrefix}_cover',
              preferredObjectPrefix: uploadBatchPrefix,
              uploadPurpose: 'video_publish_cover',
              checksumSha256: coverChecksum,
              expectedWidth: publishedWidth,
              expectedHeight: publishedHeight,
              uploadMetadata: {
                'contentOrientation': outputLayout.contentOrientation,
                'aspectRatioLabel': outputLayout.aspectRatioLabel,
              },
            );
            coverUpload = await SupabaseService.uploadMedia(
              fileName: coverFileName,
              fileBytes: coverBytes,
              mediaKind: 'cover',
              accessToken: session.accessToken,
              contentType: coverContentType,
              width: publishedWidth,
              height: publishedHeight,
              objectPrefix: coverUploadSession.objectPrefix,
              uploadSessionId: coverUploadSession.id,
            );
          } else {
            setState(() {
              _exportStatus = '命中已存在封面资产，跳过重复上传...';
            });
          }
        }

        UploadedMedia? streamManifestUpload;
        String? streamObjectPrefix;
        final segmentUploadSessionIds = <String>{};
        if (streamManifestFile != null && await streamManifestFile.exists()) {
          setState(() {
            _exportStatus = '正在上传单清晰度分片流...';
          });

          final manifestBytes = await streamManifestFile.readAsBytes();
          final manifestChecksum = SupabaseService.computeSha256Hex(
            manifestBytes,
          );
          final manifestContentType = _guessContentType(
            streamManifestFile.path,
            fallback: 'application/vnd.apple.mpegurl',
          );
          final stableStreamPrefix =
              'stream_${manifestChecksum.substring(0, 16)}';
          streamManifestUpload =
              await SupabaseService.findReusableUploadedMedia(
                mediaKind: 'stream',
                checksumSha256: manifestChecksum,
              );

          if (streamManifestUpload != null) {
            streamObjectPrefix = streamManifestUpload.objectPrefix;
            setState(() {
              _exportStatus = '命中已存在分片流资产，跳过重复上传...';
            });
          } else {
            streamObjectPrefix = stableStreamPrefix;

            for (var index = 0; index < streamSegmentFiles.length; index++) {
              final segmentFile = streamSegmentFiles[index];
              if (!await segmentFile.exists()) continue;
              final segmentBytes = await segmentFile.readAsBytes();
              final segmentFileName = segmentFile.uri.pathSegments.last;
              final segmentContentType = _guessContentType(
                segmentFile.path,
                fallback: 'video/mp4',
              );
              final segmentChecksum = SupabaseService.computeSha256Hex(
                segmentBytes,
              );
              final segmentUploadSession =
                  await SupabaseService.issueUploadSession(
                    mediaKind: 'stream',
                    sourceFilename: segmentFileName,
                    contentType: segmentContentType,
                    fileSizeBytes: segmentBytes.length,
                    ownerIdentityId: activeIdentity.id,
                    idempotencyKey:
                        '${streamObjectPrefix}_segment_${index}_$segmentFileName',
                    preferredObjectPrefix: streamObjectPrefix,
                    uploadPurpose: 'video_publish_stream_segment',
                    checksumSha256: segmentChecksum,
                    expectedWidth: publishedWidth,
                    expectedHeight: publishedHeight,
                    uploadMetadata: {
                      'contentOrientation': outputLayout.contentOrientation,
                      'aspectRatioLabel': outputLayout.aspectRatioLabel,
                      'segmentIndex': index,
                      'segmentFileName': segmentFileName,
                    },
                  );
              final segmentUpload = await SupabaseService.uploadMedia(
                fileName: segmentFileName,
                fileBytes: segmentBytes,
                mediaKind: 'stream',
                accessToken: session.accessToken,
                contentType: segmentContentType,
                width: publishedWidth,
                height: publishedHeight,
                objectPrefix: streamObjectPrefix,
                uploadSessionId: segmentUploadSession.id,
              );
              segmentUploadSessionIds.add(
                segmentUpload.uploadSessionId ?? segmentUploadSession.id,
              );
            }

            final manifestUploadSession =
                await SupabaseService.issueUploadSession(
                  mediaKind: 'stream',
                  sourceFilename: streamManifestFile.uri.pathSegments.last,
                  contentType: manifestContentType,
                  fileSizeBytes: manifestBytes.length,
                  ownerIdentityId: activeIdentity.id,
                  idempotencyKey: '${streamObjectPrefix}_manifest',
                  preferredObjectPrefix: streamObjectPrefix,
                  uploadPurpose: 'video_publish_stream_manifest',
                  checksumSha256: manifestChecksum,
                  expectedWidth: publishedWidth,
                  expectedHeight: publishedHeight,
                  uploadMetadata: {
                    'contentOrientation': outputLayout.contentOrientation,
                    'aspectRatioLabel': outputLayout.aspectRatioLabel,
                    'segmentCount': streamSegmentFiles.length,
                  },
                );
            streamManifestUpload = await SupabaseService.uploadMedia(
              fileName: streamManifestFile.uri.pathSegments.last,
              fileBytes: manifestBytes,
              mediaKind: 'stream',
              accessToken: session.accessToken,
              contentType: manifestContentType,
              width: publishedWidth,
              height: publishedHeight,
              objectPrefix: manifestUploadSession.objectPrefix,
              uploadSessionId: manifestUploadSession.id,
            );
            streamObjectPrefix = manifestUploadSession.objectPrefix;
          }
        }

        setState(() {
          _exportStatus = '上传完成，正在发布动态...';
        });

        final authorName = activeIdentity.displayName.trim().isNotEmpty
            ? activeIdentity.displayName
            : (user.email?.split('@').first ?? '匿名用户');

        await SupabaseService.publishVideo(
          videoUpload: videoUpload,
          coverUpload: coverUpload,
          streamManifestUpload: streamManifestUpload,
          description: '刚刚通过智选超级 APP 极限压缩上传了这条视频！🚀',
          authorId: user.id,
          authorIdentityId: activeIdentity.id,
          authorName: authorName,
          durationSeconds: duration <= 0 ? 1 : duration,
          contentOrientation: outputLayout.contentOrientation,
          aspectRatioLabel: outputLayout.aspectRatioLabel,
          width: publishedWidth,
          height: publishedHeight,
          streamObjectPrefix: streamObjectPrefix,
          streamFormat: streamManifestUpload == null ? null : 'hls',
        );
        await SupabaseService.consumeUploadSessions(segmentUploadSessionIds);

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
      body: _isEditorReady
          ? SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _buildTopBar(),
                      // 视频预览区
                      Expanded(
                        child: _buildPreviewArea(),
                      ),
                      // 底部编辑控制区
                      Container(
                        color: Colors.black,
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildAspectRatioSelector(),
                            const SizedBox(height: 14),
                            _buildDistributionPreview(),
                            const SizedBox(height: 16),
                            _buildPlaybackControl(),
                            const SizedBox(height: 12),
                            if (_supportsThumbnailTimeline) ...[
                              Container(
                                height: 60,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: TrimSlider(
                                  controller: _editorController,
                                  height: 60,
                                  horizontalMargin: 0,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '滑动选择封面',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 40,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: CoverSelection(
                                  controller: _editorController,
                                  size: 40,
                                ),
                              ),
                            ] else ...[
                              _buildWindowsEditorNotice(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 转码中的全屏遮罩
                  if (_isExporting)
                    Container(
                      color: Colors.black,
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

  Widget _buildAspectRatioSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _VideoAspectPreset.values.map((preset) {
          final isSelected = preset == _selectedAspectPreset;
          return Padding(
            padding: EdgeInsets.only(
              right: preset == _VideoAspectPreset.values.last ? 0 : 10,
            ),
            child: GestureDetector(
              onTap: _isExporting ? null : () => _applyAspectPreset(preset),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white,
                  ),
                  color: isSelected ? Colors.white : Colors.black,
                ),
                child: Text(
                  preset.label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (!_isWindowsDesktop) {
      return CropGridViewer.preview(controller: _editorController);
    }

    final aspectRatio = _windowsController.value.aspectRatio;
    final safeAspectRatio =
        aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 9 / 16;
    return Center(
      child: AspectRatio(
        aspectRatio: safeAspectRatio,
        child: VideoPlayer(_windowsController),
      ),
    );
  }

  Widget _buildPlaybackControl() {
    if (_isWindowsDesktop) {
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _windowsController,
        builder: (context, value, _) {
          return IconButton(
            onPressed: () {
              if (value.isPlaying) {
                _windowsController.pause();
              } else {
                _windowsController.play();
              }
            },
            icon: Icon(
              value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _editorController.video,
      builder: (_, __) {
        return IconButton(
          onPressed: () {
            if (_editorController.isPlaying) {
              _editorController.video.pause();
            } else {
              _editorController.video.play();
            }
          },
          icon: Icon(
            _editorController.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 32,
          ),
        );
      },
    );
  }

  Widget _buildDistributionPreview() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildPreviewBadge('进入$_distributionPreviewLabel'),
        _buildPreviewBadge(_primaryDistributionPreviewLabel),
        _buildPreviewBadge(_fallbackDistributionPreviewLabel),
      ],
    );
  }

  Widget _buildWindowsEditorNotice() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            'Windows 当前使用极速发布模式',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '默认截取前 15 秒，封面取起始帧。若要生成 HLS 主链，请安装 FFmpeg、设置 FFMPEG_PATH，或将 ffmpeg.exe 放到应用约定目录。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}
