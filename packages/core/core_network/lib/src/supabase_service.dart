import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final String publicUrl;
  final String mediaKind;
  final String contentType;
  final int bytes;
  final String checksumSha256;
  final String sourceFilename;

  const UploadedMedia({
    required this.ownerId,
    required this.objectKey,
    required this.publicUrl,
    required this.mediaKind,
    required this.contentType,
    required this.bytes,
    required this.checksumSha256,
    required this.sourceFilename,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    return UploadedMedia(
      ownerId: json['ownerId'] as String? ?? '',
      objectKey: json['objectKey'] as String? ?? '',
      publicUrl: json['publicUrl'] as String? ?? '',
      mediaKind: json['mediaKind'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      bytes: json['bytes'] as int? ?? 0,
      checksumSha256: json['checksumSha256'] as String? ?? '',
      sourceFilename: json['sourceFilename'] as String? ?? '',
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
  static Future<List<Map<String, dynamic>>> fetchVideos({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final data = await client
          .from('videos')
          .select()
          .eq('processing_status', 'ready')
          .eq('lifecycle_status', 'active')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // 【顶级架构约束】：绝对不提供本地假数据兜底。如果断网或报错，直接把错误抛给 UI 层处理。
      rethrow;
    }
  }

  /// 获取我发布的视频
  static Future<List<Map<String, dynamic>>> fetchMyVideos(
    String authorId, {
    String? authorIdentityId,
  }) async {
    try {
      final query = client
          .from('videos')
          .select()
          .eq('author_id', authorId)
          .neq('lifecycle_status', 'deleted');

      final data = authorIdentityId == null
          ? await query.order('created_at', ascending: false)
          : await query
              .eq('author_identity_id', authorIdentityId)
              .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
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

  /// 顶级架构：直通 R2 边缘节点上传链路
  /// 通过 Worker 统一接管认证、对象命名与元数据返回
  static Future<UploadedMedia> uploadMedia({
    required String fileName,
    required List<int> fileBytes,
    required String mediaKind,
    required String accessToken,
    String contentType = 'application/octet-stream',
  }) async {
    try {
      final workerUrl = 'https://zhixuan-media-upload.499755740.workers.dev'
          '?filename=$fileName&kind=$mediaKind';

      final response = await Dio().put(
        workerUrl,
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
    required String description,
    required String authorId,
    required String authorIdentityId,
    required String authorName,
    required double durationSeconds,
    int? width,
    int? height,
  }) async {
    final finalDescription = description.trim();

    final dbVideoData = {
      'author_id': authorId,
      'author_identity_id': authorIdentityId,
      'video_url': videoUpload.publicUrl,
      'video_object_key': videoUpload.objectKey,
      'cover_url': coverUpload?.publicUrl ?? '',
      'cover_object_key': coverUpload?.objectKey,
      'description': finalDescription,
      'author_name': authorName,
      'created_at': DateTime.now().toIso8601String(),
      'view_count': 0,
      'like_count': 0,
      'comment_count': 0,
      'share_count': 0,
      'duration_seconds': durationSeconds,
      'width': width,
      'height': height,
      'processing_status': 'ready',
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
        'retention_class': 'standard',
        'last_verified_at': DateTime.now().toIso8601String(),
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
        'retention_class': 'standard',
        'last_verified_at': DateTime.now().toIso8601String(),
      });
    }

    await client.from('media_assets').insert(mediaRecords);
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
}
