import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraWarmupLease {
  const CameraWarmupLease({
    required this.controller,
    required this.cameras,
    required this.selectedCameraIndex,
  });

  final CameraController controller;
  final List<CameraDescription> cameras;
  final int selectedCameraIndex;
}

class CameraWarmupService {
  CameraWarmupService._();

  static final CameraWarmupService instance = CameraWarmupService._();

  Future<void>? _warmupFuture;
  CameraController? _warmedController;
  List<CameraDescription>? _warmedCameras;
  int? _warmedSelectedCameraIndex;
  bool _hasUserActivatedCamera = false;

  static const int targetVideoFps = 60;
  static const int targetVideoBitrate = 20000000;

  bool get hasWarmController => _warmedController?.value.isInitialized ?? false;
  bool get hasUserActivatedCamera => _hasUserActivatedCamera;

  static int selectBestInitialCameraIndex(List<CameraDescription> cameras) {
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

  static int _scoreCamera(CameraDescription camera) {
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

  Future<void> warmup({bool userInitiated = false}) async {
    if (userInitiated) {
      _hasUserActivatedCamera = true;
    }
    if (!_hasUserActivatedCamera) {
      return;
    }
    if (hasWarmController) {
      return;
    }
    final existingFuture = _warmupFuture;
    if (existingFuture != null) {
      return existingFuture;
    }
    final future = _createWarmController();
    _warmupFuture = future;
    try {
      await future;
    } finally {
      _warmupFuture = null;
    }
  }

  Future<CameraWarmupLease?> takeWarmController({
    bool userInitiated = false,
  }) async {
    await warmup(userInitiated: userInitiated);
    final controller = _warmedController;
    final cameras = _warmedCameras;
    final selectedCameraIndex = _warmedSelectedCameraIndex;
    if (controller == null ||
        !(controller.value.isInitialized) ||
        cameras == null ||
        cameras.isEmpty ||
        selectedCameraIndex == null) {
      return null;
    }

    _warmedController = null;
    _warmedCameras = null;
    _warmedSelectedCameraIndex = null;
    return CameraWarmupLease(
      controller: controller,
      cameras: cameras,
      selectedCameraIndex: selectedCameraIndex,
    );
  }

  Future<void> _createWarmController() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return;
      }
      final selectedCameraIndex = selectBestInitialCameraIndex(cameras);
      final candidate = CameraController(
        cameras[selectedCameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
        fps: Platform.isWindows ? targetVideoFps : null,
        videoBitrate: Platform.isWindows ? targetVideoBitrate : null,
      );
      await candidate.initialize();
      try {
        await candidate.prepareForVideoRecording();
      } catch (_) {}

      await _warmedController?.dispose();
      _warmedController = candidate;
      _warmedCameras = cameras;
      _warmedSelectedCameraIndex = selectedCameraIndex;
    } catch (error) {
      debugPrint('Camera warmup failed: $error');
      await _warmedController?.dispose();
      _warmedController = null;
      _warmedCameras = null;
      _warmedSelectedCameraIndex = null;
    }
  }

  Future<void> reset() async {
    await _warmedController?.dispose();
    _warmedController = null;
    _warmedCameras = null;
    _warmedSelectedCameraIndex = null;
    _hasUserActivatedCamera = false;
  }
}
