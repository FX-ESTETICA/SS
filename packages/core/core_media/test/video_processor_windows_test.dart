import 'dart:io';

import 'package:core_media/core_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows bundled FFmpeg can transcode HEVC MP4 and WebP cover', () async {
    if (!Platform.isWindows) {
      return;
    }

    final originalCwd = Directory.current;
    final tempDir = await Directory.systemTemp.createTemp(
      'core_media_windows_ffmpeg_test_',
    );
    final toolsDir = Directory('${tempDir.path}\\tools');
    await toolsDir.create(recursive: true);

    try {
      final bundledFfmpeg = File(
        originalCwd.uri
            .resolve(
              '../../../apps/zhixuan_main/windows/third_party/ffmpeg/ffmpeg.exe',
            )
            .toFilePath(windows: true),
      );
      expect(
        bundledFfmpeg.existsSync(),
        isTrue,
        reason: '缺少项目内打包 FFmpeg，无法验证 Windows 媒体链路',
      );

      final runtimeFfmpeg = File('${toolsDir.path}\\ffmpeg.exe');
      await bundledFfmpeg.copy(runtimeFfmpeg.path);

      final sourceVideo = File('${tempDir.path}\\source.mp4');
      final synthResult = await Process.run(runtimeFfmpeg.path, [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=360x640:rate=30',
        '-f',
        'lavfi',
        '-i',
        'anullsrc=r=44100:cl=stereo',
        '-t',
        '2',
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-shortest',
        sourceVideo.path,
      ]);
      expect(
        synthResult.exitCode,
        0,
        reason: '合成测试视频失败: ${synthResult.stderr}',
      );
      expect(sourceVideo.existsSync(), isTrue);

      Directory.current = tempDir.path;

      final result = await VideoProcessor.transcodeAndExtractCover(
        sourcePath: sourceVideo.path,
        outputLayout: VideoOutputLayout.portrait,
        startTimeSeconds: 0,
        coverTimeSeconds: 0,
        maxDurationSeconds: 2,
      );

      expect(result, isNotNull);
      expect(result!.videoFile.existsSync(), isTrue);
      expect(result.coverFile?.existsSync(), isTrue);
      expect(result.videoFile.path.toLowerCase().endsWith('.mp4'), isTrue);
      expect(result.coverFile?.path.toLowerCase().endsWith('.webp'), isTrue);
      expect(result.width, VideoOutputLayout.portrait.targetWidth);
      expect(result.height, VideoOutputLayout.portrait.targetHeight);
    } finally {
      Directory.current = originalCwd.path;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}
