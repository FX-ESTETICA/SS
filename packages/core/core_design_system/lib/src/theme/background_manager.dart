import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';

enum BackgroundType {
  dynamicAurora, // 动态彩色流光
  pureBlack, // 极致纯黑
}

class BackgroundManager {
  static final BackgroundManager instance = BackgroundManager._internal();
  BackgroundManager._internal();

  final ValueNotifier<BackgroundType> currentBackground =
      ValueNotifier(BackgroundType.dynamicAurora);

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
