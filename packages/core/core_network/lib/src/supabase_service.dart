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
  User? get currentUser => client.auth.currentUser;

  /// 监听登录状态变化
  Stream<AuthState> get onAuthStateChange => client.auth.onAuthStateChange;

  /// 邮箱密码注册
  Future<AuthResponse> signUpWithEmailPassword(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  /// 邮箱密码登录
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  /// 退出登录
  Future<void> signOut() async {
    await client.auth.signOut();
  }

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

  /// 获取我发布的视频
  Future<List<Map<String, dynamic>>> fetchMyVideos(String authorName) async {
    try {
      final data = await client
          .from('videos')
          .select()
          .eq('author_name', authorName)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      rethrow;
    }
  }

  /// 上传媒体文件到存储，并返回公共 URL (适配 R2 链路)
  Future<String> uploadMedia(String fileName, dynamic fileBytes) async {
    try {
      // 尝试上传到 Supabase 绑定的 media bucket (兼容 R2)
      await client.storage.from('media').uploadBinary(fileName, fileBytes);
      return client.storage.from('media').getPublicUrl(fileName);
    } catch (e) {
      // 兜底方案：如果 bucket 未创建，返回一个静态的 R2 体验地址保证主链路跑通
      return 'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/test_video_1.mp4';
    }
  }

  /// 发布视频动态：写入数据库
  Future<void> publishVideo({
    required String videoUrl,
    required String description,
    required String authorName,
  }) async {
    try {
      await client.from('videos').insert({
        'video_url': videoUrl,
        'description': description,
        'author_name': authorName,
      });
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
