import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'memory_bridge_navigation_stub.dart'
    if (dart.library.html) 'memory_bridge_navigation_web.dart';

class MemoryBridgeEntryScreen extends StatefulWidget {
  const MemoryBridgeEntryScreen({super.key});

  @override
  State<MemoryBridgeEntryScreen> createState() => _MemoryBridgeEntryScreenState();
}

class _MemoryBridgeEntryScreenState extends State<MemoryBridgeEntryScreen> {
  late final String _targetUrl;
  bool _redirectTriggered = false;

  @override
  void initState() {
    super.initState();
    _targetUrl = buildMemoryBridgeUrl();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _redirectTriggered) return;
        _redirectTriggered = openMemoryBridgeInSameTab(_targetUrl);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const isWebRedirecting = kIsWeb;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('项目记忆桥接'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memory Bridge 已正式接入 App 路由。',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWebRedirecting
                        ? '当前为 Web 环境，页面会自动切换到浏览器侧的跨窗口记忆桥接台。'
                        : '当前为桌面端环境。桥接页属于浏览器侧能力，已接入统一路由入口；如需调试浏览器多窗口能力，请在 Web 环境打开下方地址。',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _InfoRow(label: '桥接页地址', value: _targetUrl),
                  const SizedBox(height: 12),
                  const _InfoRow(
                    label: '触发口令',
                    value: '读取记忆',
                  ),
                  const SizedBox(height: 12),
                  const _InfoRow(
                    label: '通信机制',
                    value: 'BroadcastChannel -> localStorage fallback',
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    _targetUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}
