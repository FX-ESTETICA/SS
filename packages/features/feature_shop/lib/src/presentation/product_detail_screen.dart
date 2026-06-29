import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shop_feed_screen.dart'; // 引入 ProductModel

/// 商品详情页
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;
  final bool isMerchantMode;
  final String? sourceHeroTag;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.isMerchantMode = true, // 临时默认为 true，方便预览编辑模式
    this.sourceHeroTag,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;

  late List<String> _mediaUrls;
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _mediaUrls = List.from(widget.product.mediaUrls);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 根据滑动距离计算 AppBar 的透明度
    double offset = _scrollController.offset;
    double opacity = (offset / 200).clamp(0.0, 1.0);
    if (opacity != _appBarOpacity) {
      setState(() {
        _appBarOpacity = opacity;
      });
    }
  }

  void _showSkuBottomSheet() {
    context.showInstantSheet<void>(
      backgroundColor: Colors.transparent, // 必须透明以显示沉浸式背景
      isScrollControlled: true,
      builder: (context) => const _SkuBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 透出全局背景
      body: AnimatedSpatialBackground(
        child: Stack(
          children: [
            _buildBody(),
            _buildCustomAppBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // 1. 沉浸式顶部大图 (画廊轮播模式)
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            height: 280.0, // 统一压缩高度为 280px，释放首屏空间
            decoration: const BoxDecoration(
              color: Colors.black, // 占位背景
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 画廊轮播
                PageView.builder(
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentMediaIndex = index);
                  },
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // 底部黑色渐变，方便看清下方的文字
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. 商品核心信息区
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 价格与销量
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '¥',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.product.price.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '已售 ${widget.product.salesCount}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标题
                Text(
                  widget.product.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. 规格选择入口
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: _showSkuBottomSheet,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), // 极微弱的背景区分层级
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Text(
                    '选择',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '请选择规格、颜色',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 4. 店铺信息
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.storefront, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.shopName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '官方认证店铺',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '进店逛逛',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 占位，防止底部导航栏遮挡内容
        const SliverToBoxAdapter(
          child: SizedBox(height: 120),
        ),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: _appBarOpacity), // 根据滚动渐变黑色背景
        ),
        child: Row(
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3), // 确保在图片上能看清返回按钮
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Opacity(
                opacity: _appBarOpacity, // 滚动后显示标题
                child: const Center(
                  child: Text(
                    '商品详情',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.isMerchantMode)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('进入商家商品编辑模式')),
                  );
                },
              ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 20),
              ),
              onPressed: () {},
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
          Hero(
            tag: index == 0
                ? (widget.sourceHeroTag ??
                    'product_image_${widget.product.id ?? widget.product.imageUrl}')
                : 'media_$index',
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 1080,
            ),
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
                    fontWeight: FontWeight.w500,
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
          const SnackBar(content: Text('调用系统相册/相机上传商品主图或视频')),
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
              '上传商品主图/视频\n提升购买转化率',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaActionBottomSheet(int index) {
    context.showInstantSheet<void>(
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
                  '设为商品展示首图',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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
                  '删除此主图/视频',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
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
                      const SnackBar(content: Text('商品至少需要保留一张首图')),
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

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
          top: 12,
          left: 16,
          right: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9), // 强背景，确保按钮清晰
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            // 客服、店铺、收藏图标
            _buildBottomIcon(Icons.headset_mic_outlined, '客服'),
            const SizedBox(width: 16),
            _buildBottomIcon(Icons.storefront_outlined, '店铺'),
            const SizedBox(width: 16),
            _buildBottomIcon(Icons.star_border, '收藏'),
            const Spacer(),
            // 购买按钮
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white, // 强制纯白
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(24)),
                  ),
                  child: const Text(
                    '加入购物车',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ), // 纯黑字
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black, // 纯黑底
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ), // 粗白边框，极具视觉冲击力
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                  ),
                  child: const Text(
                    '立即购买',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ), // 纯白字
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}

/// 底部 SKU 选择弹窗
class _SkuBottomSheet extends StatelessWidget {
  const _SkuBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8), // 半透明黑，让流光背景透出
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.2)), // 极客感发光边框
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部小横条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 内容区
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择规格',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '颜色',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSkuChip('极客黑', isSelected: true),
                      _buildSkuChip('星际银', isSelected: false),
                      _buildSkuChip('冰川白', isSelected: false),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    '容量/尺寸',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSkuChip('标准版', isSelected: false),
                      _buildSkuChip('Pro 版', isSelected: true),
                      _buildSkuChip('Max 顶配版', isSelected: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // 底部确认按钮
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 16,
              left: 24,
              right: 24,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white, // 纯白强按钮
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Text(
                '确定',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkuChip(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        border: Border.all(color: Colors.white, width: isSelected ? 0 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
    );
  }
}
