import 'package:supabase_flutter/supabase_flutter.dart';

/// 全局 Supabase 云端服务中枢
/// 负责管理与全球节点的连接、身份验证 (Auth)、数据库查询 (PostgreSQL) 和存储 (R2/S3)
class SupabaseService {
  SupabaseService._(); // 私有化构造函数，实现单例模式

  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

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

  // ---------------------------------------------------------------------------
  // 以下是为您预留的各种“降维打击”云端能力接口
  // ---------------------------------------------------------------------------

  /// 1. 极致登录：获取当前用户的会话状态
  Session? get currentSession => client.auth.currentSession;

  /// 2. 视频流获取：从云端数据库中查询视频列表
  Future<List<Map<String, dynamic>>> fetchVideos({int limit = 10, int offset = 0}) async {
    try {
      final data = await client
          .from('videos')
          .select()
          .order('created_at', ascending: false) // 按最新时间排序
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// 3. 商城瀑布流获取：拉取高并发商品数据
  Future<List<Map<String, dynamic>>> fetchProducts({int limit = 10, int offset = 0}) async {
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
  Future<void> sendMessage({required String content, required String senderId}) async {
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
  Future<List<Map<String, dynamic>>> fetchHistoryMessages({int limit = 50}) async {
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
  SupabaseStreamBuilder listenToMessages() {
    // 监听 messages 表的所有 INSERT 事件
    return client.from('messages').stream(primaryKey: ['id']).order('created_at', ascending: true);
  }
}
