import 'dart:async';
import 'dart:io';

import 'package:core_media/core_media.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_editor/video_editor.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_win/video_player_win.dart';

import '../domain/publish_overlay_store.dart';

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

enum _EditorTimelineMode { clip, cover }

/// 全屏沉浸式视频编辑器
class VideoEditorScreen extends ConsumerStatefulWidget {
  final File file;
  final VideoOutputLayout? preferredOutputLayout;

  const VideoEditorScreen({
    super.key,
    required this.file,
    this.preferredOutputLayout,
  });

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoEditorController? _controller;
  VideoPlayerController? _windowsPreviewController;
  bool _isStartingPublish = false;
  _VideoAspectPreset _selectedAspectPreset = _VideoAspectPreset.portrait;
  double _windowsTrimStartFraction = 0.0;
  double _windowsTrimEndFraction = 1.0;
  double _windowsCoverFraction = 0.0;
  bool _isLoadingTimelineFrames = false;
  List<VideoTimelineFrame> _timelineFrames = const [];
  _EditorTimelineMode _timelineMode = _EditorTimelineMode.clip;
  bool get _isWindowsDesktop => Platform.isWindows;
  bool get _supportsThumbnailTimeline => !_isWindowsDesktop;
  bool get _isEditorReady => _isWindowsDesktop
      ? (_windowsPreviewController?.value.isInitialized ?? false)
      : (_controller?.initialized ?? false);
  VideoEditorController get _editorController => _controller!;
  VideoPlayerController get _windowsController => _windowsPreviewController!;

  VideoOutputLayout get _currentOutputLayout =>
      _selectedAspectPreset.outputLayout;
  Duration get _sourceDuration => _isWindowsDesktop
      ? _windowsSourceDuration
      : (_controller?.video.value.duration ?? const Duration(seconds: 1));
  Duration get _windowsSourceDuration =>
      _windowsController.value.duration <= Duration.zero
          ? const Duration(seconds: 1)
          : _windowsController.value.duration;

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
    );
    _controller = controller;

    controller.initialize().then((_) async {
      final autoPreset = widget.preferredOutputLayout == null
          ? _resolveAutoAspectPreset(
              sourceWidth: controller.videoWidth,
              sourceHeight: controller.videoHeight,
            )
          : _presetFromOutputLayout(widget.preferredOutputLayout!);
      controller.cropAspectRatio(autoPreset.ratio);
      await controller.video.setLooping(true);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAspectPreset = autoPreset;
      });
      unawaited(_loadTimelineFrames());
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
      final autoPreset = widget.preferredOutputLayout == null
          ? _resolveAutoAspectPreset(
              sourceWidth: sourceSize.width,
              sourceHeight: sourceSize.height,
            )
          : _presetFromOutputLayout(widget.preferredOutputLayout!);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _selectedAspectPreset = autoPreset;
      });
      unawaited(_loadTimelineFrames());
    } catch (error) {
      debugPrint('Windows preview init error: $error');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _loadTimelineFrames() async {
    setState(() {
      _isLoadingTimelineFrames = true;
    });
    try {
      final frames = await VideoProcessor.extractTimelineFrames(
        sourcePath: widget.file.path,
        totalDurationSeconds: _sourceDuration.inMilliseconds / 1000.0,
        frameCount: 10,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _timelineFrames = frames;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _timelineFrames = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimelineFrames = false;
        });
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

  _VideoAspectPreset _presetFromOutputLayout(VideoOutputLayout outputLayout) {
    return outputLayout == VideoOutputLayout.landscape
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
      return Duration(
        milliseconds: (_windowsSourceDuration.inMilliseconds *
                _windowsTrimStartFraction)
            .round(),
      );
    }
    return _editorController.startTrim;
  }

  Duration _resolvedTrimEnd() {
    if (!_isWindowsDesktop) {
      return _editorController.endTrim;
    }
    return Duration(
      milliseconds:
          (_windowsSourceDuration.inMilliseconds * _windowsTrimEndFraction)
              .round(),
    );
  }

  double _resolvedCoverTimeSeconds(double startSeconds) {
    if (_isWindowsDesktop) {
      final absoluteSeconds =
          _windowsSourceDuration.inMilliseconds * _windowsCoverFraction / 1000.0;
      final endSeconds = _resolvedTrimEnd().inMilliseconds / 1000.0;
      return absoluteSeconds.clamp(startSeconds, endSeconds);
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

  Future<void> _seekWindowsPreview(Duration position) async {
    if (!_isWindowsDesktop) {
      return;
    }
    final duration = _windowsSourceDuration;
    final bounded = position > duration ? duration : position;
    await _windowsController.seekTo(bounded);
  }

  Future<void> _startPublishFlow() async {
    if (_isStartingPublish) {
      return;
    }
    setState(() {
      _isStartingPublish = true;
    });

    try {
      final session = SupabaseService.currentSession;
      final user = SupabaseService.currentUser;
      if (session == null || user == null) {
        throw Exception('请先登录后再发布视频');
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

      final trimStart = _resolvedTrimStart();
      final trimEnd = _resolvedTrimEnd();
      final startSeconds = trimStart.inMilliseconds / 1000.0;
      final endSeconds = trimEnd.inMilliseconds / 1000.0;
      final coverTimeSeconds = _resolvedCoverTimeSeconds(startSeconds);
      final started = PublishOverlayStore.instance.startPublish(
        PublishVideoRequest(
          file: widget.file,
          activeIdentity: identityHub.activeIdentity,
          outputLayout: _currentOutputLayout,
          trimStartSeconds: startSeconds,
          trimEndSeconds: endSeconds,
          coverTimeSeconds: coverTimeSeconds,
          cropSelection: _resolvedCropSelection(),
        ),
      );
      if (!started) {
        throw Exception('已有发布任务正在进行，请等待当前作品完成');
      }
      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      navigator.pop();
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingPublish = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isEditorReady
          ? Stack(
              children: [
                Positioned.fill(child: _buildPreviewArea()),
                Positioned.fill(child: _buildPreviewOverlay()),
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopBar(),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomPanel(),
                      ),
                    ],
                  ),
                ),
              ],
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
          _buildCircleAction(
            icon: Icons.close,
            onTap: _isStartingPublish ? null : () => Navigator.pop(context),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '编辑视频',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '已选 ${_formatDuration(_resolvedTrimEnd() - _resolvedTrimStart())}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: _isStartingPublish ? null : _startPublishFlow,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: _isStartingPublish
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      '发布',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewOverlay() {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.28),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.56),
            ],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.86),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildEditorMetricsRow(),
          const SizedBox(height: 14),
          _buildAspectRatioSelector(),
          const SizedBox(height: 18),
          _buildPlaybackRow(),
          const SizedBox(height: 18),
          _buildTimelineSection(),
        ],
      ),
    );
  }

  Widget _buildEditorMetricsRow() {
    final totalDuration = _sourceDuration;
    final selectedDuration = _resolvedTrimEnd() - _resolvedTrimStart();
    final coverDuration = Duration(
      milliseconds: (_resolvedCoverTimeSeconds(
            _resolvedTrimStart().inMilliseconds / 1000.0,
          ) *
          1000)
          .round(),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildMetricPill(label: '总时长', value: _formatDuration(totalDuration)),
        _buildMetricPill(label: '片段', value: _formatDuration(selectedDuration)),
        _buildMetricPill(label: '封面', value: _formatDuration(coverDuration)),
      ],
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspectRatioSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _VideoAspectPreset.values.map((preset) {
        final isSelected = preset == _selectedAspectPreset;
        return Padding(
          padding: EdgeInsets.only(
            right: preset == _VideoAspectPreset.values.last ? 0 : 10,
          ),
          child: GestureDetector(
            onTap: _isStartingPublish ? null : () => _applyAspectPreset(preset),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1),
                color: isSelected ? Colors.white : Colors.transparent,
              ),
              child: Text(
                preset.label,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreviewArea() {
    if (!_isWindowsDesktop) {
      return CropGridViewer.preview(controller: _editorController);
    }

    final aspectRatio = _windowsController.value.aspectRatio;
    final safeAspectRatio =
        aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 9 / 16;
    final sourceWidth = safeAspectRatio >= 1 ? 1920.0 : 1080.0;
    final sourceHeight = safeAspectRatio >= 1 ? 1080.0 : 1920.0;
    return Center(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: sourceWidth,
          height: sourceHeight,
          child: AspectRatio(
            aspectRatio: safeAspectRatio,
            child: VideoPlayer(_windowsController),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildCircleAction(
          icon: _isWindowsDesktop
              ? (_windowsController.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow)
              : (_editorController.isPlaying ? Icons.pause : Icons.play_arrow),
          onTap: () {
            if (_isWindowsDesktop) {
              if (_windowsController.value.isPlaying) {
                _windowsController.pause();
              } else {
                _windowsController.play();
              }
              setState(() {});
              return;
            }
            if (_editorController.isPlaying) {
              _editorController.video.pause();
            } else {
              _editorController.video.play();
            }
            setState(() {});
          },
        ),
        _buildTimelineQuickChip(
          label: '片段',
          value: _formatDuration(_resolvedTrimEnd() - _resolvedTrimStart()),
          isSelected: _timelineMode == _EditorTimelineMode.clip,
          onTap: () {
            setState(() {
              _timelineMode = _EditorTimelineMode.clip;
            });
          },
        ),
        _buildTimelineQuickChip(
          label: '封面',
          value: _formatDuration(
            Duration(
              milliseconds: (_resolvedCoverTimeSeconds(
                    _resolvedTrimStart().inMilliseconds / 1000.0,
                  ) *
                  1000)
                  .round(),
            ),
          ),
          isSelected: _timelineMode == _EditorTimelineMode.cover,
          onTap: () {
            setState(() {
              _timelineMode = _EditorTimelineMode.cover;
            });
          },
        ),
        _buildStaticInfoChip(
          _currentOutputLayout.contentOrientation == 'landscape'
              ? '横屏分发'
              : '推荐分发',
        ),
      ],
    );
  }

  Widget _buildTimelineQuickChip({
    required String label,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticInfoChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimelineSectionHeader(),
          const SizedBox(height: 14),
          if (_supportsThumbnailTimeline)
            _buildMobileTimelineEditor()
          else
            _buildWindowsTimelineEditor(),
        ],
      ),
    );
  }

  Widget _buildTimelineSectionHeader() {
    return Row(
      children: [
        Text(
          _timelineMode == _EditorTimelineMode.clip ? '片段编辑' : '封面选择',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _buildModeSegment(_EditorTimelineMode.clip, '片段'),
        const SizedBox(width: 8),
        _buildModeSegment(_EditorTimelineMode.cover, '封面'),
      ],
    );
  }

  Widget _buildModeSegment(_EditorTimelineMode mode, String label) {
    final isSelected = _timelineMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _timelineMode = mode;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTimelineEditor() {
    if (_timelineMode == _EditorTimelineMode.clip) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '拖动时间条选择片段',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _buildUnifiedFrameStrip(height: 72)),
                Positioned.fill(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      sliderTheme: const SliderThemeData(
                        trackHeight: 64,
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                      ),
                    ),
                    child: Opacity(
                      opacity: 0.02,
                      child: TrimSlider(
                        controller: _editorController,
                        height: 64,
                        horizontalMargin: 0,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildMobileTrimSelectionOverlay(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '已选 ${_formatDuration(_resolvedTrimEnd() - _resolvedTrimStart())}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '拖动选择封面',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(child: _buildUnifiedFrameStrip(height: 52)),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.02,
                  child: CoverSelection(
                    controller: _editorController,
                    size: 44,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: _buildMobileCoverOverlay(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '封面 ${_formatDuration(Duration(milliseconds: (_resolvedCoverTimeSeconds(_resolvedTrimStart().inMilliseconds / 1000.0) * 1000).round()))}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildWindowsTimelineEditor() {
    final totalSeconds = _windowsSourceDuration.inMilliseconds / 1000.0;
    final startSeconds = totalSeconds * _windowsTrimStartFraction;
    final endSeconds = totalSeconds * _windowsTrimEndFraction;
    final coverSeconds = totalSeconds * _windowsCoverFraction;
    final selectedCoverSeconds = coverSeconds.clamp(startSeconds, endSeconds);
    if (_timelineMode == _EditorTimelineMode.clip) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '拖动时间条选择片段',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildUnifiedFrameStrip(height: 68),
          const SizedBox(height: 12),
          RangeSlider(
            values: RangeValues(startSeconds, endSeconds),
            min: 0,
            max: totalSeconds <= 1 ? 1 : totalSeconds,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.18),
            divisions: totalSeconds.ceil().clamp(1, 600),
            labels: RangeLabels(
              _formatDuration(
                Duration(milliseconds: (startSeconds * 1000).round()),
              ),
              _formatDuration(
                Duration(milliseconds: (endSeconds * 1000).round()),
              ),
            ),
            onChanged: (values) async {
              final max = totalSeconds <= 1 ? 1.0 : totalSeconds;
              final safeStart = values.start.clamp(0.0, max);
              final safeEnd = values.end <= safeStart + 0.2
                  ? (safeStart + 0.2).clamp(0.2, max)
                  : values.end.clamp(safeStart + 0.2, max);
              setState(() {
                _windowsTrimStartFraction = safeStart / max;
                _windowsTrimEndFraction = safeEnd / max;
                _windowsCoverFraction = _windowsCoverFraction.clamp(
                  _windowsTrimStartFraction,
                  _windowsTrimEndFraction,
                );
              });
              await _seekWindowsPreview(
                Duration(milliseconds: (safeStart * 1000).round()),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '已选 ${_formatDuration(Duration(milliseconds: ((endSeconds - startSeconds) * 1000).round()))}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '拖动选择封面',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _buildUnifiedFrameStrip(height: 68),
        const SizedBox(height: 12),
        Slider(
          value: selectedCoverSeconds,
          min: startSeconds,
          max:
              endSeconds <= startSeconds + 0.1 ? startSeconds + 0.1 : endSeconds,
          activeColor: Colors.white,
          inactiveColor: Colors.white.withValues(alpha: 0.18),
          divisions: ((endSeconds - startSeconds).ceil()).clamp(1, 300),
          onChanged: (value) async {
            final max = totalSeconds <= 1 ? 1.0 : totalSeconds;
            setState(() {
              _windowsCoverFraction = value / max;
            });
            await _seekWindowsPreview(
              Duration(milliseconds: (value * 1000).round()),
            );
          },
        ),
        Text(
          '封面 ${_formatDuration(Duration(milliseconds: (selectedCoverSeconds * 1000).round()))}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedFrameStrip({required double height}) {
    if (_isLoadingTimelineFrames) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    if (_timelineFrames.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        child: Row(
          children: _timelineFrames.map((frame) {
            return Expanded(
              child: Image.file(
                frame.file,
                fit: BoxFit.cover,
                height: height,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileTrimSelectionOverlay() {
    final totalMs = _sourceDuration.inMilliseconds <= 0
        ? 1.0
        : _sourceDuration.inMilliseconds.toDouble();
    final startFraction = (_resolvedTrimStart().inMilliseconds / totalMs)
        .clamp(0.0, 1.0);
    final endFraction = (_resolvedTrimEnd().inMilliseconds / totalMs)
        .clamp(startFraction, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final left = width * startFraction;
        final right = width * endFraction;
        final selectionWidth = (right - left).clamp(24.0, width);
        return Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  SizedBox(width: left),
                  Container(
                    width: selectionWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: (left - 10).clamp(0.0, width - 20),
              top: 18,
              child: _buildTimelineHandle(),
            ),
            Positioned(
              left: (right - 10).clamp(0.0, width - 20),
              top: 18,
              child: _buildTimelineHandle(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileCoverOverlay() {
    final totalMs = _sourceDuration.inMilliseconds <= 0
        ? 1.0
        : _sourceDuration.inMilliseconds.toDouble();
    final coverFraction = (_resolvedCoverTimeSeconds(
              _resolvedTrimStart().inMilliseconds / 1000.0,
            ) *
            1000 /
            totalMs)
        .clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final markerLeft = (width * coverFraction - 10).clamp(0.0, width - 20);
        return Stack(
          children: [
            Positioned(
              left: markerLeft,
              top: 4,
              bottom: 4,
              child: Container(
                width: 20,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineHandle() {
    return Container(
      width: 20,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Center(
        child: SizedBox(
          width: 2,
          height: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required VoidCallback? onTap,
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

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.abs();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isWindowsDesktop && _isEditorReady && !_windowsController.value.isPlaying) {
      _windowsController.play();
    } else if (!_isWindowsDesktop &&
        _isEditorReady &&
        !_editorController.isPlaying) {
      _editorController.video.play();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_isWindowsDesktop && _windowsPreviewController != null) {
      _windowsPreviewController!.play();
    } else if (_controller != null) {
      _controller!.video.play();
    }
  }

}
