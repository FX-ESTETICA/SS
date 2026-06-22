import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'video_editor_screen.dart'; // 我们下一步要创建的页面

/// 视频上传准备页 (入口)
class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo() async {
    // 1. 调用系统相册选择视频 (不限制原始大小)
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null && mounted) {
      // 2. 跳转到我们自定义的“15秒截取与端侧转码”编辑器
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoEditorScreen(file: File(video.path)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 严格暗黑基底
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('发布动态', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 极简上传按钮
            GestureDetector(
              onTap: _pickVideo,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '选择要上传的视频',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '端侧极限压缩，支持最高 4K 原片\n自动截取精彩 15 秒',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
