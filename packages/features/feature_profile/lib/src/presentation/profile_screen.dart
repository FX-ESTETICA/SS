import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const ProfileScreen({super.key, this.onLoginSuccess});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showOtpInput = false;
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // 用于避免静态分析器检测到死代码的辅助方法
  bool _checkIsLoggedIn() => false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 深色背景基底
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景层：图片 + 毛玻璃虚化效果
          _buildBackground(),

          // 2. 内容层
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  // 顶部：头像、日期、问候语
                  _buildHeaderInfo(),
                  
                  const Spacer(), // 占据中间空间，把输入框推到下面
                  
                  // 底部：输入框或第三方登录区域的动态切换
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _showOtpInput ? _buildOtpSection() : _buildEmailAndThirdPartySection(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop', // 暗色抽象背景图
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.6),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
          child: Container(
            color: Colors.black.withValues(alpha: 0.2), 
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    final now = DateTime.now();
    final weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final dateStr = '${weekdays[now.weekday - 1]}, ${now.month}月${now.day}日';
    final bool isLoggedIn = _checkIsLoggedIn(); 

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black, // 未登录状态的纯黑背景
            image: isLoggedIn ? const DecorationImage(
              image: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80'), 
              fit: BoxFit.cover,
            ) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: !isLoggedIn 
            ? const Center(
                child: Text(
                  'SS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              )
            : null,
        ),
        const SizedBox(height: 24),
        // 日期
        Text(
          dateStr,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // 问候语
        Text(
          isLoggedIn ? '晚上好，Sarah！' : '欢迎，请登录',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// 邮箱输入框 + 第三方登录入口（第一步显示）
  Widget _buildEmailAndThirdPartySection() {
    return Column(
      key: const ValueKey('EmailSection'),
      children: [
        // 邮箱输入框
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.only(left: 20, right: 6),
          child: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '输入邮箱地址获取验证码',
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              // 发送箭头按钮
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 20),
                  onPressed: () {
                    if (_emailController.text.isNotEmpty) {
                      setState(() {
                        _showOtpInput = true; // 切换到验证码视图
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // 分割线
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('或使用以下方式', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          ],
        ),
        const SizedBox(height: 24),
        
        // 第三方登录按钮（小型化处理，只显示图标和简短名字）
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSmallButton(Icons.language, '谷歌'),
            _buildSmallButton(Icons.apple, '苹果'),
            _buildSmallButton(Icons.chat_bubble_outline, 'WhatsApp'),
            _buildSmallButton(Icons.wechat, '微信'),
          ],
        ),
      ],
    );
  }

  /// 验证码输入框（点击获取验证码后显示，替代前面的区域）
  Widget _buildOtpSection() {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    return Column(
      key: const ValueKey('OtpSection'),
      children: [
        Text(
          '验证码已发送至\n${_emailController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        // 6 位数验证码输入框
        Pinput(
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
              border: Border.all(color: Colors.blueAccent),
            ),
          ),
          onCompleted: (pin) {
            // 验证码输入完成，触发登录成功回调，进入视频页
            if (widget.onLoginSuccess != null) {
              widget.onLoginSuccess!();
            }
          },
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () {
            setState(() {
              _showOtpInput = false; // 返回修改邮箱
            });
          },
          child: const Text('修改邮箱地址', style: TextStyle(color: Colors.white54)),
        )
      ],
    );
  }

  /// 小型化第三方按钮
  Widget _buildSmallButton(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Icon(icon, color: Colors.white70, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}