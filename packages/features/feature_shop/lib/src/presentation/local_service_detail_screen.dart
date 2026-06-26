import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shop_feed_screen.dart'; // 获取 ProductModel

/// 专为本地生活、线下门店打造的极致视觉详情页
class LocalServiceDetailScreen extends StatefulWidget {
  final ProductModel product;
  final bool isStore; // true 为商店，false 为服务
  final bool isMerchantMode; // 是否为商家编辑模式

  const LocalServiceDetailScreen({
    super.key,
    required this.product,
    this.isStore = true,
    this.isMerchantMode = true, // 临时默认为 true，方便预览编辑模式
  });

  @override
  State<LocalServiceDetailScreen> createState() =>
      _LocalServiceDetailScreenState();
}

class _LocalServiceDetailScreenState extends State<LocalServiceDetailScreen> {
  late List<String> _mediaUrls;
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _mediaUrls = List.from(widget.product.mediaUrls);
  }

  @override
  Widget build(BuildContext context) {
    // 使用透明 Scaffold，露出底层的沉浸式宇宙流光背景
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSpatialBackground(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildMediaCarouselHeader(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildTitleAndPrice(),
                        const SizedBox(height: 32),
                        _buildMerchantInfo(),
                        const SizedBox(height: 32),
                        _buildActionRow(),
                        const SizedBox(height: 32),
                        _buildServiceDetails(),
                        const SizedBox(height: 120), // 底部留白，防止被预约按钮遮挡
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomNavigationBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaCarouselHeader(BuildContext context) {
    // 压缩头部高度，释放首屏空间 (从 400 降至 280)
    return SliverAppBar(
      expandedHeight: 280.0,
      pinned: true,
      backgroundColor: Colors.black, // 滑动上去后变成纯黑，防止穿帮
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isMerchantMode)
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('进入商家信息编辑模式')),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 画廊轮播
            PageView.builder(
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentMediaIndex = index);
              },
              // 如果是商家模式，多渲染一页作为上传入口
              itemCount: widget.isMerchantMode
                  ? _mediaUrls.length + 1
                  : _mediaUrls.length,
              itemBuilder: (context, index) {
                if (index == _mediaUrls.length) {
                  return _buildUploadPlaceholder();
                }
                return _buildMediaItem(_mediaUrls[index], index);
              },
            ),

            // 画廊指示器
            Positioned(
              right: 16,
              bottom: 24,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentMediaIndex + 1} / ${widget.isMerchantMode ? _mediaUrls.length + 1 : _mediaUrls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // 底部自然过渡遮罩
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem(String url, int index) {
    return GestureDetector(
      onTap: () {
        if (widget.isMerchantMode) {
          _showMediaActionBottomSheet(index);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth: 800,
          ),
          // 商家模式下，第一张强制显示“首图”标签
          if (widget.isMerchantMode && index == 0)
            Positioned(
              left: 16,
              top: 100, // 避开 AppBar
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '当前展示首图',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('调用系统相册/相机上传图片或视频')),
        );
      },
      child: Container(
        color: Colors.grey[900], // 深灰色底
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              '上传门店环境图/视频\n展示最好的一面',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaActionBottomSheet(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.star, color: Colors.white),
                title: const Text(
                  '设为展示首图',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    final item = _mediaUrls.removeAt(index);
                    _mediaUrls.insert(0, item);
                    _currentMediaIndex = 0; // 切回第一张
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text(
                  '删除此媒体',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (_mediaUrls.length > 1) {
                    setState(() {
                      _mediaUrls.removeAt(index);
                      if (_currentMediaIndex >= _mediaUrls.length) {
                        _currentMediaIndex = _mediaUrls.length - 1;
                      }
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('至少保留一张首图')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitleAndPrice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  '¥',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.product.price.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Text(
              '已服务 ${widget.product.salesCount} 次',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          widget.product.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildTag(widget.isStore ? '官方认证' : '金牌服务'),
            const SizedBox(width: 8),
            _buildTag('随时退'),
            const SizedBox(width: 8),
            _buildTag('免预约', isSolid: false),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String text, {bool isSolid = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSolid ? Colors.white : Colors.transparent,
        border: isSolid ? null : Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSolid ? Colors.black : Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMerchantInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1), // 纯白极简线框
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(Icons.storefront, color: Colors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.shopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 14),
                        Icon(Icons.star, color: Colors.white, size: 14),
                        Icon(Icons.star, color: Colors.white, size: 14),
                        Icon(Icons.star, color: Colors.white, size: 14),
                        Icon(Icons.star_half, color: Colors.white, size: 14),
                        SizedBox(width: 8),
                        Text(
                          '4.9分',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white, height: 1),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.location_on, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '距离 1.2km | 北京市朝阳区三里屯太古里南区 1层',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.phone, color: Colors.white, size: 24),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionItem(Icons.directions, '路线导航'),
        _buildActionItem(Icons.chat_bubble_outline, '在线咨询'),
        _buildActionItem(Icons.store, '进店逛逛'),
        _buildActionItem(Icons.photo_library_outlined, '商家相册'),
      ],
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceDetails() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '服务与预订须知',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Text(
          '1. 凭此预约凭证到店即可享受专属服务。\n\n2. 请提前至少 2 小时进行线上预约，以免到店排队。\n\n3. 本服务包含全程 1 对 1 专属向导。\n\n4. 如需取消预约，请在服务开始前 24 小时内操作，随时退款，不收手续费。',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.6,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    // 悬浮在底部的全透明控制栏，按钮保持纯实色
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.headset_mic, color: Colors.white),
                  SizedBox(height: 4),
                  Text(
                    '客服',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white, // 纯白实色，强烈对比
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      widget.isStore ? '立即预约' : '购买服务',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ), // 纯黑字体
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
