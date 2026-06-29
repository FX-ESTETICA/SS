import 'dart:async';
import 'dart:io';

import 'package:core_media/core_media.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';

enum PublishOverlayStage {
  idle,
  preparing,
  processing,
  uploading,
  publishing,
  completed,
  failed,
}

class PendingPublishedVideo {
  const PendingPublishedVideo({
    required this.jobId,
    required this.authorIdentityId,
    required this.primaryPlaybackUrl,
    required this.coverUrl,
    required this.authorName,
    required this.description,
    required this.width,
    required this.height,
    required this.contentOrientation,
    required this.distributionChannelLabel,
    required this.primaryDistributionLabel,
    required this.statusLabel,
    this.isPending = false,
    this.isFailed = false,
    this.canRetry = false,
    this.pendingMessage = '',
    this.errorMessage,
  });

  final String jobId;
  final String authorIdentityId;
  final String primaryPlaybackUrl;
  final String coverUrl;
  final String authorName;
  final String description;
  final int? width;
  final int? height;
  final String contentOrientation;
  final String distributionChannelLabel;
  final String primaryDistributionLabel;
  final String statusLabel;
  final bool isPending;
  final bool isFailed;
  final bool canRetry;
  final String pendingMessage;
  final String? errorMessage;
}

class PublishOverlayState {
  const PublishOverlayState({
    required this.stage,
    required this.message,
    required this.jobId,
    this.pendingVideo,
    this.completedVideo,
    this.error,
  });

  const PublishOverlayState.idle()
      : stage = PublishOverlayStage.idle,
        message = '',
        jobId = null,
        pendingVideo = null,
        completedVideo = null,
        error = null;

  final PublishOverlayStage stage;
  final String message;
  final String? jobId;
  final PendingPublishedVideo? pendingVideo;
  final PendingPublishedVideo? completedVideo;
  final String? error;

  bool get isVisible => stage != PublishOverlayStage.idle;
  bool get isActive =>
      stage == PublishOverlayStage.preparing ||
      stage == PublishOverlayStage.processing ||
      stage == PublishOverlayStage.uploading ||
      stage == PublishOverlayStage.publishing;
}

class PublishVideoRequest {
  const PublishVideoRequest({
    required this.file,
    required this.activeIdentity,
    required this.outputLayout,
    required this.trimStartSeconds,
    required this.trimEndSeconds,
    required this.coverTimeSeconds,
    this.cropSelection,
    this.description = '刚刚发布了一条新作品',
  });

  final File file;
  final UserIdentityRecord activeIdentity;
  final VideoOutputLayout outputLayout;
  final double trimStartSeconds;
  final double trimEndSeconds;
  final double coverTimeSeconds;
  final VideoCropSelection? cropSelection;
  final String description;
}

class PublishOverlayStore extends ChangeNotifier {
  PublishOverlayStore._();

  static final PublishOverlayStore instance = PublishOverlayStore._();

  PublishOverlayState _state = const PublishOverlayState.idle();
  final Map<String, PublishVideoRequest> _requestsByJobId = {};

  PublishOverlayState get state => _state;

  bool get hasActiveJob => _state.isActive;

  bool startPublish(PublishVideoRequest request) {
    if (hasActiveJob) {
      return false;
    }
    final jobId = DateTime.now().microsecondsSinceEpoch.toString();
    _requestsByJobId[jobId] = request;
    _beginPublish(jobId, request);
    return true;
  }

  bool retryFailedPublish(String jobId) {
    if (hasActiveJob) {
      return false;
    }
    final request = _requestsByJobId[jobId];
    if (request == null) {
      return false;
    }
    _beginPublish(jobId, request);
    return true;
  }

  void dismissFailure(String jobId) {
    if (_state.jobId == jobId && _state.stage == PublishOverlayStage.failed) {
      _state = const PublishOverlayState.idle();
      notifyListeners();
    }
  }

  void _beginPublish(String jobId, PublishVideoRequest request) {
    final authorName = request.activeIdentity.displayName.trim().isNotEmpty
        ? request.activeIdentity.displayName
        : '我';
    final pendingVideo = PendingPublishedVideo(
      jobId: jobId,
      authorIdentityId: request.activeIdentity.id,
      primaryPlaybackUrl: request.file.uri.toString(),
      coverUrl: '',
      authorName: authorName,
      description: request.description,
      width: request.outputLayout.targetWidth,
      height: request.outputLayout.targetHeight,
      contentOrientation: request.outputLayout.contentOrientation,
      distributionChannelLabel:
          request.outputLayout.contentOrientation == 'landscape' ? '横屏' : '推荐',
      primaryDistributionLabel: '发布中',
      statusLabel: '发布中',
      isPending: true,
      isFailed: false,
      canRetry: false,
      pendingMessage: '准备发布',
    );
    _state = PublishOverlayState(
      stage: PublishOverlayStage.preparing,
      message: '准备发布',
      jobId: jobId,
      pendingVideo: pendingVideo,
    );
    notifyListeners();
    unawaited(_runPublish(jobId, request));
  }

  void _update(
    String jobId,
    PublishOverlayStage stage,
    String message, {
    PendingPublishedVideo? pendingVideo,
    PendingPublishedVideo? completedVideo,
    String? error,
  }) {
    if (_state.jobId != jobId) {
      return;
    }
    _state = PublishOverlayState(
      stage: stage,
      message: message,
      jobId: jobId,
      pendingVideo: _copyPendingVideoWithMessage(
        pendingVideo ?? _state.pendingVideo,
        message,
      ),
      completedVideo: completedVideo,
      error: error,
    );
    notifyListeners();
  }

  PendingPublishedVideo? _copyPendingVideoWithMessage(
    PendingPublishedVideo? video,
    String message,
  ) {
    if (video == null) {
      return null;
    }
    return PendingPublishedVideo(
      jobId: video.jobId,
      authorIdentityId: video.authorIdentityId,
      primaryPlaybackUrl: video.primaryPlaybackUrl,
      coverUrl: video.coverUrl,
      authorName: video.authorName,
      description: video.description,
      width: video.width,
      height: video.height,
      contentOrientation: video.contentOrientation,
      distributionChannelLabel: video.distributionChannelLabel,
      primaryDistributionLabel: video.primaryDistributionLabel,
      statusLabel: video.statusLabel,
      isPending: video.isPending,
      isFailed: video.isFailed,
      canRetry: video.canRetry,
      pendingMessage: message,
      errorMessage: video.errorMessage,
    );
  }

  Future<void> _runPublish(String jobId, PublishVideoRequest request) async {
    try {
      final session = SupabaseService.currentSession;
      final user = SupabaseService.currentUser;
      if (session == null || user == null) {
        throw Exception('请先登录后再发布视频');
      }

      final trimStart = request.trimStartSeconds.clamp(0.0, double.infinity);
      final trimEnd = request.trimEndSeconds > trimStart
          ? request.trimEndSeconds
          : trimStart + 1.0;
      final duration = trimEnd - trimStart;
      final coverTime = request.coverTimeSeconds.clamp(trimStart, trimEnd);
      final outputLayout = request.outputLayout;

      _update(jobId, PublishOverlayStage.processing, '正在生成视频与封面');
      final result = await VideoProcessor.transcodeAndExtractCover(
        sourcePath: request.file.path,
        outputLayout: outputLayout,
        cropSelection: request.cropSelection,
        startTimeSeconds: trimStart,
        coverTimeSeconds: coverTime,
        maxDurationSeconds: duration.ceil().clamp(1, 600),
      );

      if (result == null) {
        throw Exception('视频处理失败，请检查素材后重试');
      }

      _update(jobId, PublishOverlayStage.uploading, '正在上传主视频');
      final uploadBatchPrefix = 'publish_${DateTime.now().millisecondsSinceEpoch}';
      final publishedWidth = result.width ?? outputLayout.targetWidth;
      final publishedHeight = result.height ?? outputLayout.targetHeight;
      final videoBytes = await result.videoFile.readAsBytes();
      final videoFileName =
          'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final videoContentType = _guessContentType(
        result.videoFile.path,
        fallback: 'video/mp4',
      );
      final videoChecksum = SupabaseService.computeSha256Hex(videoBytes);
      UploadedMedia videoUpload = await SupabaseService.findReusableUploadedMedia(
            mediaKind: 'video',
            checksumSha256: videoChecksum,
          ) ??
          const UploadedMedia(
            ownerId: '',
            objectKey: '',
            publicUrl: '',
            mediaKind: 'video',
            contentType: 'video/mp4',
            bytes: 0,
            checksumSha256: '',
            sourceFilename: '',
          );

      if (videoUpload.publicUrl.isEmpty) {
        final videoUploadSession = await SupabaseService.issueUploadSession(
          mediaKind: 'video',
          sourceFilename: videoFileName,
          contentType: videoContentType,
          fileSizeBytes: videoBytes.length,
          ownerIdentityId: request.activeIdentity.id,
          idempotencyKey: '${uploadBatchPrefix}_video',
          preferredObjectPrefix: uploadBatchPrefix,
          uploadPurpose: 'video_publish_primary',
          checksumSha256: videoChecksum,
          expectedWidth: publishedWidth,
          expectedHeight: publishedHeight,
          uploadMetadata: {
            'contentOrientation': outputLayout.contentOrientation,
            'aspectRatioLabel': outputLayout.aspectRatioLabel,
          },
        );

        videoUpload = await SupabaseService.uploadMedia(
          fileName: videoFileName,
          fileBytes: videoBytes,
          mediaKind: 'video',
          accessToken: session.accessToken,
          contentType: videoContentType,
          width: publishedWidth,
          height: publishedHeight,
          objectPrefix: videoUploadSession.objectPrefix,
          uploadSessionId: videoUploadSession.id,
        );
      }

      UploadedMedia? coverUpload;
      final coverFile = result.coverFile;
      if (coverFile != null && await coverFile.exists()) {
        _update(jobId, PublishOverlayStage.uploading, '正在上传封面');
        final coverBytes = await coverFile.readAsBytes();
        final coverFileName =
            'cover_${DateTime.now().millisecondsSinceEpoch}.webp';
        final coverContentType = _guessContentType(
          coverFile.path,
          fallback: 'image/webp',
        );
        final coverChecksum = SupabaseService.computeSha256Hex(coverBytes);
        coverUpload = await SupabaseService.findReusableUploadedMedia(
          mediaKind: 'cover',
          checksumSha256: coverChecksum,
        );
        if (coverUpload == null) {
          final coverUploadSession = await SupabaseService.issueUploadSession(
            mediaKind: 'cover',
            sourceFilename: coverFileName,
            contentType: coverContentType,
            fileSizeBytes: coverBytes.length,
            ownerIdentityId: request.activeIdentity.id,
            idempotencyKey: '${uploadBatchPrefix}_cover',
            preferredObjectPrefix: uploadBatchPrefix,
            uploadPurpose: 'video_publish_cover',
            checksumSha256: coverChecksum,
            expectedWidth: publishedWidth,
            expectedHeight: publishedHeight,
            uploadMetadata: {
              'contentOrientation': outputLayout.contentOrientation,
              'aspectRatioLabel': outputLayout.aspectRatioLabel,
            },
          );
          coverUpload = await SupabaseService.uploadMedia(
            fileName: coverFileName,
            fileBytes: coverBytes,
            mediaKind: 'cover',
            accessToken: session.accessToken,
            contentType: coverContentType,
            width: publishedWidth,
            height: publishedHeight,
            objectPrefix: coverUploadSession.objectPrefix,
            uploadSessionId: coverUploadSession.id,
          );
        }
      }

      _update(jobId, PublishOverlayStage.publishing, '正在发布到内容流');
      final authorName = request.activeIdentity.displayName.trim().isNotEmpty
          ? request.activeIdentity.displayName
          : (user.email?.split('@').first ?? '匿名用户');

      await SupabaseService.publishVideo(
        videoUpload: videoUpload,
        coverUpload: coverUpload,
        description: request.description,
        authorId: user.id,
        authorIdentityId: request.activeIdentity.id,
        authorName: authorName,
        durationSeconds: duration <= 0 ? 1 : duration,
        contentOrientation: outputLayout.contentOrientation,
        aspectRatioLabel: outputLayout.aspectRatioLabel,
        width: publishedWidth,
        height: publishedHeight,
      );

      final completedVideo = PendingPublishedVideo(
        jobId: jobId,
        authorIdentityId: request.activeIdentity.id,
        primaryPlaybackUrl: videoUpload.publicUrl,
        coverUrl: coverUpload?.publicUrl ?? '',
        authorName: authorName,
        description: request.description,
        width: publishedWidth,
        height: publishedHeight,
        contentOrientation: outputLayout.contentOrientation,
        distributionChannelLabel:
            outputLayout.contentOrientation == 'landscape' ? '横屏' : '推荐',
        primaryDistributionLabel: 'HEVC直出',
        statusLabel: '已发布',
        isPending: false,
        isFailed: false,
        canRetry: false,
        pendingMessage: '发布完成',
      );
      _update(
        jobId,
        PublishOverlayStage.completed,
        '发布完成',
        completedVideo: completedVideo,
      );
      await Future.delayed(const Duration(milliseconds: 3200));
      if (_state.jobId == jobId) {
        _state = const PublishOverlayState.idle();
        notifyListeners();
      }
    } catch (error) {
      final failedVideo = _state.pendingVideo == null
          ? null
          : PendingPublishedVideo(
              jobId: _state.pendingVideo!.jobId,
              authorIdentityId: _state.pendingVideo!.authorIdentityId,
              primaryPlaybackUrl: _state.pendingVideo!.primaryPlaybackUrl,
              coverUrl: _state.pendingVideo!.coverUrl,
              authorName: _state.pendingVideo!.authorName,
              description: _state.pendingVideo!.description,
              width: _state.pendingVideo!.width,
              height: _state.pendingVideo!.height,
              contentOrientation: _state.pendingVideo!.contentOrientation,
              distributionChannelLabel:
                  _state.pendingVideo!.distributionChannelLabel,
              primaryDistributionLabel: '重试发布',
              statusLabel: '发布失败',
              isPending: false,
              isFailed: true,
              canRetry: true,
              pendingMessage: '发布失败，点击重试',
              errorMessage: '$error',
            );
      _update(
        jobId,
        PublishOverlayStage.failed,
        '发布失败',
        pendingVideo: failedVideo,
        error: '$error',
      );
    }
  }

  static String _guessContentType(String path, {required String fallback}) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.webp')) return 'image/webp';
    if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerPath.endsWith('.png')) return 'image/png';
    if (lowerPath.endsWith('.mp4')) return 'video/mp4';
    if (lowerPath.endsWith('.mov')) return 'video/quicktime';
    return fallback;
  }
}
