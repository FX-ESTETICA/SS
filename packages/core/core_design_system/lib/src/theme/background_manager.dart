import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';

enum BackgroundType {
  dynamicAurora, // 动态彩色流光
  rainbowGradient, // 七彩流光渐变
  crimsonNebula, // 绯红星云
  oceanGlacier, // 深海蓝焰
  emeraldMist, // 翡翠光雾
  pureBlack, // 极致纯黑
}

class BackgroundThemePreset {
  final BackgroundType type;
  final String title;
  final List<Color> previewColors;

  const BackgroundThemePreset({
    required this.type,
    required this.title,
    required this.previewColors,
  });
}

class BackgroundManager {
  static final BackgroundManager instance = BackgroundManager._internal();
  BackgroundManager._internal();

  static const List<BackgroundThemePreset> availableThemes = [
    BackgroundThemePreset(
      type: BackgroundType.pureBlack,
      title: '极简纯黑',
      previewColors: [
        Color(0xFF000000),
        Color(0xFF050505),
        Color(0xFF0A0A0A),
      ],
    ),
    BackgroundThemePreset(
      type: BackgroundType.rainbowGradient,
      title: '七彩流光渐变',
      previewColors: [
        Color(0xFFFF3D81),
        Color(0xFF7048FF),
        Color(0xFF00C2FF),
      ],
    ),
    BackgroundThemePreset(
      type: BackgroundType.crimsonNebula,
      title: '绯红星云',
      previewColors: [
        Color(0xFF160104),
        Color(0xFF7A0C2E),
        Color(0xFFFF5A5F),
      ],
    ),
    BackgroundThemePreset(
      type: BackgroundType.oceanGlacier,
      title: '深海蓝焰',
      previewColors: [
        Color(0xFF03121C),
        Color(0xFF005E7A),
        Color(0xFF62E6FF),
      ],
    ),
    BackgroundThemePreset(
      type: BackgroundType.emeraldMist,
      title: '翡翠光雾',
      previewColors: [
        Color(0xFF03110C),
        Color(0xFF0E8E63),
        Color(0xFF6CFFD0),
      ],
    ),
  ];

  final ValueNotifier<BackgroundType> currentBackground =
      ValueNotifier(BackgroundType.rainbowGradient);

  // 全局共享的流光时间驱动器
  final ValueNotifier<double> globalTimeNotifier = ValueNotifier(0.0);
  Ticker? _globalTicker;
  int _activeSubscribers = 0;
  Duration _lastElapsed = Duration.zero;

  // 交互降频机制：静止一段时间后完全停止动画以达到 0% CPU
  Timer? _idleTimer;
  bool _isIdle = false;

  void setBackground(BackgroundType type) {
    currentBackground.value = type;
  }

  /// 通知系统有用户交互，唤醒动画
  void notifyInteraction() {
    _isIdle = false;
    _startTickerIfNeeded();

    _idleTimer?.cancel();
    // 3秒无交互后自动进入休眠态
    _idleTimer = Timer(const Duration(seconds: 3), () {
      _isIdle = true;
      _stopTicker();
    });
  }

  void addSubscriber() {
    _activeSubscribers++;
    notifyInteraction(); // 初始订阅时唤醒一次
  }

  void removeSubscriber() {
    _activeSubscribers--;
    if (_activeSubscribers <= 0) {
      _idleTimer?.cancel();
      _stopTicker();
      _activeSubscribers = 0;
    }
  }

  void _startTickerIfNeeded() {
    if (_globalTicker == null && _activeSubscribers > 0 && !_isIdle) {
      _lastElapsed = Duration.zero;
      _globalTicker = Ticker((elapsed) {
        if (elapsed - _lastElapsed < const Duration(milliseconds: 33)) {
          return;
        }
        _lastElapsed = elapsed;
        globalTimeNotifier.value += 0.005;
      });
      _globalTicker!.start();
    }
  }

  void _stopTicker() {
    _globalTicker?.stop();
    _globalTicker?.dispose();
    _globalTicker = null;
  }
}
