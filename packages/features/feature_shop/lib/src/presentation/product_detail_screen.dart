import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'shop_feed_screen.dart'; // 引入 ProductModel

/// 商品详情页
class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    showModalBottomSheet(
      context: context,
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
        // 1. 沉浸式顶部大图 (带 Hero 动画)
        SliverToBoxAdapter(
          child: Hero(
            tag: 'product_image_${widget.product.id ?? widget.product.imageUrl}', // 使用唯一 ID 作为 tag，如果 id 不存在则用 imageUrl 兜底
            child: Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.width, // 正方形大图
              decoration: const BoxDecoration(
                color: Colors.black, // 占位背景
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.product.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1080, // 详情页需要高清原图，放宽内存限制
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
                    const Text('¥', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      widget.product.price.toStringAsFixed(2),
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      '已售 ${widget.product.salesCount}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标题
                Text(
                  widget.product.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
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
                  const Text('选择', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 16),
                  Text('请选择规格、颜色', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5), size: 20),
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
                      Text(widget.product.shopName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('官方认证店铺', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('进店逛逛', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Opacity(
                opacity: _appBarOpacity, // 滚动后显示标题
                child: const Center(
                  child: Text('商品详情', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
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

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom, top: 12, left: 16, right: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9), // 强背景，确保按钮清晰
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white, // 强制纯白
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
                  ),
                  child: const Text('加入购物车', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), // 纯黑字
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black, // 纯黑底
                    border: Border.all(color: Colors.white, width: 2), // 粗白边框，极具视觉冲击力
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                  ),
                  child: const Text('立即购买', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), // 纯白字
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)), // 极客感发光边框
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
                  const Text('选择规格', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('颜色', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
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
                  const Text('容量/尺寸', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16, left: 24, right: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white, // 纯白强按钮
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Text('确定', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
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
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
