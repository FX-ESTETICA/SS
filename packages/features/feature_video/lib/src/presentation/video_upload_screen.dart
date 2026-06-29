import 'dart:io';
import 'dart:async';
import 'dart:convert';
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
  const VideoUploadScreen({super.key});

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
  VideoOutputLayout _selectedOutputLayout = VideoOutputLayout.portrait;
  bool _showCameraPrimer = true;
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
    _showCameraPrimer = false;
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
            _showCameraPrimer = false;
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
        if (mounted) {
          setState(() {
            _showCameraPrimer = false;
          });
        }
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
          _showCameraPrimer = false;
        });
      }
    }
  }

  Future<void> _beginCameraFlow() async {
    // #region debug-point H2:continue-button-tapped
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'H2',
        location: 'video_upload_screen.dart:_beginCameraFlow',
        msg: 'continue button tapped',
        data: {
          'showCameraPrimer': _showCameraPrimer,
          'isInitializingCamera': _isInitializingCamera,
          'hasWarmController': CameraWarmupService.instance.hasWarmController,
          'hasUserActivatedCamera':
              CameraWarmupService.instance.hasUserActivatedCamera,
        },
      ),
    );
    // #endregion
    await _initCamera(userInitiated: true);
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
          'showCameraPrimer': _showCameraPrimer,
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
            'showCameraPrimer': _showCameraPrimer,
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
          'showCameraPrimer': _showCameraPrimer,
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

    // 强制使用 pushReplacement 或者延迟一点，避免与系统的相册 Picker 生命周期冲突
    Future.microtask(() {
      if (!mounted) return;
      context.pushImmersive<void>(
        builder: (context) => VideoEditorScreen(
          file: file,
          preferredOutputLayout: _selectedOutputLayout,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _cameraController?.value.previewSize;
    final previewWidth = previewSize?.width ?? 1080;
    final previewHeight = previewSize?.height ?? 1920;

    return Scaffold(
      backgroundColor: Colors.black, // 严格暗黑基底
      body: Stack(
        children: [
          // 1. 相机全屏预览区
          if (_cameraController != null &&
              _cameraController!.value.isInitialized &&
              !_showCameraPrimer)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            )
          else
            Center(
              child: _showCameraPrimer
                  ? const SizedBox.shrink()
                  : _cameraError != null
                      ? Text(
                          _cameraError!,
                          style: const TextStyle(color: Colors.white),
                        )
                      : const CircularProgressIndicator(color: Colors.white),
            ),

          if (_isInitializingCamera)
            Container(color: Colors.black.withValues(alpha: 0.22)),

          IgnorePointer(
            child: Center(
              child: _buildCaptureGuide(),
            ),
          ),

          Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildTopStatusPill(),
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
                            'showCameraPrimer': _showCameraPrimer,
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

          // 3. 底部操作区
          Positioned(
            bottom: 156,
            left: 0,
            right: 0,
            child: Center(
              child: _buildAspectRatioSelector(),
            ),
          ),

          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 占位，保持中间按钮绝对居中
                const SizedBox(width: 60),

                // 中间录制按钮
                GestureDetector(
                  onTap: _toggleRecording,
                  child: _buildRecordButton(),
                ),

                // 右侧相册选择按钮
                GestureDetector(
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
                ),
              ],
            ),
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

          if (_showCameraPrimer) Positioned.fill(child: _buildCameraPrimer()),
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

  Widget _buildAspectRatioSelector() {
    final isPortrait = _selectedOutputLayout == VideoOutputLayout.portrait;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAspectRatioChip(
            label: '9:16',
            selected: isPortrait,
            onTap: () {
              setState(() {
                _selectedOutputLayout = VideoOutputLayout.portrait;
              });
            },
          ),
          _buildAspectRatioChip(
            label: '16:9',
            selected: !isPortrait,
            onTap: () {
              setState(() {
                _selectedOutputLayout = VideoOutputLayout.landscape;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAspectRatioChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureGuide() {
    final isPortrait = _selectedOutputLayout == VideoOutputLayout.portrait;
    return FractionallySizedBox(
      widthFactor: isPortrait ? 0.54 : 0.82,
      child: AspectRatio(
        aspectRatio: isPortrait ? 9 / 16 : 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatusPill() {
    if (_showCameraPrimer) {
      return const SizedBox.shrink();
    }
    if (_isRecording) {
      return _buildStatusPill(
        key: const ValueKey('recording'),
        label: '录制中',
        accentColor: Colors.red,
      );
    }
    if (_isInitializingCamera) {
      return _buildStatusPill(
        key: const ValueKey('initializing'),
        label: '相机准备中',
        loading: true,
      );
    }
    if (_cameraError != null) {
      return _buildStatusPill(
        key: const ValueKey('error'),
        label: _cameraError!,
      );
    }
    return _buildStatusPill(
      key: const ValueKey('ready'),
      label: _selectedOutputLayout == VideoOutputLayout.landscape
          ? '16:9 已就绪'
          : '9:16 已就绪',
    );
  }

  Widget _buildStatusPill({
    required Key key,
    required String label,
    bool loading = false,
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
          if (loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
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

  Widget _buildCameraPrimer() {
    // #region debug-point H4:camera-primer-render
    unawaited(
      _reportDebugEvent(
        hypothesisId: 'H4',
        location: 'video_upload_screen.dart:_buildCameraPrimer',
        msg: 'camera primer rendered',
        data: {
          'showCameraPrimer': _showCameraPrimer,
          'isInitializingCamera': _isInitializingCamera,
          'cameraError': _cameraError,
        },
      ),
    );
    // #endregion
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCaptureGuide(),
                      const SizedBox(height: 40),
                      const Text(
                        '准备开启相机',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _cameraError ??
                            '首次使用时系统会请求相机权限。授权后，后续进入拍摄会更接近秒开体感。',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: _isInitializingCamera ? null : _beginCameraFlow,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: _isInitializingCamera
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Text(
                                  '继续',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '你也可以直接从相册导入素材',
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
            GestureDetector(
              onTap: _pickFromGallery,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
