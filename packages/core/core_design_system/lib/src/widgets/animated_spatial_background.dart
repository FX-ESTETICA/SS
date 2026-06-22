import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../theme/background_manager.dart';

/// 极简美学：深空流光背景组件
/// 使用 Fragment Shader 进行 GPU 硬件加速，通过 ValueNotifier 驱动局部重绘，彻底解放 CPU
class AnimatedSpatialBackground extends StatefulWidget {
  final Widget child;

  const AnimatedSpatialBackground({super.key, required this.child});

  @override
  State<AnimatedSpatialBackground> createState() => _AnimatedSpatialBackgroundState();
}

class _AnimatedSpatialBackgroundState extends State<AnimatedSpatialBackground> {
  ui.FragmentProgram? _program;
  
  @override
  void initState() {
    super.initState();
    _loadShader();
    BackgroundManager.instance.addSubscriber();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('packages/core_design_system/shaders/aurora_flow.frag');
      if (mounted) {
        setState(() {
          _program = program;
        });
      }
    } catch (e) {
      debugPrint('Shader load error: $e');
    }
  }

  @override
  void dispose() {
    BackgroundManager.instance.removeSubscriber();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackgroundType>(
      valueListenable: BackgroundManager.instance.currentBackground,
      builder: (context, bgType, _) {
        return Stack(
          children: [
            if (bgType == BackgroundType.dynamicAurora && _program != null)
              SizedBox.expand(
                child: RepaintBoundary( // 硬件图层隔离，防止其他组件的频繁重绘波及 Shader
                  child: CustomPaint(
                    // 将 Notifier 传入 Painter，实现真正的旁路渲染 (Bypass Rendering)
                    painter: _AuroraShaderPainter(_program!, BackgroundManager.instance.globalTimeNotifier),
                  ),
                ),
              )
            else if (bgType == BackgroundType.pureBlack || _program == null)
              Container(color: Colors.black),
              
            widget.child,
          ],
        );
      },
    );
  }
}

class _AuroraShaderPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ValueNotifier<double> timeNotifier;

  // 核心修复：将 timeNotifier 传给 super(repaint)，Flutter 会自动在数值改变时仅重绘此画布
  _AuroraShaderPainter(this.program, this.timeNotifier) : super(repaint: timeNotifier);

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    // 注入 GLSL uniform 变量
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, timeNotifier.value);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _AuroraShaderPainter oldDelegate) {
    // 因为使用了 repaint 驱动，这里可以直接返回 false
    return false;
  }
}
