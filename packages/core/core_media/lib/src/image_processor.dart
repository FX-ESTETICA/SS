import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';

/// 端侧图片处理器：极致压缩与所见即所得裁剪
class ImageProcessor {
  /// 开启全屏沉浸式裁剪，并将结果极限压缩为 WebP 格式
  /// 返回压缩后的文件对象
  static Future<File?> cropAndCompress({
    required String sourcePath,
    required BuildContext context,
    int maxLongSide = 1920, // 极限压榨，1920 足够手机 2K 屏和桌面端瀑布流
    int quality = 85,
  }) async {
    // 1. 调用 image_cropper 实现所见即所得裁剪
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: '调整图片',
            toolbarColor: Colors.black, // 严格遵守暗黑/沉浸底色红线
            toolbarWidgetColor: Colors.white, // 纯白前景色红线
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
        ),
        IOSUiSettings(
          title: '调整图片',
          cancelButtonTitle: '取消',
          doneButtonTitle: '完成',
        ),
      ],
    );

    if (croppedFile == null) return null;

    // 2. 获取临时目录，准备 WebP 输出
    final tempDir = Directory.systemTemp;
    final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.webp';

    // 3. 调用底层的 C++ / libjpeg-turbo / WebP 编码器进行极限压缩
    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      croppedFile.path,
      targetPath,
      minWidth: maxLongSide,
      minHeight: maxLongSide,
      quality: quality,
      format: CompressFormat.webp, // 强制转为 WebP，打破画质与体积的悖论
    );

    if (compressedXFile != null) {
      return File(compressedXFile.path);
    }

    return null;
  }
}
