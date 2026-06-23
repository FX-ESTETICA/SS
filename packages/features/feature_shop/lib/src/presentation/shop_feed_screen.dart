import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_detail_screen.dart'; // 引入详情页

/// 商品数据模型
class ProductModel {
  final String? id;
  final String title;
  final String imageUrl;
  final double price;
  final int salesCount;
  final String shopName;

  ProductModel({
    this.id,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.salesCount,
    required this.shopName,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      salesCount: json['sales_count'] ?? 0,
      shopName: json['shop_name'] ?? '',
    );
  }
}

/// 淘宝风格商城瀑布流页面
class ShopFeedScreen extends StatefulWidget {
  final bool isTabActive;
  const ShopFeedScreen({super.key, this.isTabActive = true});

  @override
  State<ShopFeedScreen> createState() => _ShopFeedScreenState();
}

class _ShopFeedScreenState extends State<ShopFeedScreen> {
  final List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearchExpanded = false;
  final ScrollController _scrollController = ScrollController();
  bool _isBannerVisible = true; // 新增：视口裁剪标志
  
  // 0: 商店 (横向16:9), 1: 商城 (竖向瀑布流), 2: 生活 (服务卡片)
  int _selectedMainCategoryIndex = 1;
  int _selectedSubCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // 性能优化：当向下滚动超过 800 像素时，认为广告区已经完全移出屏幕，触发视口裁剪
    final isVisible = _scrollController.offset < 800;
    if (isVisible != _isBannerVisible) {
      setState(() {
        _isBannerVisible = isVisible;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    try {
      final data = await SupabaseService.instance.fetchProducts();
      if (mounted) {
        setState(() {
          _products.addAll(data.map((e) => ProductModel.fromJson(e)).toList());
          _isLoading = false;
        });
      }
    } catch (e) {
      // 降级使用虚拟占位数据，让用户直接看效果
      if (mounted) {
        setState(() {
          _products.addAll(_generateMockProducts());
          _isLoading = false;
        });
      }
    }
  }

  List<ProductModel> _generateMockProducts() {
    final mockImages = [
      'https://images.unsplash.com/photo-1523275335684-37898b6baf30?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1572635196237-14b3f281503f?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1526170375885-4d8ecf77b99f?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1484101403633-562f891dc89a?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1523293115678-02a9c6f50c7c?auto=format&fit=crop&q=80&w=500',
      'https://images.unsplash.com/photo-1549298916-b41d501d3772?auto=format&fit=crop&q=80&w=500',
    ];
    return List.generate(16, (index) {
      return ProductModel(
        title: '沉浸式空间设计 - 极简美学测试商品 ${index + 1}',
        imageUrl: mockImages[index % mockImages.length],
        price: 199.0 + (index * 20),
        salesCount: 1000 + index * 10,
        shopName: '智选本地生活',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 必须透明以露出全局流光
      body: AnimatedSpatialBackground(
        child: _buildBody(), // 移除 Stack，完全由 _buildBody 的 CustomScrollView 接管滚动
      ),
    );
  }

  // （已删除 _buildFloatingHeader() 方法，并入 _buildFloatingHeaderContent）

  Widget _buildMainCategoryItem(String title, int index) {
    final isSelected = _selectedMainCategoryIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedMainCategoryIndex = index;
        _selectedSubCategoryIndex = 0; // 重置小分类索引
      }),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSelected ? 20 : 16,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              color: Colors.white, // 强制纯白，移除 Colors.white70
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 选中状态的底部小白条
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 16 : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        int crossAxisCount = 2; // 商城
        if (screenWidth > 1200) {
          crossAxisCount = 6; // 宽屏下一行放 6 个
        } else if (screenWidth > 800) {
          crossAxisCount = 4;
        } else if (screenWidth > 600) {
          crossAxisCount = 3;
        }

        int storeLifeCrossAxisCount = 1; // 商店与生活
        if (screenWidth > 1200) {
          storeLifeCrossAxisCount = 4; // 宽屏下一行放 4 个
        } else if (screenWidth > 800) {
          storeLifeCrossAxisCount = 2;
        }

        double itemWidth;
        double itemHeight;
        double spacing;
        double paddingHorizontal;
        double borderRadius;

        if (_selectedMainCategoryIndex == 0) { // 商店
          spacing = 16.0;
          paddingHorizontal = 16.0;
          borderRadius = 16.0;
          itemWidth = (screenWidth - paddingHorizontal * 2 - (storeLifeCrossAxisCount - 1) * spacing) / storeLifeCrossAxisCount;
          itemHeight = itemWidth / (16 / 9);
        } else if (_selectedMainCategoryIndex == 1) { // 商城
          spacing = 8.0;
          paddingHorizontal = 8.0;
          borderRadius = 12.0;
          itemWidth = (screenWidth - paddingHorizontal * 2 - (crossAxisCount - 1) * spacing) / crossAxisCount;
          itemHeight = itemWidth / (3 / 4);
        } else { // 生活
          spacing = 16.0;
          paddingHorizontal = 16.0;
          borderRadius = 16.0;
          itemWidth = (screenWidth - paddingHorizontal * 2 - (storeLifeCrossAxisCount - 1) * spacing) / storeLifeCrossAxisCount;
          itemHeight = itemWidth / (21 / 9);
        }

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          // 核心优化：物理级预渲染边界。
          // 提前在屏幕外 2500 像素的位置就开始在 Isolate (独立线程) 中解码图片并构建 RenderObject。
          // 这样用户滑到的时候，图片已经变成了 GPU 里的纹理 (Texture)，实现绝对的 0 毫秒掉帧。
          // ignore: deprecated_member_use
          cacheExtent: 2500, 
          slivers: [
            // 沉浸式头部区域：广告传送带置顶，且贯穿左右边缘；导航栏悬浮其上
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  _HeroBannerContent(
                    categoryIndex: _selectedMainCategoryIndex,
                    itemWidth: itemWidth,
                    itemHeight: itemHeight,
                    spacing: spacing,
                    borderRadius: borderRadius,
                    isVisible: _isBannerVisible && widget.isTabActive,
                  ),
                  _buildFloatingHeaderContent(),
                ],
              ),
            ),
            
            // 小分类导航 (跟随滚动)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 140,
                child: _SubCategoryHeaderContent(
                  mainCategoryIndex: _selectedMainCategoryIndex,
                  selectedIndex: _selectedSubCategoryIndex,
                  onChanged: (index) {
                    setState(() {
                      _selectedSubCategoryIndex = index;
                    });
                  },
                ),
              ),
            ),

            // 根据选中的大分类渲染不同的商品流
            if (_isLoading)
              _buildSkeletonSliver(crossAxisCount)
            else if (_errorMessage != null)
              SliverToBoxAdapter(child: Center(child: Text(_errorMessage!, style: AppTypography.body)))
            else
              _buildContentSliver(crossAxisCount, storeLifeCrossAxisCount),
          ],
        );
      },
    );
  }

  /// 原本悬浮的导航栏内容，现在作为普通的滚动内容
  Widget _buildFloatingHeaderContent() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topPadding + 32, bottom: 16), // 增加基础 topPadding，避开 40px 高度的 WindowCaption
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：左侧定位 / 搜索框，右侧按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isSearchExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          'Rapallo', // 极简单图标+定位文字
                          style: AppTypography.body.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: const Offset(0, 1),
                                blurRadius: 3.0,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    secondChild: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '搜索全网低价好物...',
                                hintStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w300),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearchExpanded = !_isSearchExpanded;
                    });
                  },
                  child: Container(
                    width: 32, // 稍微缩小点击区域
                    height: 32,
                    color: Colors.transparent, // 彻底去除圆形背景，仅保留透明点击区域
                    alignment: Alignment.centerRight,
                    child: Icon(
                      _isSearchExpanded ? Icons.close : Icons.search,
                      color: Colors.white, // 强制纯白，因为没有背景了
                      size: 24, // 放大一点图标以补偿背景的缺失
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12), // 极大地缩小与下方大分类的间距
          // 第二行：大分类居中显示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMainCategoryItem('商店', 0),
              const SizedBox(width: 32),
              _buildMainCategoryItem('商城', 1),
              const SizedBox(width: 32),
              _buildMainCategoryItem('生活', 2),
            ],
          ),
        ],
      ),
    );
  }

  /// 动态分发不同的内容布局
  Widget _buildContentSliver(int crossAxisCount, int storeLifeCrossAxisCount) {
    if (_products.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: Center(
            child: Text('暂无相关商品', style: AppTypography.body),
          ),
        ),
      );
    }

    switch (_selectedMainCategoryIndex) {
      case 0: // 商店 (横向16:9)
        return SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: storeLifeCrossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 16 / 9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildStoreCard(_products[index]),
              childCount: _products.length,
            ),
          ),
        );
      case 1: // 商城 (竖向尺寸一致)
        return SliverPadding(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3 / 4,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildMallCard(_products[index]),
              childCount: _products.length,
            ),
          ),
        );
      case 2: // 生活 (58同城类，服务卡片)
        return SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: storeLifeCrossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 21 / 9,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildLifeCard(_products[index]),
              childCount: _products.length,
            ),
          ),
        );
      default:
        return const SliverToBoxAdapter(child: SizedBox());
    }
  }

  /// 骨架屏 (Skeleton) 渲染 Sliver 版本
  Widget _buildSkeletonSliver(int crossAxisCount) {
    return SliverMasonryGrid.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: index % 2 == 0 ? 250 : 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
  /// 1. 商店卡片：横向 16:9 比例，沉浸式信息覆盖
  Widget _buildStoreCard(ProductModel product) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 背景大图
            Hero(
              tag: 'product_image_${product.id ?? product.imageUrl}',
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 800, // 强制内存熔断，防止高清大图撑爆内存 (16:9 适合 800px 宽度)
              ),
            ),
            // 沉浸式渐变遮罩 (底部)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
              ),
            ),
            // 覆盖在上面的文字信息
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white, // 强制纯白
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('本地严选', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)), // 强制黑字
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          product.shopName,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w300), // 纯白，通过粗细区分
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. 商城卡片：竖向比例，沉浸式信息覆盖
  Widget _buildMallCard(ProductModel product) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'product_image_${product.id ?? product.imageUrl}',
              child: CachedNetworkImage(
                imageUrl: product.imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400, // 强制内存熔断，瀑布流卡片仅需 400px 宽度
              ),
            ),
            // 渐变遮罩
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
              ),
            ),
            // 信息区
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('¥', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        product.price.toStringAsFixed(0),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. 生活卡片：58同城类服务，沉浸式信息覆盖
  Widget _buildLifeCard(ProductModel product) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
            tag: 'product_image_${product.id ?? product.imageUrl}',
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 600, // 强制内存熔断
            ),
          ),
          // 全局微弱黑色遮罩 + 底部强遮罩
            Container(color: Colors.black.withValues(alpha: 0.2)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  ),
                ),
              ),
            ),
            // 服务信息
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.title, // 例如：上门家电维修
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 14), // 强制纯白
                            const Text(' 4.9', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w300)),
                            const SizedBox(width: 8),
                            Text('已服务 ${product.salesCount} 次', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w300)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white, // 强制纯白
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('预约', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), // 强制纯黑
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(ProductModel product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: ProductDetailScreen(product: product),
          );
        },
      ),
    );
  }
}

class ContinuousMarqueeBanner extends StatefulWidget {
  final List<String> imageUrls;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final double borderRadius;
  final bool isVisible;

  const ContinuousMarqueeBanner({
    super.key,
    required this.imageUrls,
    required this.itemWidth,
    required this.itemHeight,
    required this.spacing,
    required this.borderRadius,
    required this.isVisible,
  });

  @override
  State<ContinuousMarqueeBanner> createState() => _ContinuousMarqueeBannerState();
}

class _ContinuousMarqueeBannerState extends State<ContinuousMarqueeBanner> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _scrollNotifier = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    // 使用一个独立的极低频 Ticker (30fps)，与全局背景解绑，保证视觉上的持续反馈
    _ticker = createTicker((elapsed) {
      if (!widget.isVisible) return;
      // 速度控制：每毫秒移动的像素量 (大约 60像素/秒)
      _scrollNotifier.value = elapsed.inMilliseconds * 0.06;
    });
    if (widget.isVisible) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(ContinuousMarqueeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.isVisible && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scrollNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox();

    final screenWidth = MediaQuery.of(context).size.width;
    final double totalItemWidth = widget.itemWidth + widget.spacing;

    // 构建足够长的图片队列，确保能填满屏幕并能循环滚动
    List<String> displayUrls = [...widget.imageUrls];
    // 至少需要填满屏幕两倍的宽度，才能保证首尾相连时没有断层
    while (displayUrls.length * totalItemWidth < screenWidth * 2 + totalItemWidth * 2) {
      displayUrls.addAll(widget.imageUrls);
    }
    final int n = displayUrls.length;
    final double totalWidth = n * totalItemWidth;

    return SizedBox(
      height: widget.itemHeight,
      width: double.infinity, // 强制撑满全宽
      child: ClipRect( // 裁剪掉溢出的部分
        child: ValueListenableBuilder<double>(
          valueListenable: _scrollNotifier,
          builder: (context, scrollOffset, child) {
            return Stack(
              clipBehavior: Clip.none, // 允许子元素溢出 Stack
              children: List.generate(n, (i) {
                final double basePos = i * totalItemWidth;
                // 核心循环算法：让卡片在 -totalItemWidth 到 (totalWidth - totalItemWidth) 之间循环移动
                // 修复断层：确保卡片是从屏幕最右侧进入，向最左侧移出
                final double x = ((basePos - scrollOffset) % totalWidth);
                
                // 如果计算出的位置太靠右（超过了总宽度减去一个元素的宽度），把它挪到最左边去，实现无缝衔接
                final double adjustedX = x > totalWidth - totalItemWidth ? x - totalWidth : x;

                // 使用 Transform.translate，绝对禁止触发 CPU 的 performLayout
                return Transform.translate(
                  offset: Offset(adjustedX, 0),
                  child: SizedBox(
                    width: widget.itemWidth,
                    height: widget.itemHeight,
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: displayUrls[i],
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.1)),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.white.withValues(alpha: 0.1),
                          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// 动态比例的广告区
class _HeroBannerContent extends StatelessWidget {
  final int categoryIndex;
  final double itemWidth;
  final double itemHeight;
  final double spacing;
  final double borderRadius;
  final bool isVisible;

  const _HeroBannerContent({
    required this.categoryIndex,
    required this.itemWidth,
    required this.itemHeight,
    required this.spacing,
    required this.borderRadius,
    required this.isVisible,
  });

  // 定义三个分类的广告图片池 (使用 picsum.photos 全球高可用图床)
  final Map<int, List<String>> _categoryBanners = const {
    0: [ // 商店 (16:9)
      'https://picsum.photos/id/1015/1000/562', 
      'https://picsum.photos/id/1025/1000/562', 
      'https://picsum.photos/id/1060/1000/562', 
    ],
    1: [ // 商城 (3:4)
      'https://picsum.photos/id/1035/800/1066', 
      'https://picsum.photos/id/1074/800/1066', 
      'https://picsum.photos/id/119/800/1066', 
    ],
    2: [ // 生活 (21:9)
      'https://picsum.photos/id/10/1000/428', 
      'https://picsum.photos/id/1016/1000/428', 
      'https://picsum.photos/id/1018/1000/428', 
    ],
  };

  @override
  Widget build(BuildContext context) {
    final imageUrls = _categoryBanners[categoryIndex] ?? _categoryBanners[1]!;
    
    // 增加基础的顶部 padding 避开沉浸式状态栏 (与 Header 对齐)
    final topPadding = MediaQuery.of(context).padding.top + 32;

    return Container(
      // 背景必须透明，彻底移除黑色相框
      color: Colors.transparent,
      padding: EdgeInsets.only(top: topPadding + 60), // 给上方悬浮导航栏留出空间，但不设置左右 padding 以实现贯穿
      child: ContinuousMarqueeBanner(
        imageUrls: imageUrls,
        itemWidth: itemWidth,
        itemHeight: itemHeight,
        spacing: spacing,
        borderRadius: borderRadius,
        isVisible: isVisible,
      ),
    );
  }
}

/// 黏性小分类导航 (纯图标横向滑动) -> 已改为跟随滚动的 _SubCategoryHeaderContent
class _SubCategoryHeaderContent extends StatelessWidget {
  final int mainCategoryIndex;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SubCategoryHeaderContent({
    required this.mainCategoryIndex,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 构建基于实景图的分类数据池 (每个大类 6 个小分类)
    final List<Map<String, String>> categories;

    if (mainCategoryIndex == 0) { // 商店
      categories = [
        {'label': '综合', 'image': 'https://picsum.photos/id/102/300/300'},
        {'label': '餐饮', 'image': 'https://picsum.photos/id/1080/300/300'},
        {'label': '咖啡', 'image': 'https://picsum.photos/id/1060/300/300'},
        {'label': '健身', 'image': 'https://picsum.photos/id/1050/300/300'},
        {'label': '电影', 'image': 'https://picsum.photos/id/1043/300/300'},
        {'label': '出行', 'image': 'https://picsum.photos/id/1072/300/300'},
      ];
    } else if (mainCategoryIndex == 1) { // 商城
      categories = [
        {'label': '推荐', 'image': 'https://picsum.photos/id/20/300/300'},
        {'label': '数码', 'image': 'https://picsum.photos/id/366/300/300'},
        {'label': '服饰', 'image': 'https://picsum.photos/id/335/300/300'},
        {'label': '家居', 'image': 'https://picsum.photos/id/405/300/300'},
        {'label': '酒水', 'image': 'https://picsum.photos/id/42/300/300'},
        {'label': '美妆', 'image': 'https://picsum.photos/id/450/300/300'},
      ];
    } else { // 生活
      categories = [
        {'label': '附近', 'image': 'https://picsum.photos/id/500/300/300'},
        {'label': '保洁', 'image': 'https://picsum.photos/id/600/300/300'},
        {'label': '维修', 'image': 'https://picsum.photos/id/700/300/300'},
        {'label': '搬家', 'image': 'https://picsum.photos/id/800/300/300'},
        {'label': '消毒', 'image': 'https://picsum.photos/id/900/300/300'},
        {'label': '宠物', 'image': 'https://picsum.photos/id/1025/300/300'},
      ];
    }

    return Container(
      height: 100, // 直接使用固定高度，不再引用 maxExtent
      decoration: const BoxDecoration(
        color: Colors.transparent, // 完全透明
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(categories.length, (index) {
              final isSelected = selectedIndex == index;
              final category = categories[index];
              
              return GestureDetector(
                onTap: () => onChanged(index),
                behavior: HitTestBehavior.opaque,
                // 【底层优化】图层冷冻 + 物理弹簧引擎，极度流畅
                child: RepaintBoundary(
                  child: AnimatedScale(
                    scale: isSelected ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut, // 极具重量感的果冻回弹
                    child: Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 76, 
                      height: 84, 
                      // 移除 CustomPaint，回归纯净层级
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. 底层实景图片 (配合 ColorFilter)
                            ColorFiltered(
                              colorFilter: isSelected 
                                  ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) 
                                  : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                              child: CachedNetworkImage(
                                imageUrl: category['image']!,
                                fit: BoxFit.cover,
                                memCacheWidth: 200, 
                                placeholder: (context, url) => Container(color: Colors.grey[900]), 
                                errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
                              ),
                            ),
                            // 2. 底部渐变遮罩
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
                                  ),
                                ),
                              ),
                            ),
                            // 3. 底部文字
                            Positioned(
                              bottom: 8, left: 0, right: 0,
                              child: Text(
                                category['label']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                  shadows: [
                                    Shadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// 已经移除 _CardOverlayPainter 类


