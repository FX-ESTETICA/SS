import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';

/// 消息数据模型
class MessageModel {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;
  final bool isMe;

  MessageModel({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
    required this.isMe,
  });

  factory MessageModel.fromJson(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    return MessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      senderId: json['sender_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      isMe: json['sender_id'] == currentUserId,
    );
  }
}

/// 仿微信/WhatsApp 聊天界面
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _messageSubscription;

  String get _currentUserId => SupabaseService.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetchHistoryMessages();
    _subscribeToNewMessages();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel(); // 取消 WebSocket 订阅，防止内存泄漏
    super.dispose();
  }

  /// 1. 从云端拉取历史消息
  Future<void> _fetchHistoryMessages() async {
    if (_currentUserId.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = '请先登录后再使用聊天功能';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await SupabaseService.fetchHistoryMessages();

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            data.map((e) => MessageModel.fromJson(e, _currentUserId)).toList(),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '无法连接到聊天服务器';
          _isLoading = false;
        });
      }
    }
  }

  /// 2. 订阅 WebSocket (Realtime) 频道，实现秒发秒回
  void _subscribeToNewMessages() {
    if (_currentUserId.isEmpty) return;
    _messageSubscription = SupabaseService.listenToMessages().listen(
      (data) {
        if (mounted) {
          setState(() {
            _errorMessage = null;
            _messages.clear();
            _messages.addAll(
              data
                  .map((e) => MessageModel.fromJson(e, _currentUserId))
                  .toList(),
            );
          });
          _scrollToBottom();
        }
      },
      onError: (_, __) async {
        await _messageSubscription?.cancel();
        _messageSubscription = null;
        await _fetchHistoryMessages();
        if (!mounted) return;
        setState(() {
          _errorMessage = '实时消息通道暂不可用，已切换为历史消息模式';
        });
      },
    );
  }

  /// 3. 发送消息
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再发送消息')),
      );
      return;
    }

    // 先清空输入框，提供极速响应的 UI 体验
    _textController.clear();

    // 我们不需要手动 add 到 _messages 列表里！
    // 因为只要我们写入数据库，上面的 _subscribeToNewMessages 就会瞬间通过 WebSocket 把新消息推回给我们！
    try {
      await SupabaseService.sendMessage(
        content: text,
        senderId: _currentUserId,
      );
    } catch (e) {
      // 发送失败处理
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消息发送失败')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 必须透明以露出全局流光
      extendBodyBehindAppBar: true, // 允许流光背景渗透到导航栏下方
      appBar: AppBar(
        backgroundColor: Colors.transparent, // 导航栏透明
        elevation: 0,
        // 增加顶部边距，避开 40px 高度的 WindowCaption，实现全页面的同步下移
        toolbarHeight: kToolbarHeight + 32,
        title: const Padding(
          padding: EdgeInsets.only(top: 32.0),
          child: Text(
            '架构师 (在线)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 32.0),
            child: IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: AnimatedSpatialBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: AppColors.error),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(MessageModel msg) {
    final isMe = msg.isMe;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24), // 增加气泡之间的呼吸感
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white, // 对方头像底色纯白
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.black,
                size: 20,
              ), // 黑图标
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                // 极致黑白：我的消息纯白，对方消息纯黑框
                color: isMe ? Colors.white : Colors.black,
                border: isMe
                    ? null
                    : Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ), // 对方消息加极其微弱的白边框界定边界
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: isMe
                    ? [
                        BoxShadow(
                          color:
                              Colors.white.withValues(alpha: 0.1), // 白色气泡微微发光
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                msg.content,
                style: TextStyle(
                  fontSize: 16,
                  color: isMe ? Colors.black : Colors.white, // 极简反差
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1), // 我的头像线框
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 20,
              ), // 白图标
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent, // 必须透明以露出底部流光，不能是纯黑
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ), // 极细白线分割
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.mic_none, size: 28, color: Colors.white), // 纯白图标
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.transparent, // 输入框透明
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ), // 线框输入框
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(color: Colors.white), // 输入文字纯白
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    border: InputBorder.none,
                    hintText: '发送消息...',
                    hintStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w300,
                    ), // 占位符暗白
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white, // 发送按钮纯白实心
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  size: 18,
                  color: Colors.black,
                ), // 黑图标
              ),
            ),
          ],
        ),
      ),
    );
  }
}
