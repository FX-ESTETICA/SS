import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/background_manager.dart';

class _BackgroundShaderRegistry {
  static const Map<BackgroundType, String> shaderAssets = {
    BackgroundType.dynamicAurora:
        'packages/core_design_system/shaders/aurora_flow.frag',
    BackgroundType.rainbowGradient:
        'packages/core_design_system/shaders/rainbow_flow.frag',
    BackgroundType.crimsonNebula:
        'packages/core_design_system/shaders/crimson_nebula.frag',
    BackgroundType.oceanGlacier:
        'packages/core_design_system/shaders/ocean_glacier.frag',
    BackgroundType.emeraldMist:
        'packages/core_design_system/shaders/emerald_mist.frag',
  };

  static final Map<BackgroundType, ui.FragmentProgram> _programs = {};
  static Future<void>? _loadingFuture;

  static Future<void> ensureLoaded() {
    if (_programs.length == shaderAssets.length) {
      return Future.value();
    }

    _loadingFuture ??= Future.wait<MapEntry<BackgroundType, ui.FragmentProgram>>(
      shaderAssets.entries.map((entry) async {
        final program = await ui.FragmentProgram.fromAsset(entry.value);
        return MapEntry(entry.key, program);
      }),
    ).then((loadedPrograms) {
      _programs
        ..clear()
        ..addEntries(loadedPrograms);
    });

    return _loadingFuture!;
  }

  static ui.FragmentProgram? programFor(BackgroundType type) {
    return _programs[type];
  }
}

/// 极简美学：深空流光背景组件
/// 使用 Fragment Shader 进行 GPU 硬件加速，通过 ValueNotifier 驱动局部重绘，彻底解放 CPU
class AnimatedSpatialBackground extends StatefulWidget {
  final Widget child;

  const AnimatedSpatialBackground({super.key, required this.child});

  @override
  State<AnimatedSpatialBackground> createState() =>
      _AnimatedSpatialBackgroundState();
}

class _AnimatedSpatialBackgroundState extends State<AnimatedSpatialBackground> {
  @override
  void initState() {
    super.initState();
    _loadShader();
    BackgroundManager.instance.addSubscriber();
  }

  Future<void> _loadShader() async {
    try {
      await _BackgroundShaderRegistry.ensureLoaded();
      if (mounted) {
        setState(() {
          // 仅触发一次重建，实际 Program 由全局注册表复用。
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
            Positioned.fill(
              child: BackgroundThemePreview(
                backgroundType: bgType,
              ),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class BackgroundThemePreview extends StatefulWidget {
  final BackgroundType backgroundType;

  const BackgroundThemePreview({
    super.key,
    required this.backgroundType,
  });

  @override
  State<BackgroundThemePreview> createState() => _BackgroundThemePreviewState();
}

class _BackgroundThemePreviewState extends State<BackgroundThemePreview> {
  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      await _BackgroundShaderRegistry.ensureLoaded();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Shader preview load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProgram = _BackgroundShaderRegistry.programFor(
      widget.backgroundType,
    );

    if (widget.backgroundType == BackgroundType.pureBlack ||
        currentProgram == null) {
      return Container(color: Colors.black);
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: _ShaderBackgroundPainter(
          currentProgram,
          BackgroundManager.instance.globalTimeNotifier,
        ),
      ),
    );
  }
}

class _ShaderBackgroundPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ValueNotifier<double> timeNotifier;

  // 核心修复：将 timeNotifier 传给 super(repaint)，Flutter 会自动在数值改变时仅重绘此画布
  _ShaderBackgroundPainter(this.program, this.timeNotifier)
      : super(repaint: timeNotifier);

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
  bool shouldRepaint(covariant _ShaderBackgroundPainter oldDelegate) {
    // 因为使用了 repaint 驱动，这里可以直接返回 false
    return false;
  }
}
