import 'package:flutter/material.dart';

enum BackgroundType {
  dynamicAurora, // 动态彩色流光
  pureBlack,     // 极致纯黑
}

class BackgroundManager {
  static final BackgroundManager instance = BackgroundManager._internal();
  BackgroundManager._internal();

  final ValueNotifier<BackgroundType> currentBackground = ValueNotifier(BackgroundType.dynamicAurora);

  void setBackground(BackgroundType type) {
    currentBackground.value = type;
  }
}
