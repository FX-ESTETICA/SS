import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/platform_video_record.dart';

// @AI_CORE_MECHANISM: [2026-06-26] 基于 Riverpod 的 Supabase 注入
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// 核心数据/云端服务入口
/// 提供认证、数据库、存储等全球加速服务的统一封装。
/// 不再作为单例暴露业务方法，只保留基础的 init，业务应通过 Repository 层封装
class UploadedMedia {
  final String ownerId;
  final String objectKey;
  final String? objectPrefix;
  final String? uploadSessionId;
  final String publicUrl;
  final String mediaKind;
  final String contentType;
  final int bytes;
  final String checksumSha256;
  final String sourceFilename;
  final int? width;
  final int? height;

  const UploadedMedia({
    required this.ownerId,
    required this.objectKey,
    this.objectPrefix,
    this.uploadSessionId,
    required this.publicUrl,
    required this.mediaKind,
    required this.contentType,
    required this.bytes,
    required this.checksumSha256,
    required this.sourceFilename,
    this.width,
    this.height,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    return UploadedMedia(
      ownerId: json['ownerId'] as String? ?? '',
      objectKey: json['objectKey'] as String? ?? '',
      objectPrefix: json['objectPrefix'] as String?,
      uploadSessionId: json['uploadSessionId'] as String?,
      publicUrl: json['publicUrl'] as String? ?? '',
      mediaKind: json['mediaKind'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      bytes: json['bytes'] as int? ?? 0,
      checksumSha256: json['checksumSha256'] as String? ?? '',
      sourceFilename: json['sourceFilename'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class UploadSessionPlan {
  const UploadSessionPlan({
    required this.id,
    required this.ownerId,
    required this.mediaKind,
    required this.sourceFilename,
    required this.contentType,
    required this.idempotencyKey,
    required this.objectPrefix,
    required this.status,
    required this.resumeStrategy,
    required this.expiresAt,
    this.ownerIdentityId,
    this.fileSizeBytes,
    this.checksumSha256,
    this.retryCount = 0,
    this.expectedWidth,
    this.expectedHeight,
    this.outputPayload = const <String, dynamic>{},
  });

  final String id;
  final String ownerId;
  final String? ownerIdentityId;
  final String mediaKind;
  final String sourceFilename;
  final String contentType;
  final int? fileSizeBytes;
  final String? checksumSha256;
  final String idempotencyKey;
  final String objectPrefix;
  final String status;
  final String resumeStrategy;
  final DateTime? expiresAt;
  final int retryCount;
  final int? expectedWidth;
  final int? expectedHeight;
  final Map<String, dynamic> outputPayload;

  factory UploadSessionPlan.fromJson(Map<String, dynamic> json) {
    return UploadSessionPlan(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      ownerIdentityId: json['owner_identity_id'] as String?,
      mediaKind: json['media_kind'] as String? ?? '',
      sourceFilename: json['source_filename'] as String? ?? '',
      contentType: json['content_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: json['file_size_bytes'] as int?,
      checksumSha256: json['checksum_sha256'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      objectPrefix: json['object_prefix'] as String? ?? '',
      status: json['status'] as String? ?? 'issued',
      resumeStrategy: json['resume_strategy'] as String? ?? 'single_request',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      retryCount: json['retry_count'] as int? ?? 0,
      expectedWidth: json['expected_width'] as int?,
      expectedHeight: json['expected_height'] as int?,
      outputPayload: Map<String, dynamic>.from(
        json['output_payload'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }
}

class SupabaseService {
  SupabaseService._(); // 私有化构造函数，实现单例模式

  static final SupabaseService instance = SupabaseService._();

  /// 获取当前客户端实例
  static SupabaseClient get client => Supabase.instance.client;

  /// 初始化云端引擎（必须在 App 启动时调用）
  /// [url] Supabase 提供的 API URL
  /// [publishableKey] Supabase 提供的匿名访问密钥
  static Future<void> initialize({
    required String url,
    required String publishableKey,
  }) async {
    await Supabase.initialize(
      url: url,
      // ignore: deprecated_member_use
      anonKey: publishableKey,
    );
  }

  /// 提供获取 Auth, Database, Storage 的快捷入口，以便于底层代码直接调用
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
  static final Random _random = Random.secure();

  // ---------------------------------------------------------------------------
  // @AI_CONTEXT: [2026-06-26] 以下方法为临时恢复，以解决其他模块（商城、IM、视频）的编译报错。
  // 在后续的重构中，这些方法应当被迁移到各自模块的 Repository 中，并遵循 TaskEither 规范。
  // ---------------------------------------------------------------------------

  /// 1. 极致登录：获取当前用户的会话状态
  static Session? get currentSession => client.auth.currentSession;
  static User? get currentUser => client.auth.currentUser;

  /// 监听登录状态变化
  static Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;

  /// 更新用户资料 (如头像、昵称)
  static Future<UserResponse> updateUserMetadata(
    Map<String, dynamic> metadata,
  ) async {
    return await client.auth.updateUser(UserAttributes(data: metadata));
  }

  /// 2. 视频流获取：从云端数据库中查询视频列表
  static Future<List<PlatformVideoRecord>> fetchVideos({
    int limit = 10,
    int offset = 0,
    String? distributionChannel,
  }) async {
    try {
      var query = client
          .from('videos')
          .select()
          .eq('processing_status', 'ready')
          .eq('workflow_status', 'ready')
          .eq('moderation_status', 'approved')
          .eq('distribution_status', 'ready')
          .eq('lifecycle_status', 'active');

      if (distributionChannel != null && distributionChannel.isNotEmpty) {
        query = query.eq('distribution_channel', distributionChannel);
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(
        data,
      ).map(PlatformVideoRecord.fromJson).toList();
    } catch (e) {
      // 【顶级架构约束】：绝对不提供本地假数据兜底。如果断网或报错，直接把错误抛给 UI 层处理。
      rethrow;
    }
  }

  /// 获取我发布的视频
  static Future<List<PlatformVideoRecord>> fetchMyVideos(
    String authorId, {
    String? authorIdentityId,
  }) async {
    try {
      var query = client
          .from('videos')
          .select()
          .eq('author_id', authorId)
          .neq('lifecycle_status', 'deleted');

      if (authorIdentityId != null && authorIdentityId.isNotEmpty) {
        query = query.eq('author_identity_id', authorIdentityId);
      }

      final data = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(
        data,
      ).map(PlatformVideoRecord.fromJson).toList();
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMyMediaAssets() async {
    final user = currentUser;
    if (user == null) {
      throw Exception('请先登录后再查看媒体资产');
    }

    final data = await client
        .from('media_assets')
        .select()
        .eq('owner_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<UploadSessionPlan> issueUploadSession({
    required String mediaKind,
    required String sourceFilename,
    required String contentType,
    required int fileSizeBytes,
    String? ownerIdentityId,
    String? idempotencyKey,
    String? preferredObjectPrefix,
    String uploadPurpose = 'generic',
    String resumeStrategy = 'single_request',
    String? checksumSha256,
    int? expectedWidth,
    int? expectedHeight,
    Map<String, dynamic>? uploadMetadata,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('请先登录后再创建上传会话');
    }

    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      final existingSession = await _findUploadSessionByIdempotency(
        ownerId: user.id,
        idempotencyKey: idempotencyKey,
      );
      if (existingSession != null) {
        if (
            existingSession.status == 'failed' ||
            existingSession.status == 'abandoned') {
          return _reopenUploadSession(
            sessionId: existingSession.id,
            sourceFilename: sourceFilename,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes,
            checksumSha256: checksumSha256,
            expectedWidth: expectedWidth,
            expectedHeight: expectedHeight,
            uploadMetadata: uploadMetadata,
            nextRetryCount: existingSession.retryCount + 1,
          );
        }
        return existingSession;
      }
    }

    final objectPrefix =
        _sanitizeUploadToken(preferredObjectPrefix) ?? _generateUploadToken();
    final finalIdempotencyKey =
        _sanitizeUploadToken(idempotencyKey) ?? 'idem_$objectPrefix';

    final inserted = await client
        .from('media_upload_sessions')
        .insert({
          'owner_id': user.id,
          'owner_identity_id': ownerIdentityId,
          'media_kind': mediaKind,
          'upload_purpose': uploadPurpose,
          'source_filename': sourceFilename,
          'content_type': contentType,
          'file_size_bytes': fileSizeBytes,
          'checksum_sha256': checksumSha256,
          'idempotency_key': finalIdempotencyKey,
          'object_prefix': objectPrefix,
          'status': 'issued',
          'expected_width': expectedWidth,
          'expected_height': expectedHeight,
          'resume_strategy': resumeStrategy,
          'upload_metadata': uploadMetadata ?? const <String, dynamic>{},
        })
        .select()
        .single();

    return UploadSessionPlan.fromJson(Map<String, dynamic>.from(inserted));
  }

  static Future<UploadedMedia?> findReusableUploadedMedia({
    required String mediaKind,
    required String checksumSha256,
  }) async {
    final user = currentUser;
    if (user == null || checksumSha256.trim().isEmpty) {
      return null;
    }

    final reusableAsset = await _findReusableMediaAsset(
      ownerId: user.id,
      mediaKind: mediaKind,
      checksumSha256: checksumSha256,
    );
    if (reusableAsset != null) {
      return reusableAsset;
    }

    return _findReusableUploadedSessionMedia(
      ownerId: user.id,
      mediaKind: mediaKind,
      checksumSha256: checksumSha256,
    );
  }

  /// 顶级架构：直通 R2 边缘节点上传链路
  /// 通过 Worker 统一接管认证、对象命名与元数据返回
  static Future<UploadedMedia> uploadMedia({
    required String fileName,
    required List<int> fileBytes,
    required String mediaKind,
    required String accessToken,
    String contentType = 'application/octet-stream',
    int? width,
    int? height,
    String? objectPrefix,
    String? uploadSessionId,
  }) async {
    try {
      final workerUri = Uri.parse(
        'https://zhixuan-media-upload.499755740.workers.dev',
      ).replace(
        queryParameters: {
          'filename': fileName,
          'kind': mediaKind,
          if (width != null) 'width': '$width',
          if (height != null) 'height': '$height',
          if (objectPrefix != null && objectPrefix.isNotEmpty)
            'prefix': objectPrefix,
          if (uploadSessionId != null && uploadSessionId.isNotEmpty)
            'upload_session_id': uploadSessionId,
        },
      );

      final response = await Dio().put(
        workerUri.toString(),
        data: fileBytes,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': contentType,
          },
        ),
      );

      if (response.statusCode == 200) {
        final payload = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : Map<String, dynamic>.from(response.data as Map);
        if (uploadSessionId != null && uploadSessionId.isNotEmpty) {
          payload['uploadSessionId'] = uploadSessionId;
        }
        return UploadedMedia.fromJson(payload);
      } else {
        throw Exception('Worker 拒绝了请求: ${response.data}');
      }
    } catch (e) {
      throw Exception('直传 R2 边缘节点失败: $e');
    }
  }

  /// 发布视频动态：写入数据库 (升级版：支持独立封面和默认计数器)
  static Future<void> publishVideo({
    required UploadedMedia videoUpload,
    UploadedMedia? coverUpload,
    UploadedMedia? streamManifestUpload,
    required String description,
    required String authorId,
    required String authorIdentityId,
    required String authorName,
    required double durationSeconds,
    required String contentOrientation,
    required String aspectRatioLabel,
    int? width,
    int? height,
    String? streamObjectPrefix,
    String? streamFormat,
  }) async {
    final finalDescription = description.trim();
    final now = DateTime.now().toUtc();
    final publishedAt = now.toIso8601String();
    final hasStream = streamManifestUpload != null;
    final distributionChannel = contentOrientation == 'landscape'
        ? 'landscape'
        : 'recommendation';
    final primaryDistributionKind = hasStream ? 'hls' : 'direct_file';
    final videoAssetRole = hasStream ? 'fallback_playback' : 'playback_file';
    final videoProcessingProfile = hasStream
        ? 'mp4_fallback'
        : 'mp4_primary_distribution';

    final dbVideoData = {
      'author_id': authorId,
      'author_identity_id': authorIdentityId,
      'video_url': videoUpload.publicUrl,
      'video_object_key': videoUpload.objectKey,
      'cover_url': coverUpload?.publicUrl ?? '',
      'cover_object_key': coverUpload?.objectKey,
      'stream_url': streamManifestUpload?.publicUrl,
      'stream_object_prefix': streamObjectPrefix,
      'stream_format': streamFormat,
      'description': finalDescription,
      'author_name': authorName,
      'created_at': publishedAt,
      'view_count': 0,
      'like_count': 0,
      'comment_count': 0,
      'share_count': 0,
      'duration_seconds': durationSeconds,
      'width': width,
      'height': height,
      'content_orientation': contentOrientation,
      'aspect_ratio_label': aspectRatioLabel,
      'processing_status': 'ready',
      'workflow_status': 'ready',
      'moderation_status': 'approved',
      'distribution_status': 'ready',
      'distribution_channel': distributionChannel,
      'primary_distribution_kind': primaryDistributionKind,
      'asset_schema_version': 1,
      'published_at': publishedAt,
      'ingest_source': 'desktop_client',
    };

    final insertedVideo =
        await client.from('videos').insert(dbVideoData).select('id').single();

    final videoId = insertedVideo['id'] as String;
    final mediaRecords = <Map<String, dynamic>>[
      {
        'owner_id': authorId,
        'owner_identity_id': authorIdentityId,
        'entity_type': 'video',
        'entity_id': videoId,
        'media_kind': 'video',
        'bucket_name': 'zhixuan-media',
        'object_key': videoUpload.objectKey,
        'public_url': videoUpload.publicUrl,
        'mime_type': videoUpload.contentType,
        'bytes': videoUpload.bytes,
        'checksum_sha256': videoUpload.checksumSha256,
        'source_filename': videoUpload.sourceFilename,
        'status': 'ready',
        'asset_role': videoAssetRole,
        'asset_scope': 'distribution',
        'asset_family': 'playback',
        'storage_tier': 'hot',
        'availability_status': 'online',
        'processing_profile': videoProcessingProfile,
        'asset_metadata': {
          'contentOrientation': contentOrientation,
          'aspectRatioLabel': aspectRatioLabel,
          'width': width ?? videoUpload.width,
          'height': height ?? videoUpload.height,
          'distributionChannel': distributionChannel,
          'isPrimaryDistribution': !hasStream,
        },
        'retention_class': 'standard',
        'last_verified_at': publishedAt,
      },
    ];

    if (coverUpload != null) {
      mediaRecords.add({
        'owner_id': authorId,
        'owner_identity_id': authorIdentityId,
        'entity_type': 'video',
        'entity_id': videoId,
        'media_kind': 'cover',
        'bucket_name': 'zhixuan-media',
        'object_key': coverUpload.objectKey,
        'public_url': coverUpload.publicUrl,
        'mime_type': coverUpload.contentType,
        'bytes': coverUpload.bytes,
        'checksum_sha256': coverUpload.checksumSha256,
        'source_filename': coverUpload.sourceFilename,
        'status': 'ready',
        'asset_role': 'cover',
        'asset_scope': 'presentation',
        'asset_family': 'cover',
        'storage_tier': 'hot',
        'availability_status': 'online',
        'processing_profile': 'webp_cover',
        'asset_metadata': {
          'contentOrientation': contentOrientation,
          'aspectRatioLabel': aspectRatioLabel,
          'width': width ?? coverUpload.width,
          'height': height ?? coverUpload.height,
        },
        'retention_class': 'standard',
        'last_verified_at': publishedAt,
      });
    }

    if (streamManifestUpload != null) {
      mediaRecords.add({
        'owner_id': authorId,
        'owner_identity_id': authorIdentityId,
        'entity_type': 'video',
        'entity_id': videoId,
        'media_kind': 'stream_manifest',
        'bucket_name': 'zhixuan-media',
        'object_key': streamManifestUpload.objectKey,
        'public_url': streamManifestUpload.publicUrl,
        'mime_type': streamManifestUpload.contentType,
        'bytes': streamManifestUpload.bytes,
        'checksum_sha256': streamManifestUpload.checksumSha256,
        'source_filename': streamManifestUpload.sourceFilename,
        'status': 'ready',
        'asset_role': 'stream_manifest',
        'asset_scope': 'distribution',
        'asset_family': 'playback',
        'storage_tier': 'hot',
        'availability_status': 'online',
        'processing_profile': 'single_quality_hls_manifest',
        'asset_metadata': {
          'contentOrientation': contentOrientation,
          'aspectRatioLabel': aspectRatioLabel,
          'width': width ?? streamManifestUpload.width,
          'height': height ?? streamManifestUpload.height,
          'streamObjectPrefix': streamObjectPrefix,
          'streamFormat': streamFormat ?? 'hls',
          'isPrimaryDistribution': true,
        },
        'retention_class': 'standard',
        'last_verified_at': publishedAt,
      });
    }

    await client.from('media_assets').insert(mediaRecords);

    await client.from('video_pipeline_jobs').insert({
      'video_id': videoId,
      'owner_id': authorId,
      'owner_identity_id': authorIdentityId,
      'job_type': 'publish',
      'status': 'completed',
      'source_origin': 'desktop_client',
      'attempt_count': 1,
      'started_at': publishedAt,
      'finished_at': publishedAt,
      'input_payload': {
        'contentOrientation': contentOrientation,
        'aspectRatioLabel': aspectRatioLabel,
        'hasCover': coverUpload != null,
        'hasStream': hasStream,
        'streamFormat': streamFormat,
      },
      'output_payload': {
        'videoObjectKey': videoUpload.objectKey,
        'coverObjectKey': coverUpload?.objectKey,
        'streamObjectPrefix': streamObjectPrefix,
        'primaryDistributionKind': primaryDistributionKind,
        'distributionChannel': distributionChannel,
      },
    });

    await consumeUploadSessions([
      videoUpload.uploadSessionId,
      coverUpload?.uploadSessionId,
      streamManifestUpload?.uploadSessionId,
    ]);
  }

  static Future<void> archiveVideo(
    String videoId, {
    String? authorIdentityId,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('请先登录后再归档视频');
    }

    final now = DateTime.now().toUtc();
    final purgeAfter = now.add(const Duration(days: 180));

    final videoUpdate = client
        .from('videos')
        .update({
          'lifecycle_status': 'archived',
          'archived_at': now.toIso8601String(),
        })
        .eq('id', videoId)
        .eq('author_id', user.id);
    if (authorIdentityId != null && authorIdentityId.isNotEmpty) {
      videoUpdate.eq('author_identity_id', authorIdentityId);
    }
    await videoUpdate;

    final mediaUpdate = client
        .from('media_assets')
        .update({
          'status': 'archived',
          'archived_at': now.toIso8601String(),
          'purge_after': purgeAfter.toIso8601String(),
          'last_verified_at': now.toIso8601String(),
        })
        .eq('entity_type', 'video')
        .eq('entity_id', videoId)
        .eq('owner_id', user.id);
    if (authorIdentityId != null && authorIdentityId.isNotEmpty) {
      mediaUpdate.eq('owner_identity_id', authorIdentityId);
    }
    await mediaUpdate;
  }

  /// 3. 商城瀑布流获取：拉取高并发商品数据
  static Future<List<Map<String, dynamic>>> fetchProducts({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final data = await client
          .from('products')
          .select()
          .order('sales_count', ascending: false) // 按销量排序，制造爆款氛围
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// 4. IM 消息发送：插入一条新消息
  static Future<void> sendMessage({
    required String content,
    required String senderId,
  }) async {
    try {
      await client.from('messages').insert({
        'content': content,
        'sender_id': senderId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// 5. IM 历史消息获取
  static Future<List<Map<String, dynamic>>> fetchHistoryMessages({
    int limit = 50,
  }) async {
    try {
      final data = await client
          .from('messages')
          .select()
          .order('created_at', ascending: true) // 历史消息按时间正序
          .limit(limit);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// 6. IM 实时监听：WebSocket 订阅新消息
  static SupabaseStreamBuilder listenToMessages() {
    // 监听 messages 表的所有 INSERT 事件
    return client
        .from('messages')
        .stream(primaryKey: ['id']).order('created_at', ascending: true);
  }

  static Future<void> consumeUploadSessions(Iterable<String?> sessionIds) async {
    final ids = sessionIds
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return;
    }

    await client
        .from('media_upload_sessions')
        .update({
          'status': 'consumed',
          'last_error_code': null,
          'last_error_message': null,
        })
        .inFilter('id', ids);
  }

  static String _generateUploadToken() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = List.generate(
      4,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'upl_${timestamp}_$randomPart';
  }

  static String? _sanitizeUploadToken(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  static String computeSha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  static Future<UploadedMedia?> _findReusableMediaAsset({
    required String ownerId,
    required String mediaKind,
    required String checksumSha256,
  }) async {
    final candidateKinds = _candidateAssetKindsForUploadKind(mediaKind);
    if (candidateKinds.isEmpty) {
      return null;
    }

    final data = await client
        .from('media_assets')
        .select(
          'owner_id, object_key, public_url, media_kind, mime_type, bytes, '
          'checksum_sha256, source_filename',
        )
        .eq('owner_id', ownerId)
        .eq('media_kind', candidateKinds.first)
        .eq('checksum_sha256', checksumSha256)
        .eq('status', 'ready')
        .order('created_at', ascending: false)
        .limit(1);
    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final objectKey = row['object_key'] as String? ?? '';
    return UploadedMedia(
      ownerId: row['owner_id'] as String? ?? ownerId,
      objectKey: objectKey,
      objectPrefix: _extractObjectPrefixFromKey(objectKey),
      uploadSessionId: null,
      publicUrl: row['public_url'] as String? ?? '',
      mediaKind: row['media_kind'] as String? ?? mediaKind,
      contentType:
          row['mime_type'] as String? ?? 'application/octet-stream',
      bytes: row['bytes'] as int? ?? 0,
      checksumSha256: row['checksum_sha256'] as String? ?? checksumSha256,
      sourceFilename: row['source_filename'] as String? ?? '',
    );
  }

  static Future<UploadedMedia?> _findReusableUploadedSessionMedia({
    required String ownerId,
    required String mediaKind,
    required String checksumSha256,
  }) async {
    final data = await client
        .from('media_upload_sessions')
        .select(
          'id, owner_id, media_kind, content_type, file_size_bytes, checksum_sha256, '
          'source_filename, output_payload',
        )
        .eq('owner_id', ownerId)
        .eq('media_kind', mediaKind)
        .eq('checksum_sha256', checksumSha256)
        .eq('status', 'uploaded')
        .order('created_at', ascending: false)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final outputPayload = Map<String, dynamic>.from(
      row['output_payload'] as Map? ?? const <String, dynamic>{},
    );
    final objectKey = outputPayload['objectKey'] as String? ?? '';
    final publicUrl = outputPayload['publicUrl'] as String? ?? '';
    if (objectKey.isEmpty || publicUrl.isEmpty) {
      return null;
    }

    return UploadedMedia(
      ownerId: row['owner_id'] as String? ?? ownerId,
      objectKey: objectKey,
      objectPrefix: outputPayload['objectPrefix'] as String? ??
          _extractObjectPrefixFromKey(objectKey),
      uploadSessionId: row['id'] as String?,
      publicUrl: publicUrl,
      mediaKind: row['media_kind'] as String? ?? mediaKind,
      contentType:
          row['content_type'] as String? ?? 'application/octet-stream',
      bytes: row['file_size_bytes'] as int? ?? 0,
      checksumSha256: row['checksum_sha256'] as String? ?? checksumSha256,
      sourceFilename: row['source_filename'] as String? ?? '',
    );
  }

  static Future<UploadSessionPlan?> _findUploadSessionByIdempotency({
    required String ownerId,
    required String idempotencyKey,
  }) async {
    final sanitizedKey = _sanitizeUploadToken(idempotencyKey);
    if (sanitizedKey == null) {
      return null;
    }

    final data = await client
        .from('media_upload_sessions')
        .select()
        .eq('owner_id', ownerId)
        .eq('idempotency_key', sanitizedKey)
        .order('created_at', ascending: false)
        .limit(1);

    final rows = List<Map<String, dynamic>>.from(data);
    if (rows.isEmpty) {
      return null;
    }
    return UploadSessionPlan.fromJson(rows.first);
  }

  static Future<UploadSessionPlan> _reopenUploadSession({
    required String sessionId,
    required String sourceFilename,
    required String contentType,
    required int fileSizeBytes,
    required int nextRetryCount,
    String? checksumSha256,
    int? expectedWidth,
    int? expectedHeight,
    Map<String, dynamic>? uploadMetadata,
  }) async {
    final updated = await client
        .from('media_upload_sessions')
        .update({
          'status': 'issued',
          'source_filename': sourceFilename,
          'content_type': contentType,
          'file_size_bytes': fileSizeBytes,
          'checksum_sha256': checksumSha256,
          'expected_width': expectedWidth,
          'expected_height': expectedHeight,
          'bytes_uploaded': 0,
          'completed_at': null,
          'last_error_code': null,
          'last_error_message': null,
          'retry_count': nextRetryCount,
          'upload_metadata': uploadMetadata ?? const <String, dynamic>{},
          'output_payload': const <String, dynamic>{},
          'expires_at': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
        })
        .eq('id', sessionId)
        .select()
        .single();

    return UploadSessionPlan.fromJson(Map<String, dynamic>.from(updated));
  }

  static List<String> _candidateAssetKindsForUploadKind(String mediaKind) {
    switch (mediaKind) {
      case 'stream':
        return const ['stream_manifest'];
      case 'video':
        return const ['video'];
      case 'cover':
        return const ['cover'];
      case 'avatar':
        return const [];
      default:
        return [mediaKind];
    }
  }

  static String? _extractObjectPrefixFromKey(String objectKey) {
    final segments = objectKey.split('/');
    if (segments.length <= 4) {
      return null;
    }
    return segments.sublist(3, segments.length - 1).join('/');
  }
}
