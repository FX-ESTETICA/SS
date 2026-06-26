import 'package:flutter/material.dart';
import 'colors.dart';

/// 降维打击必备：全局标准字体排版规范 (极致克制与呼吸感)
class AppTypography {
  // 顶级标题 (如页面顶部的应用名称、模块主名称)
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // 一级标题 (如页面内部的主标题)
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // 卡片/模块标题 (焦点字号)
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // 常规标题 (列表项、重要 Tab)
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // 标准正文 (极其细腻)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // 次要正文/按钮文本 (精巧干练)
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  // 辅助标签 (日期、提示)
  static const TextStyle labelLarge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  // 徽章/极小标签 (状态、缩写) - 极致细节
  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
