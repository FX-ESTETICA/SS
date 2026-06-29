class PlatformVideoRecord {
  const PlatformVideoRecord({
    required this.id,
    required this.authorId,
    required this.authorIdentityId,
    required this.authorName,
    required this.description,
    required this.videoUrl,
    required this.coverUrl,
    required this.streamUrl,
    required this.streamFormat,
    required this.videoObjectKey,
    required this.coverObjectKey,
    required this.streamObjectPrefix,
    required this.contentOrientation,
    required this.aspectRatioLabel,
    required this.workflowStatus,
    required this.moderationStatus,
    required this.distributionStatus,
    required this.distributionChannel,
    required this.primaryDistributionKind,
    required this.processingStatus,
    required this.lifecycleStatus,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.durationSeconds,
    required this.assetSchemaVersion,
    this.width,
    this.height,
    this.publishedAt,
    this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorIdentityId;
  final String authorName;
  final String description;
  final String videoUrl;
  final String coverUrl;
  final String streamUrl;
  final String streamFormat;
  final String videoObjectKey;
  final String? coverObjectKey;
  final String? streamObjectPrefix;
  final String contentOrientation;
  final String aspectRatioLabel;
  final String workflowStatus;
  final String moderationStatus;
  final String distributionStatus;
  final String distributionChannel;
  final String primaryDistributionKind;
  final String processingStatus;
  final String lifecycleStatus;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final double durationSeconds;
  final int assetSchemaVersion;
  final int? width;
  final int? height;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  bool get isLandscape => contentOrientation == 'landscape';

  bool get prefersStreaming =>
      primaryDistributionKind == 'hls' &&
      streamUrl.isNotEmpty &&
      streamFormat == 'hls';

  String get primaryPlaybackUrl {
    if (prefersStreaming) {
      return streamUrl;
    }
    return videoUrl;
  }

  String? get fallbackPlaybackUrl {
    if (prefersStreaming && videoUrl.isNotEmpty) {
      return videoUrl;
    }
    return null;
  }

  bool get isReadyForPlayback =>
      processingStatus == 'ready' &&
      workflowStatus == 'ready' &&
      moderationStatus == 'approved' &&
      distributionStatus == 'ready' &&
      lifecycleStatus == 'active';

  String get distributionChannelLabel {
    switch (distributionChannel) {
      case 'landscape':
        return '横屏';
      case 'private':
        return '私密';
      case 'draft':
        return '草稿';
      case 'recommendation':
      default:
        return '推荐';
    }
  }

  String get primaryDistributionLabel {
    switch (primaryDistributionKind) {
      case 'hls':
        return 'HLS主链';
      case 'cmaf':
        return 'CMAF主链';
      case 'dash':
        return 'DASH主链';
      case 'direct_file':
      default:
        return 'MP4直出';
    }
  }

  String get statusLabel {
    if (lifecycleStatus == 'archived') {
      return '已归档';
    }
    if (lifecycleStatus == 'deleted') {
      return '已删除';
    }
    if (moderationStatus == 'rejected') {
      return '审核拒绝';
    }
    if (moderationStatus == 'restricted') {
      return '受限';
    }
    if (distributionStatus == 'offline') {
      return '已下线';
    }
    if (isReadyForPlayback) {
      return '已发布';
    }
    switch (workflowStatus) {
      case 'processing':
        return '处理中';
      case 'packaging':
        return '封装中';
      case 'review_pending':
        return '待审核';
      case 'failed':
        return '处理失败';
      case 'queued':
        return '排队中';
      case 'uploaded':
      default:
        return '已上传';
    }
  }

  factory PlatformVideoRecord.fromJson(Map<String, dynamic> json) {
    return PlatformVideoRecord(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorIdentityId: json['author_identity_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '@匿名用户',
      description: json['description'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      streamUrl: json['stream_url'] as String? ?? '',
      streamFormat: json['stream_format'] as String? ?? '',
      videoObjectKey: json['video_object_key'] as String? ?? '',
      coverObjectKey: json['cover_object_key'] as String?,
      streamObjectPrefix: json['stream_object_prefix'] as String?,
      contentOrientation: _resolveContentOrientation(json),
      aspectRatioLabel: json['aspect_ratio_label'] as String? ?? '',
      workflowStatus: json['workflow_status'] as String? ?? 'uploaded',
      moderationStatus: json['moderation_status'] as String? ?? 'pending',
      distributionStatus: json['distribution_status'] as String? ?? 'pending',
      distributionChannel:
          json['distribution_channel'] as String? ?? 'recommendation',
      primaryDistributionKind:
          json['primary_distribution_kind'] as String? ?? 'direct_file',
      processingStatus: json['processing_status'] as String? ?? 'uploaded',
      lifecycleStatus: json['lifecycle_status'] as String? ?? 'active',
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0,
      assetSchemaVersion: json['asset_schema_version'] as int? ?? 1,
      width: json['width'] as int?,
      height: json['height'] as int?,
      publishedAt: _parseDateTime(json['published_at']),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static String _resolveContentOrientation(Map<String, dynamic> json) {
    final explicit = json['content_orientation'] as String?;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final width = json['width'] as int?;
    final height = json['height'] as int?;
    if (width != null && height != null && width > height) {
      return 'landscape';
    }
    return 'portrait';
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}
