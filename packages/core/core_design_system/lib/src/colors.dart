import 'package:flutter/material.dart';

/// 全局颜色定义（降维打击必备：UI 绝对统一）
/// 所有模块（淘宝、微信、抖音）必须使用这里的颜色，严禁在业务代码里直接写色号 (如 0xFF0000)
class AppColors {
  // 品牌主色调
  static const Color primary = Color(0xFF0052D9);
  
  // 辅助色
  static const Color success = Color(0xFF2BA471);
  static const Color warning = Color(0xFFE37318);
  static const Color error = Color(0xFFD54941);

  // 中性色（背景、文本）
  static const Color background = Color(0xFFF3F3F3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF181818);
  static const Color textSecondary = Color(0xFF666666);
}
