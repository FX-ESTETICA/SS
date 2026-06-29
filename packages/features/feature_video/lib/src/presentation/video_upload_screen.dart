import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:core_media/core_media.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/camera_warmup_service.dart';
import 'video_editor_screen.dart'; // 我们下一步要创建的页面

/// 视频上传准备页 (入口) - 相机拍摄模式
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({
    super.key,
    this.initialWarmLease,
  });

  final CameraWarmupLease? initialWarmLease;

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const String _debugRunId = 'post-fix';
  static const String _debugSessionId = 'upload-camera-dead';
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isInitializingCamera = true;
  String? _cameraError;
  bool _isPickingFromGallery = false;
  final ImagePicker _picker = ImagePicker();

  // #region debug-point H1:reporter
  Future<void> _reportDebugEvent({
    required String hypothesisId,
    required String location,
    required String msg,
    Map<String, Object?> data = const {},
  }) async {
    try {
      var serverUrl = 'http://127.0.0.1:7777/event';
      var sessionId = _debugSessionId;
      final envFile = File(
        r'c:\Users\49975\Desktop\智选\.dbg\upload-camera-dead.env',
      );
      if (await envFile.exists()) {
        final content = await envFile.readAsString();
        for (final line in const LineSplitter().convert(content)) {
          if (line.startsWith('DEBUG_SERVER_URL=')) {
            serverUrl = line.substring('DEBUG_SERVER_URL='.length).trim();
          } else if (line.startsWith('DEBUG_SESSION_ID=')) {
            sessionId = line.substring('DEBUG_SESSION_ID='.length).trim();
          }
        }
      }
      final uri = Uri.parse(serverUrl);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'sessionId': sessionId,
          'runId': _debugRunId,
          'hypothesisId': hypothesisId,
          'location': location,
          'msg': '[DEBUG] $msg',
          'data': data,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      await request.close();
      client.close();
    } catch (_) {}
  }
  // #endregion

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: const [],
      ),
    );
    if (_supportsViewportRotation) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]),
      );
    }
    final warmLease = widget.initialWarmLease;
    if (warmLease != null) {
      _cameraController = warmLease.controller;
      _cameras = warmLease.cameras;
      _selectedCameraIndex = warmLease.selectedCameraIndex;
      _isInitializingCamera = false;
      _cameraError = null;
      return;
    }
    unawaited(_initCamera(userInitiated: true));
  }

  Future<void> _initCamera({bool userInitiated = false}) async {
    try {
      if (!userInitiated &&
          !CameraWarmupService.instance.hasUserActivatedCamera &&
          !CameraWarmupService.instance.hasWarmController) {
        return;
      }
      if (mounted) {
        setState(() {
          _isInitializingCamera = true;
          _cameraError = null;
        });
      }
      final warmLease = await CameraWarmupService.instance.takeWarmController(
        userInitiated: userInitiated,
      );
      if (warmLease != null) {
        _cameraController = warmLease.controller;
        _cameras = warmLease.cameras;
        _selectedCameraIndex = warmLease.selectedCameraIndex;
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraError = null;
          });
        }
        return;
      }

      _cameras = await availableCameras();
      // #region debug-point H3:available-cameras
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H3',
          location: 'video_upload_screen.dart:_initCamera',
          msg: 'availableCameras resolved',
          data: {
            'cameraCount': _cameras?.length ?? 0,
            'cameras': _cameras
                    ?.map(
                      (camera) => {
                        'name': camera.name,
                        'lensDirection': camera.lensDirection.name,
                        'sensorOrientation': camera.sensorOrientation,
                      },
                    )
                    .toList() ??
                const [],
          },
        ),
      );
      // #endregion
      if (_cameras != null && _cameras!.isNotEmpty) {
        _selectedCameraIndex = CameraWarmupService.selectBestInitialCameraIndex(
          _cameras!,
        );
        // #region debug-point H3:selected-camera
        unawaited(
          _reportDebugEvent(
            hypothesisId: 'H3',
            location: 'video_upload_screen.dart:_initCamera',
            msg: 'camera selected by heuristic',
            data: {
              'selectedCameraIndex': _selectedCameraIndex,
              'selectedCameraName': _cameras![_selectedCameraIndex].name,
              'selectedLensDirection':
                  _cameras![_selectedCameraIndex].lensDirection.name,
            },
          ),
        );
        // #endregion
        await _setupCameraController();
      } else {
        setState(() {
          _cameraError = '未检测到可用摄像头';
          _isInitializingCamera = false;
        });
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      // #region debug-point H1:init-error
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H1',
          location: 'video_upload_screen.dart:_initCamera',
          msg: 'camera init failed',
          data: {'error': '$e'},
        ),
      );
      // #endregion
      if (mounted) {
        setState(() {
          _cameraError = '摄像头初始化失败';
          _isInitializingCamera = false;
        });
      }
    }
  }

  Future<void> _setupCameraController() async {
    if (_cameras == null || _cameras!.isEmpty) return;

    if (mounted) {
      setState(() {
        _isInitializingCamera = true;
        _cameraError = null;
      });
    }

    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.max,
      enableAudio: false, // 关闭音频避免 Windows 下因为麦克风权限导致的初始化黑屏/卡死
      fps: Platform.isWindows ? CameraWarmupService.targetVideoFps : null,
      videoBitrate:
          Platform.isWindows ? CameraWarmupService.targetVideoBitrate : null,
    );

    try {
      final stopwatch = Stopwatch()..start();
      // #region debug-point H1:controller-config
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H1',
          location: 'video_upload_screen.dart:_setupCameraController',
          msg: 'camera controller configured',
          data: {
            'cameraName': _cameras![_selectedCameraIndex].name,
            'resolutionPreset': 'max',
            'fpsTarget':
                Platform.isWindows ? CameraWarmupService.targetVideoFps : null,
            'videoBitrateTarget':
                Platform.isWindows
                    ? CameraWarmupService.targetVideoBitrate
                    : null,
            'enableAudio': false,
            'platform': Platform.operatingSystem,
          },
        ),
      );
      // #endregion
      await _cameraController!.initialize();
      try {
        await _cameraController!.prepareForVideoRecording();
      } catch (e) {
        debugPrint('prepareForVideoRecording error: $e');
        // #region debug-point H1:prepare-error
        unawaited(
          _reportDebugEvent(
            hypothesisId: 'H1',
            location: 'video_upload_screen.dart:_setupCameraController',
            msg: 'prepareForVideoRecording failed',
            data: {'error': '$e'},
          ),
        );
        // #endregion
      }
      stopwatch.stop();
      // #region debug-point H1:controller-initialized
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H1',
          location: 'video_upload_screen.dart:_setupCameraController',
          msg: 'camera controller initialized',
          data: {
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'isInitialized': _cameraController?.value.isInitialized ?? false,
            'previewSize': {
              'width': _cameraController?.value.previewSize?.width,
              'height': _cameraController?.value.previewSize?.height,
            },
            'aspectRatio': _cameraController?.value.aspectRatio,
            'isRecordingVideo':
                _cameraController?.value.isRecordingVideo ?? false,
            'selectedCameraName': _cameras![_selectedCameraIndex].name,
          },
        ),
      );
      // #endregion
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = null;
        });
      }
    } catch (e) {
      debugPrint('Camera setup error: $e');
      // #region debug-point H1:setup-error
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H1',
          location: 'video_upload_screen.dart:_setupCameraController',
          msg: 'camera setup failed',
          data: {
            'cameraName': _cameras![_selectedCameraIndex].name,
            'error': '$e',
          },
        ),
      );
      // #endregion
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = '摄像头启动失败';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    if (_supportsViewportRotation) {
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      ),
    );
    super.dispose();
  }

  void _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    // #region debug-point H3:flip-camera
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'H3',
        location: 'video_upload_screen.dart:_flipCamera',
        msg: 'camera flipped',
        data: {
          'selectedCameraIndex': _selectedCameraIndex,
          'selectedCameraName': _cameras![_selectedCameraIndex].name,
        },
      ),
    );
    // #endregion
    await _setupCameraController();
  }

  Future<void> _toggleRecording() async {
    // #region debug-point H2:record-button-tapped
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'H2',
        location: 'video_upload_screen.dart:_toggleRecording',
        msg: 'record button tapped',
        data: {
          'hasController': _cameraController != null,
          'isInitialized': _cameraController?.value.isInitialized ?? false,
          'isInitializingCamera': _isInitializingCamera,
        },
      ),
    );
    // #endregion
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // #region debug-point H2:record-guard-return
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H2',
          location: 'video_upload_screen.dart:_toggleRecording',
          msg: 'record button ignored by guard',
          data: {
            'hasController': _cameraController != null,
            'isInitialized': _cameraController?.value.isInitialized ?? false,
            'isInitializingCamera': _isInitializingCamera,
          },
        ),
      );
      // #endregion
      return;
    }

    if (_isRecording) {
      // 停止录制
      final file = await _cameraController!.stopVideoRecording();
      // #region debug-point H4:stop-recording
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H4',
          location: 'video_upload_screen.dart:_toggleRecording',
          msg: 'video recording stopped',
          data: {
            'filePath': file.path,
            'selectedCameraName': _cameras?[_selectedCameraIndex].name,
          },
        ),
      );
      // #endregion
      setState(() => _isRecording = false);
      _goToEditor(File(file.path));
    } else {
      // 开始录制
      await _cameraController!.startVideoRecording();
      // #region debug-point H4:start-recording
      unawaited(
        _reportDebugEvent(
          hypothesisId: 'H4',
          location: 'video_upload_screen.dart:_toggleRecording',
          msg: 'video recording started',
          data: {
            'selectedCameraName': _cameras?[_selectedCameraIndex].name,
            'previewSize': {
              'width': _cameraController?.value.previewSize?.width,
              'height': _cameraController?.value.previewSize?.height,
            },
          },
        ),
      );
      // #endregion
      setState(() => _isRecording = true);
    }
  }

  Future<void> _pickFromGallery() async {
    // #region debug-point H2:gallery-button-tapped
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'H2',
        location: 'video_upload_screen.dart:_pickFromGallery',
        msg: 'gallery button tapped',
        data: {
          'isInitializingCamera': _isInitializingCamera,
          'isPickingFromGallery': _isPickingFromGallery,
        },
      ),
    );
    // #endregion
    if (_isPickingFromGallery) {
      return;
    }
    try {
      setState(() {
        _isPickingFromGallery = true;
      });
      // 调用系统相册选择视频 (不限制原始大小)
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        _goToEditor(File(video.path));
      }
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFromGallery = false;
        });
      }
    }
  }

  void _goToEditor(File file) {
    if (!mounted) return;
    final effectiveOutputLayout = _resolveEffectiveOutputLayout(
      MediaQuery.sizeOf(context),
    );

    // 强制使用 pushReplacement 或者延迟一点，避免与系统的相册 Picker 生命周期冲突
    Future.microtask(() {
      if (!mounted) return;
      context.pushImmersive<void>(
        builder: (context) => VideoEditorScreen(
          file: file,
          preferredOutputLayout: effectiveOutputLayout,
        ),
      );
    });
  }

  bool get _supportsViewportRotation => Platform.isAndroid || Platform.isIOS;

  bool get _isCameraReady =>
      _cameraController != null && _cameraController!.value.isInitialized;

  VideoOutputLayout _resolveAutoOutputLayout(Size viewportSize) {
    return viewportSize.width > viewportSize.height
        ? VideoOutputLayout.landscape
        : VideoOutputLayout.portrait;
  }

  VideoOutputLayout _resolveEffectiveOutputLayout(Size viewportSize) {
    return _resolveAutoOutputLayout(viewportSize);
  }

  Widget _buildPreviewSurface() {
    if (_cameraError != null && !_isCameraReady) {
      return Center(
        child: Text(
          _cameraError!,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (!_isCameraReady) {
      return const SizedBox.expand(
        child: ColoredBox(color: Colors.black),
      );
    }

    final controller = _cameraController!;
    final previewSize = controller.value.previewSize;
    final previewWidth = previewSize?.width ?? 1080;
    final previewHeight = previewSize?.height ?? 1920;

    return SizedBox.expand(
      child: ClipRect(
        child: ColoredBox(
          color: Colors.black,
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: CameraPreview(controller),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final isViewportLandscape = viewportSize.width > viewportSize.height;
    final effectiveOutputLayout = _resolveEffectiveOutputLayout(viewportSize);
    final statusTop = safePadding.top + 16;

    return Scaffold(
      backgroundColor: Colors.black, // 严格暗黑基底
      body: Stack(
        children: [
          _buildPreviewSurface(),

          Positioned(
            top: statusTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildTopStatusPill(effectiveOutputLayout),
              ),
            ),
          ),

          // 2. 顶部纯净操作栏：只保留必要控制，不显示任何状态文字
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopActionButton(
                    icon: Icons.close,
                    onTap: () {
                      // #region debug-point H2:close-button-tapped
                      unawaited(
                        _reportDebugEvent(
                          hypothesisId: 'H2',
                          location: 'video_upload_screen.dart:build.close',
                          msg: 'close button tapped',
                          data: {
                            'isInitializingCamera': _isInitializingCamera,
                          },
                        ),
                      );
                      // #endregion
                      Navigator.pop(context);
                    },
                  ),
                  if ((_cameras?.length ?? 0) > 1)
                    _buildTopActionButton(
                      icon: Icons.flip_camera_ios,
                      onTap: _flipCamera,
                    )
                  else
                    const SizedBox(width: 44, height: 44),
                ],
              ),
            ),
          ),

          if (isViewportLandscape)
            _buildLandscapeControls(
              safePadding: safePadding,
            )
          else
            _buildPortraitControls(
              safePadding: safePadding,
            ),

          // 4. 录制状态提示 (仅在录制时显示)
          if (_isRecording)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '录制中',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
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

  Widget _buildPortraitControls({
    required EdgeInsets safePadding,
  }) {
    return Stack(
      children: [
        Positioned(
          bottom: safePadding.bottom + 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 60),
              GestureDetector(
                onTap: _toggleRecording,
                child: _buildRecordButton(),
              ),
              _buildGalleryButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeControls({
    required EdgeInsets safePadding,
  }) {
    return Positioned(
      top: safePadding.top + 24,
      right: safePadding.right + 24,
      bottom: safePadding.bottom + 24,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggleRecording,
            child: _buildRecordButton(),
          ),
          const SizedBox(height: 28),
          _buildGalleryButton(),
        ],
      ),
    );
  }

  Widget _buildTopStatusPill(VideoOutputLayout effectiveOutputLayout) {
    if (_isInitializingCamera && !_isCameraReady && _cameraError == null) {
      return const SizedBox.shrink();
    }
    if (_isRecording) {
      return _buildStatusPill(
        key: const ValueKey('recording'),
        label: '录制中',
        accentColor: Colors.red,
      );
    }
    if (_cameraError != null) {
      return _buildStatusPill(
        key: const ValueKey('error'),
        label: _cameraError!,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusPill({
    required Key key,
    required String label,
    Color accentColor = Colors.white,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        color: _isRecording ? Colors.red.withValues(alpha: 0.18) : Colors.transparent,
        boxShadow: _isRecording
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.26),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: _isRecording ? 30 : 60,
          height: _isRecording ? 30 : 60,
          decoration: BoxDecoration(
            color: _isRecording ? Colors.red : Colors.white,
            borderRadius: BorderRadius.circular(_isRecording ? 8 : 30),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: _pickFromGallery,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: _isPickingFromGallery
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
          const SizedBox(height: 4),
          const Text(
            '相册',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
