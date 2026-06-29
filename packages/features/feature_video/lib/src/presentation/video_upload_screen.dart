import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'video_editor_screen.dart'; // 我们下一步要创建的页面

/// 视频上传准备页 (入口) - 相机拍摄模式
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const int _targetVideoFps = 60;
  static const int _targetVideoBitrate = 20000000;
  static const String _debugRunId = 'post-fix';
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  bool _isRecording = false;
  bool _isInitializingCamera = true;
  String? _cameraError;
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
      var sessionId = 'camera-native-validation';
      final envFile = File(
        r'c:\Users\49975\Desktop\智选\.dbg\camera-native-validation.env',
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
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
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
        _selectedCameraIndex = _selectBestInitialCameraIndex(_cameras!);
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
      fps: Platform.isWindows ? _targetVideoFps : null,
      videoBitrate: Platform.isWindows ? _targetVideoBitrate : null,
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
            'fpsTarget': Platform.isWindows ? _targetVideoFps : null,
            'videoBitrateTarget':
                Platform.isWindows ? _targetVideoBitrate : null,
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

  int _selectBestInitialCameraIndex(List<CameraDescription> cameras) {
    if (!Platform.isWindows) {
      final frontIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      return frontIndex == -1 ? 0 : frontIndex;
    }

    var bestIndex = 0;
    var bestScore = -9999;
    for (var i = 0; i < cameras.length; i++) {
      final score = _scoreCamera(cameras[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  int _scoreCamera(CameraDescription camera) {
    final name = camera.name.toLowerCase();
    var score = 0;

    if (name.contains('integrated')) score += 80;
    if (name.contains('hd')) score += 30;
    if (name.contains('full hd')) score += 40;
    if (name.contains('webcam')) score += 35;
    if (name.contains('usb')) score += 25;
    if (name.contains('logitech')) score += 50;
    if (name.contains('front')) score += 15;
    if (name.contains('rear') || name.contains('back')) score += 20;
    if (name.contains('camera')) score += 10;
    if (name.contains('ir') ||
        name.contains('infrared') ||
        name.contains('depth')) {
      score -= 120;
    }
    if (name.contains('virtual') ||
        name.contains('obs') ||
        name.contains('droidcam')) {
      score -= 80;
    }

    return score;
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
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
    try {
      // 调用系统相册选择视频 (不限制原始大小)
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        _goToEditor(File(video.path));
      }
    } catch (e) {
      debugPrint('Error picking video from gallery: $e');
    }
  }

  void _goToEditor(File file) {
    if (!mounted) return;

    // 强制使用 pushReplacement 或者延迟一点，避免与系统的相册 Picker 生命周期冲突
    Future.microtask(() {
      if (!mounted) return;
      context.pushInstant<void>(
        builder: (context) => VideoEditorScreen(file: file),
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
              _cameraController!.value.isInitialized)
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
              child: _cameraError != null
                  ? Text(
                      _cameraError!,
                      style: const TextStyle(color: Colors.white),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

          if (_isInitializingCamera)
            Container(color: Colors.black.withValues(alpha: 0.22)),

          // 2. 顶部纯净操作栏：只保留必要控制，不显示任何状态文字
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopActionButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
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
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isRecording ? Colors.red : Colors.transparent,
                    ),
                    child: Center(
                      child: Container(
                        width: _isRecording ? 30 : 60,
                        height: _isRecording ? 30 : 60,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.white,
                          borderRadius:
                              BorderRadius.circular(_isRecording ? 8 : 30),
                        ),
                      ),
                    ),
                  ),
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
                        child: const Icon(
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
}
