import 'package:flutter/material.dart';
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
  const ShopFeedScreen({super.key});

  @override
  State<ShopFeedScreen> createState() => _ShopFeedScreenState();
}

class _ShopFeedScreenState extends State<ShopFeedScreen> {
  final List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearchExpanded = false;
  final ScrollController _scrollController = ScrollController();
  
  // 0: 商店 (横向16:9), 1: 商城 (竖向瀑布流), 2: 生活 (服务卡片)
  int _selectedMainCategoryIndex = 1;
  int _selectedSubCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
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
        child: Stack(
          children: [
            _buildBody(),
            _buildFloatingHeader(),
          ],
        ),
      ),
    );
  }

  /// 悬浮式透明导航栏 (定位 + 展开式搜索 + 居中大分类)
  Widget _buildFloatingHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 16, bottom: 16),
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
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: '搜索全网低价好物...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
      ),
    );
  }

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
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(), // 增加弹性物理效果
      slivers: [
        // 1/3 广告区 (带视差效果)
        SliverPersistentHeader(
          pinned: false,
          delegate: _HeroBannerDelegate(
            minHeight: 0,
            maxHeight: MediaQuery.of(context).size.height / 3,
          ),
        ),
        
        // 黏性小分类导航 (居中显示，所有大分类都显示)
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickySubCategoryHeaderDelegate(
            mainCategoryIndex: _selectedMainCategoryIndex,
            selectedIndex: _selectedSubCategoryIndex,
            onChanged: (index) {
              setState(() {
                _selectedSubCategoryIndex = index;
              });
            },
          ),
        ),

        // 根据选中的大分类渲染不同的商品流
        if (_isLoading)
          _buildSkeletonSliver()
        else if (_errorMessage != null)
          SliverToBoxAdapter(child: Center(child: Text(_errorMessage!, style: AppTypography.body)))
        else
          _buildContentSliver(),
      ],
    );
  }

  /// 动态分发不同的内容布局
  Widget _buildContentSliver() {
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

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.crossAxisExtent > 1200) {
          crossAxisCount = 5;
        } else if (constraints.crossAxisExtent > 800) {
          crossAxisCount = 4;
        } else if (constraints.crossAxisExtent > 600) {
          crossAxisCount = 3;
        }

        switch (_selectedMainCategoryIndex) {
          case 0: // 商店 (横向16:9)
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildStoreCard(_products[index]),
                childCount: _products.length,
              ),
            );
          case 1: // 商城 (竖向3:4/9:16)
            return SliverPadding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childCount: _products.length,
                itemBuilder: (context, index) {
                  return _buildMallCard(_products[index]);
                },
              ),
            );
          case 2: // 生活 (58同城类，服务卡片)
            return SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildLifeCard(_products[index]),
                  childCount: _products.length,
                ),
              ),
            );
          default:
            return const SliverToBoxAdapter(child: SizedBox());
        }
      },
    );
  }

  /// 骨架屏 (Skeleton) 渲染 Sliver 版本
  Widget _buildSkeletonSliver() {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.crossAxisExtent > 1200) {
          crossAxisCount = 5;
        } else if (constraints.crossAxisExtent > 800) {
          crossAxisCount = 4;
        } else if (constraints.crossAxisExtent > 600) {
          crossAxisCount = 3;
        }

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
      },
    );
  }
  /// 1. 商店卡片：横向 16:9 比例，沉浸式信息覆盖
  Widget _buildStoreCard(ProductModel product) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: AspectRatio(
        aspectRatio: 16 / 9, // 完美横向比例
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
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13), // 纯白透明度
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
      ),
    );
  }

  /// 2. 商城卡片：竖向比例，沉浸式信息覆盖
  Widget _buildMallCard(ProductModel product) {
    // 模拟 3:4 和 9:16 的错落感
    final isTall = product.imageUrl.hashCode % 2 == 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: AspectRatio(
        aspectRatio: isTall ? 9 / 16 : 3 / 4,
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
      ),
    );
  }

  /// 3. 生活卡片：58同城类服务，沉浸式信息覆盖
  Widget _buildLifeCard(ProductModel product) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _navigateToDetail(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: AspectRatio(
        aspectRatio: 21 / 9, // 更扁长的服务卡片
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
                            Text(' 4.9', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('已服务 ${product.salesCount} 次', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
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

/// 1/3 广告区 (带视差效果)
class _HeroBannerDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;

  _HeroBannerDelegate({
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 视差滚动计算：内容以更慢的速度向上移动
    final parallaxOffset = shrinkOffset * 0.5;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -parallaxOffset,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: Colors.black, // 占位背景
            child: CachedNetworkImage(
              // 这里用一张高质感的图片代替视频作为示例，实际可替换为 video_player
              imageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&q=80&w=1920',
              fit: BoxFit.cover,
              memCacheWidth: 1080, // 广告位保留较高清晰度
            ),
          ),
        ),
        // 底部融合渐变遮罩 (改为纯黑)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 60,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black, // 强制纯黑
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_HeroBannerDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight;
  }
}

/// 黏性小分类导航 (纯图标横向滑动)
class _StickySubCategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int mainCategoryIndex;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  _StickySubCategoryHeaderDelegate({
    required this.mainCategoryIndex,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // final double alpha = (shrinkOffset / maxExtent).clamp(0.0, 1.0); // 暂不使用
    
    // 定义选中(实心)和未选中(线框)两套图标
    final List<IconData> outlinedIcons;
    final List<IconData> filledIcons;

    if (mainCategoryIndex == 0) {
      outlinedIcons = [Icons.storefront_outlined, Icons.restaurant_outlined, Icons.local_cafe_outlined, Icons.fitness_center_outlined, Icons.movie_outlined, Icons.directions_car_outlined];
      filledIcons = [Icons.storefront, Icons.restaurant, Icons.local_cafe, Icons.fitness_center, Icons.movie, Icons.directions_car];
    } else if (mainCategoryIndex == 1) {
      outlinedIcons = [Icons.star_border, Icons.smartphone_outlined, Icons.checkroom_outlined, Icons.chair_outlined, Icons.liquor_outlined, Icons.face_retouching_natural_outlined];
      filledIcons = [Icons.star, Icons.smartphone, Icons.checkroom, Icons.chair, Icons.liquor, Icons.face_retouching_natural];
    } else {
      outlinedIcons = [Icons.near_me_outlined, Icons.cleaning_services_outlined, Icons.home_repair_service_outlined, Icons.local_shipping_outlined, Icons.sanitizer_outlined, Icons.pets_outlined];
      filledIcons = [Icons.near_me, Icons.cleaning_services, Icons.home_repair_service, Icons.local_shipping, Icons.sanitizer, Icons.pets];
    }

    return Container(
      height: maxExtent,
      decoration: const BoxDecoration(
        color: Colors.transparent, // 完全透明，不要任何背景色，让流光完全透出来
      ),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(outlinedIcons.length, (index) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () => onChanged(index),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.only(right: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? filledIcons[index] : outlinedIcons[index],
                        size: 24, // 略微缩小
                        weight: 100, // 极细线框 (需 Flutter Material Symbols 支持)
                        color: Colors.white, // 强制纯白，绝不使用任何透明度
                      ),
                      const SizedBox(height: 6),
                      // 底部横线指示器
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: isSelected ? 16 : 0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickySubCategoryHeaderDelegate oldDelegate) {
    return mainCategoryIndex != oldDelegate.mainCategoryIndex || selectedIndex != oldDelegate.selectedIndex;
  }
}


