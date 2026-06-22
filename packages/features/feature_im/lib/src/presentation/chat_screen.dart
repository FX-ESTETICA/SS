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

  factory MessageModel.fromJson(Map<String, dynamic> json, String currentUserId) {
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
  
  // 模拟当前用户的 ID（在真实的 Supabase Auth 中，这是登录用户的 UUID）
  final String _currentUserId = 'user_123';

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
    try {
      final data = await SupabaseService.instance.fetchHistoryMessages();
      
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((e) => MessageModel.fromJson(e, _currentUserId)).toList());
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
    _messageSubscription = SupabaseService.instance.listenToMessages().listen((data) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(data.map((e) => MessageModel.fromJson(e, _currentUserId)).toList());
        });
        _scrollToBottom();
      }
    });
  }

  /// 3. 发送消息
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 先清空输入框，提供极速响应的 UI 体验
    _textController.clear();
    
    // 我们不需要手动 add 到 _messages 列表里！
    // 因为只要我们写入数据库，上面的 _subscribeToNewMessages 就会瞬间通过 WebSocket 把新消息推回给我们！
    try {
      await SupabaseService.instance.sendMessage(
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        title: const Text('架构师 (在线)', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)));
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // 降维打击：微信绿 vs 苹果蓝
                color: isMe ? const Color(0xFF95EC69) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.content,
                style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
          ),
          
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            const Icon(Icons.mic_none, size: 28, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120), // 限制最大高度，防止布局异常
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null, // 允许换行
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                    hintText: '发送消息...',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.emoji_emotions_outlined, size: 28, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.send, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}