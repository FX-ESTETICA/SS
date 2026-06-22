import 'package:flutter/material.dart';
import '../theme/background_manager.dart';

/// 极简美学：深空流光背景组件
/// 提供一个极暗的彩色旋转扫光背景，用于替代枯燥的纯黑或纯白背景
class AnimatedSpatialBackground extends StatefulWidget {
  final Widget child;

  const AnimatedSpatialBackground({super.key, required this.child});

  @override
  State<AnimatedSpatialBackground> createState() => _AnimatedSpatialBackgroundState();
}

class _AnimatedSpatialBackgroundState extends State<AnimatedSpatialBackground> with SingleTickerProviderStateMixin {
  late AnimationController _bgAnimationController;

  @override
  void initState() {
    super.initState();
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // 15秒一个轮回，比之前更舒缓
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackgroundType>(
      valueListenable: BackgroundManager.instance.currentBackground,
      builder: (context, bgType, _) {
        return Stack(
          children: [
            // 根据全局设置渲染不同的底层背景
            if (bgType == BackgroundType.dynamicAurora)
              AnimatedBuilder(
                animation: _bgAnimationController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        center: Alignment.center,
                        colors: [
                          Colors.black,
                          const Color(0xFF2A0845).withValues(alpha: 0.5), // 深邃紫
                          Colors.black,
                          const Color(0xFF00416A).withValues(alpha: 0.5), // 深海蓝
                          Colors.black,
                          const Color(0xFF640D14).withValues(alpha: 0.5), // 猩红暗流
                          Colors.black,
                        ],
                        stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
                        transform: GradientRotation(_bgAnimationController.value * 2 * 3.1415926),
                      ),
                    ),
                  );
                },
              )
            else if (bgType == BackgroundType.pureBlack)
              Container(color: Colors.black),
              
            // 确保上层内容可以直接盖在流光上
            widget.child,
          ],
        );
      },
    );
  }
}
