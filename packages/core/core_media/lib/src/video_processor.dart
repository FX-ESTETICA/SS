import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_session.dart';

/// 视频处理结果记录
class VideoProcessResult {
  final File videoFile;
  final File? coverFile;

  VideoProcessResult(this.videoFile, this.coverFile);
}

/// 端侧视频处理器：15秒截取、帧级封面提取与硬件加速转码
class VideoProcessor {
  /// 将用户选定的视频进行极限压缩，转码为 H.264，并抽取指定时间点的封面
  /// [sourcePath]: 原始视频路径 (可能是从 video_editor 截取后传过来的中间路径)
  /// [startTimeSeconds]: 截取开始时间
  /// [coverTimeSeconds]: 用户选定作为封面的时间点
  /// [maxDurationSeconds]: 强制限制最大时长 (默认 15)
  static Future<VideoProcessResult?> transcodeAndExtractCover({
    required String sourcePath,
    double startTimeSeconds = 0.0,
    double coverTimeSeconds = 0.0,
    int maxDurationSeconds = 15,
  }) async {
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final targetVideoPath = '${tempDir.path}/${timestamp}_compressed.mp4';
    final targetCoverPath = '${tempDir.path}/${timestamp}_cover.webp';

    // Windows 环境下调用系统中可能存在的 ffmpeg
    if (Platform.isWindows) {
      debugPrint('Windows 环境下尝试调用本地 FFmpeg 进程进行转码...');
      try {
        // Windows 的转码参数，同样强力注入 faststart
        final args = [
          '-y', // 覆盖输出文件
          '-ss', '$startTimeSeconds',
          '-i', sourcePath,
          '-t', '$maxDurationSeconds',
          '-vf', 'scale=-2:720',
          '-c:v', 'libx264',
          '-crf', '28',
          '-preset', 'veryfast',
          '-c:a', 'aac',
          '-b:a', '128k',
          '-movflags', 'faststart',
          targetVideoPath,
        ];
        
        final result = await Process.run('ffmpeg', args);
        if (result.exitCode != 0) {
          debugPrint('Windows FFmpeg 转码失败: ${result.stderr}');
          // 如果系统没有 ffmpeg，为了不阻断流程，只能妥协返回原片，但必须警告用户
          debugPrint('==================================================================');
          debugPrint('【致命警告】: 系统未安装 FFmpeg！无法注入 faststart。');
          debugPrint('为了达到顶级秒开体验，请在电脑上安装 FFmpeg 并添加到环境变量。');
          debugPrint('当前将回退到原片直传，您将无法体验到真正的秒开！');
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
          '-c:v', 'libwebp',
          targetCoverPath,
        ];
        await Process.run('ffmpeg', coverArgs);
        
        return VideoProcessResult(File(targetVideoPath), File(targetCoverPath));
      } catch (e) {
        debugPrint('无法调用 FFmpeg: $e');
        return VideoProcessResult(File(sourcePath), null);
      }
    }

    // 1. FFmpeg 命令构建：强制转码 H.264，限制时长，压榨体积，【核心：注入 faststart】
    // -ss : 跳转到指定截取开始时间
    // -t 15 : 强制最大 15 秒
    // -vf scale=-2:720 : 动态缩放，高度限制为 720p，宽度自动对齐
    // -c:v libx264 : 使用 H.264 编码 (保证全平台兼容)
    // -crf 28 : 控制画质和体积平衡，数字越大体积越小画质越低
    // -preset veryfast : 转码速度优先
    // -movflags faststart : 【降维打击核心】将 moov atom 移动到文件头部，实现真正的“边下边播”！
    final videoCmd =
        '-ss $startTimeSeconds -i "$sourcePath" -t $maxDurationSeconds -vf scale=-2:720 -c:v libx264 -crf 28 -preset veryfast -c:a aac -b:a 128k -movflags faststart "$targetVideoPath"';

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
    // -c:v libwebp : 编码为 WebP
    final coverCmd =
        '-ss $coverTimeSeconds -i "$sourcePath" -vframes 1 -c:v libwebp "$targetCoverPath"';

    // 执行封面抽取
    FFmpegSession coverSession = await FFmpegKit.execute(coverCmd);
    final coverReturnCode = await coverSession.getReturnCode();

    if (!ReturnCode.isSuccess(coverReturnCode)) {
      // 封面抽取失败，可以考虑给个默认封面，但极致要求下直接返回 null 或者兜底逻辑
      return null;
    }

    return VideoProcessResult(
      File(targetVideoPath),
      File(targetCoverPath),
    );
  }
}
