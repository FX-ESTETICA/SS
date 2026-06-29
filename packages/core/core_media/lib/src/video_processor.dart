import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_session.dart';

int _ensureEven(int value, {required bool roundUp}) {
  if (value.isEven) {
    return value;
  }
  return roundUp ? value + 1 : math.max(2, value - 1);
}

/// 视频处理结果记录
class VideoProcessResult {
  final File videoFile;
  final File? coverFile;
  final int? width;
  final int? height;
  final File? streamManifestFile;
  final List<File> streamSegmentFiles;

  VideoProcessResult(
    this.videoFile,
    this.coverFile, {
    this.width,
    this.height,
    this.streamManifestFile,
    this.streamSegmentFiles = const [],
  });
}

enum VideoOutputLayout {
  portrait(
    contentOrientation: 'portrait',
    aspectRatioLabel: '9:16',
    targetWidth: 1080,
    targetHeight: 1920,
  ),
  landscape(
    contentOrientation: 'landscape',
    aspectRatioLabel: '16:9',
    targetWidth: 1920,
    targetHeight: 1080,
  );

  const VideoOutputLayout({
    required this.contentOrientation,
    required this.aspectRatioLabel,
    required this.targetWidth,
    required this.targetHeight,
  });

  final String contentOrientation;
  final String aspectRatioLabel;
  final int targetWidth;
  final int targetHeight;
}

class VideoCropSelection {
  const VideoCropSelection({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.leftFraction,
    required this.topFraction,
    required this.rightFraction,
    required this.bottomFraction,
  });

  final int sourceWidth;
  final int sourceHeight;
  final double leftFraction;
  final double topFraction;
  final double rightFraction;
  final double bottomFraction;

  String? toFfmpegCropFilter() {
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return null;
    }

    final left = _ensureEven(
      (sourceWidth * leftFraction.clamp(0.0, 1.0)).round(),
      roundUp: false,
    );
    final top = _ensureEven(
      (sourceHeight * topFraction.clamp(0.0, 1.0)).round(),
      roundUp: false,
    );
    final right = _ensureEven(
      (sourceWidth * rightFraction.clamp(0.0, 1.0)).round(),
      roundUp: false,
    );
    final bottom = _ensureEven(
      (sourceHeight * bottomFraction.clamp(0.0, 1.0)).round(),
      roundUp: false,
    );

    final width = _ensureEven(
      math.max(2, right - left),
      roundUp: false,
    );
    final height = _ensureEven(
      math.max(2, bottom - top),
      roundUp: false,
    );

    final isFullFrame =
        left <= 0 &&
        top <= 0 &&
        width >= _ensureEven(sourceWidth, roundUp: false) &&
        height >= _ensureEven(sourceHeight, roundUp: false);

    if (isFullFrame) {
      return null;
    }

    return 'crop=$width:$height:$left:$top';
  }
}

/// 端侧视频处理器：15秒截取、帧级封面提取与硬件加速转码
class VideoProcessor {
  static const String _streamManifestFileName = 'stream.m3u8';
  static const String _streamInitFileName = 'init.mp4';
  static const List<String> _windowsFfmpegCandidates = <String>[
    r'C:\ffmpeg\bin\ffmpeg.exe',
    r'C:\Program Files\ffmpeg\bin\ffmpeg.exe',
    r'C:\Program Files (x86)\ffmpeg\bin\ffmpeg.exe',
    r'C:\ProgramData\chocolatey\bin\ffmpeg.exe',
  ];

  static Iterable<String> _runtimeWindowsFfmpegCandidates() sync* {
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final currentDir = Directory.current.path;
    final candidates = <String>{
      '$currentDir\\ffmpeg.exe',
      '$currentDir\\bin\\ffmpeg.exe',
      '$currentDir\\tools\\ffmpeg.exe',
      '$executableDir\\ffmpeg.exe',
      '$executableDir\\bin\\ffmpeg.exe',
      '$executableDir\\tools\\ffmpeg.exe',
    };
    for (final candidate in candidates) {
      yield candidate;
    }
  }

  static Future<String?> _resolveWindowsFfmpegCommand() async {
    final envCandidate = Platform.environment['FFMPEG_PATH']?.trim();
    if (envCandidate != null && envCandidate.isNotEmpty) {
      if (File(envCandidate).existsSync()) {
        return envCandidate;
      }
      debugPrint('FFMPEG_PATH 指向的文件不存在: $envCandidate');
    }

    for (final candidate in _windowsFfmpegCandidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    for (final candidate in _runtimeWindowsFfmpegCandidates()) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    try {
      final result = await Process.run('where', const ['ffmpeg']);
      if (result.exitCode == 0) {
        final stdout = '${result.stdout}'.trim();
        final firstLine = stdout
            .split(RegExp(r'[\r\n]+'))
            .map((line) => line.trim())
            .firstWhere(
              (line) => line.isNotEmpty,
              orElse: () => '',
            );
        if (firstLine.isNotEmpty && File(firstLine).existsSync()) {
          return firstLine;
        }
      }
    } catch (error) {
      debugPrint('Windows FFmpeg 路径探测失败: $error');
    }

    return null;
  }

  /// 将用户选定的视频进行极限压缩，转码为 H.264，并抽取指定时间点的封面
  /// [sourcePath]: 原始视频路径 (可能是从 video_editor 截取后传过来的中间路径)
  /// [startTimeSeconds]: 截取开始时间
  /// [coverTimeSeconds]: 用户选定作为封面的时间点
  /// [maxDurationSeconds]: 强制限制最大时长 (默认 15)
  static Future<VideoProcessResult?> transcodeAndExtractCover({
    required String sourcePath,
    VideoOutputLayout outputLayout = VideoOutputLayout.portrait,
    VideoCropSelection? cropSelection,
    double startTimeSeconds = 0.0,
    double coverTimeSeconds = 0.0,
    int maxDurationSeconds = 15,
  }) async {
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final targetVideoPath = '${tempDir.path}/${timestamp}_compressed.mp4';
    final targetCoverPath = '${tempDir.path}/${timestamp}_cover.webp';
    final streamDir = Directory('${tempDir.path}/${timestamp}_hls');

    // Windows 环境下调用系统中可能存在的 ffmpeg
    if (Platform.isWindows) {
      debugPrint('Windows 环境下尝试调用本地 FFmpeg 进程进行转码...');
      try {
        final ffmpegCommand = await _resolveWindowsFfmpegCommand();
        if (ffmpegCommand == null) {
          debugPrint('==================================================================');
          debugPrint('【前置条件缺失】: 当前 Windows 设备未发现可执行 FFmpeg。');
          debugPrint('请安装 FFmpeg、设置 FFMPEG_PATH，或将 ffmpeg.exe 放到应用约定目录。');
          debugPrint('当前将回退到原片直传，HLS 主链与封面抽帧不会生成。');
          debugPrint('==================================================================');
          return VideoProcessResult(File(sourcePath), null);
        }

        final targetVideoFilter = _buildTargetVideoFilter(
          outputLayout: outputLayout,
          cropSelection: cropSelection,
        );

        // Windows 的转码参数，同样强力注入 faststart
        final args = [
          '-y', // 覆盖输出文件
          '-ss', '$startTimeSeconds',
          '-i', sourcePath,
          '-t', '$maxDurationSeconds',
          '-vf', targetVideoFilter,
          '-c:v', 'libx264',
          '-crf', '28',
          '-preset', 'veryfast',
          '-c:a', 'aac',
          '-b:a', '128k',
          '-movflags', 'faststart',
          targetVideoPath,
        ];
        
        final result = await Process.run(ffmpegCommand, args);
        if (result.exitCode != 0) {
          debugPrint('Windows FFmpeg 转码失败: ${result.stderr}');
          debugPrint('==================================================================');
          debugPrint('【前置条件缺失】: FFmpeg 转码失败，当前回退为原片直传。');
          debugPrint('请检查 FFmpeg 安装状态、编码器能力与执行权限。');
          debugPrint('==================================================================');
          await Future.delayed(const Duration(seconds: 1));
          return VideoProcessResult(File(sourcePath), null);
        }

        // 抽取封面
        final coverArgs = [
          '-y',
          '-ss', '$coverTimeSeconds',
          '-i', sourcePath,
          '-vframes', '1',
          '-vf', targetVideoFilter,
          '-c:v', 'libwebp',
          targetCoverPath,
        ];
        await Process.run(ffmpegCommand, coverArgs);
        
        final streamPackage = await _buildWindowsHlsPackage(
          ffmpegCommand: ffmpegCommand,
          sourceVideoPath: targetVideoPath,
          streamDir: streamDir,
        );

        return VideoProcessResult(
          File(targetVideoPath),
          File(targetCoverPath),
          width: outputLayout.targetWidth,
          height: outputLayout.targetHeight,
          streamManifestFile: streamPackage?.manifestFile,
          streamSegmentFiles: streamPackage?.segmentFiles ?? const [],
        );
      } catch (e) {
        debugPrint('无法调用 FFmpeg: $e');
        return VideoProcessResult(File(sourcePath), null);
      }
    }

    // 1. FFmpeg 命令构建：强制转码 H.264，限制时长，压榨体积，【核心：注入 faststart】
    // -ss : 跳转到指定截取开始时间
    // -t 15 : 强制最大 15 秒
    // -vf ... : 按用户最终选择输出竖屏或横屏母版，保证推荐流与横屏区彻底分流
    // -c:v libx264 : 使用 H.264 编码 (保证全平台兼容)
    // -crf 28 : 控制画质和体积平衡，数字越大体积越小画质越低
    // -preset veryfast : 转码速度优先
    // -movflags faststart : 【降维打击核心】将 moov atom 移动到文件头部，实现真正的“边下边播”！
    final targetVideoFilter = _buildTargetVideoFilter(
      outputLayout: outputLayout,
      cropSelection: cropSelection,
    );
    final videoCmd =
        '-ss $startTimeSeconds -i "$sourcePath" -t $maxDurationSeconds '
        '-vf $targetVideoFilter '
        '-c:v libx264 -crf 28 -preset veryfast -c:a aac -b:a 128k '
        '-movflags faststart "$targetVideoPath"';

    // 执行视频转码
    FFmpegSession videoSession = await FFmpegKit.execute(videoCmd);
    final videoReturnCode = await videoSession.getReturnCode();

    if (!ReturnCode.isSuccess(videoReturnCode)) {
      // 转码失败
      return null;
    }

    // 2. FFmpeg 命令构建：抽取帧级封面并转为 WebP
    // -ss : 跳转到指定时间
    // -vframes 1 : 仅抽取 1 帧
    // -vf : 与视频统一为最终发布母版，避免播放面尺寸跳动
    // -c:v libwebp : 编码为 WebP
    final coverCmd =
        '-ss $coverTimeSeconds -i "$sourcePath" -vframes 1 '
        '-vf $targetVideoFilter '
        '-c:v libwebp "$targetCoverPath"';

    // 执行封面抽取
    FFmpegSession coverSession = await FFmpegKit.execute(coverCmd);
    final coverReturnCode = await coverSession.getReturnCode();

    if (!ReturnCode.isSuccess(coverReturnCode)) {
      // 封面抽取失败，可以考虑给个默认封面，但极致要求下直接返回 null 或者兜底逻辑
      return null;
    }

    final streamPackage = await _buildMobileHlsPackage(
      sourceVideoPath: targetVideoPath,
      streamDir: streamDir,
    );

    return VideoProcessResult(
      File(targetVideoPath),
      File(targetCoverPath),
      width: outputLayout.targetWidth,
      height: outputLayout.targetHeight,
      streamManifestFile: streamPackage?.manifestFile,
      streamSegmentFiles: streamPackage?.segmentFiles ?? const [],
    );
  }

  static String _buildTargetVideoFilter({
    required VideoOutputLayout outputLayout,
    VideoCropSelection? cropSelection,
  }) {
    final filters = <String>[];
    final cropFilter = cropSelection?.toFfmpegCropFilter();
    if (cropFilter != null && cropFilter.isNotEmpty) {
      filters.add(cropFilter);
      filters.add(
        'scale=${outputLayout.targetWidth}:${outputLayout.targetHeight}:flags=lanczos',
      );
    } else {
      filters.add(
        'scale=${outputLayout.targetWidth}:${outputLayout.targetHeight}:'
        'force_original_aspect_ratio=increase:flags=lanczos',
      );
      filters.add(
        'crop=${outputLayout.targetWidth}:${outputLayout.targetHeight}',
      );
    }
    filters.add('setsar=1');
    return filters.join(',');
  }


  static Future<_StreamPackage?> _buildWindowsHlsPackage({
    required String ffmpegCommand,
    required String sourceVideoPath,
    required Directory streamDir,
  }) async {
    await streamDir.create(recursive: true);
    final manifestPath = '${streamDir.path}/$_streamManifestFileName';
    final segmentPattern = '${streamDir.path}/seg_%05d.m4s';

    final args = [
      '-y',
      '-i',
      sourceVideoPath,
      '-c',
      'copy',
      '-f',
      'hls',
      '-hls_time',
      '1',
      '-hls_playlist_type',
      'vod',
      '-hls_segment_type',
      'fmp4',
      '-hls_fmp4_init_filename',
      _streamInitFileName,
      '-hls_flags',
      'independent_segments',
      '-hls_segment_filename',
      segmentPattern,
      manifestPath,
    ];

    final result = await Process.run(ffmpegCommand, args);
    if (result.exitCode != 0) {
      debugPrint('Windows HLS 打包失败: ${result.stderr}');
      return null;
    }

    return _readStreamPackage(streamDir);
  }

  static Future<_StreamPackage?> _buildMobileHlsPackage({
    required String sourceVideoPath,
    required Directory streamDir,
  }) async {
    await streamDir.create(recursive: true);
    final manifestPath = '${streamDir.path}/$_streamManifestFileName';
    final segmentPattern = '${streamDir.path}/seg_%05d.m4s';
    final hlsCmd =
        '-i "$sourceVideoPath" -c copy -f hls -hls_time 1 '
        '-hls_playlist_type vod -hls_segment_type fmp4 '
        '-hls_fmp4_init_filename $_streamInitFileName '
        '-hls_flags independent_segments '
        '-hls_segment_filename "$segmentPattern" "$manifestPath"';

    final session = await FFmpegKit.execute(hlsCmd);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      return null;
    }

    return _readStreamPackage(streamDir);
  }

  static _StreamPackage? _readStreamPackage(Directory streamDir) {
    final manifestFile = File('${streamDir.path}/$_streamManifestFileName');
    if (!manifestFile.existsSync()) {
      return null;
    }

    final segmentFiles = streamDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path != manifestFile.path)
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return _StreamPackage(
      manifestFile: manifestFile,
      segmentFiles: segmentFiles,
    );
  }
}

class _StreamPackage {
  final File manifestFile;
  final List<File> segmentFiles;

  const _StreamPackage({
    required this.manifestFile,
    required this.segmentFiles,
  });
}
