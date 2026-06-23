import 'dart:async';
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
  final bool isTabActive;
  const ShopFeedScreen({super.key, this.isTabActive = true});

  @override
  State<ShopFeedScreen> createState() => _ShopFeedScreenState();
}

class _ShopFeedScreenState extends State<ShopFeedScreen> {
  final List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  bool _isBannerVisible = true; // 新增：视口裁剪标志
  
  // 0: 商店 (横向16:9), 1: 商城 (竖向瀑布流), 2: 生活 (服务卡片)
  int _selectedMainCategoryIndex = 1;

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
    // 终极极简架构：不需要任何复杂的 Stack 或 AnimatedBuilder 手动计算 offset
    // 直接将全息广告和搜索栏放入底层的 CustomScrollView 中，随页面自然滚动
    return Material(
      color: Colors.transparent, // 必须透明以露出全局流光
      child: AnimatedSpatialBackground(
        child: _buildBody(),
      ),
    );
  }

  // （已删除悬浮功能区，整合到全新的横向 Header 中）
  
  // （已删除 _buildFloatingHeader() 和 _buildFloatingHeaderContent() 方法）

  // （已删除未使用的 _buildMainCategoryItem 方法）

  Widget _buildBody() {
    // 强制移除所有 MediaQuery 注入的 padding（包括顶部的状态栏/标题栏安全区）
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: LayoutBuilder(
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

          double itemWidth;
          double itemHeight;
          double spacing;
          double paddingHorizontal;
          double borderRadius;

          if (_selectedMainCategoryIndex == 0) { // 商店
            spacing = 16.0;
            paddingHorizontal = 16.0;
            borderRadius = 16.0;
            itemWidth = (screenWidth - paddingHorizontal * 2 - (crossAxisCount - 1) * spacing) / crossAxisCount;
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
            itemWidth = (screenWidth - paddingHorizontal * 2 - (crossAxisCount - 1) * spacing) / crossAxisCount;
            itemHeight = itemWidth / (21 / 9);
          }

          // 使用 ScrollConfiguration 隐藏右侧的原生滚动条
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              // 核心优化：物理级预渲染边界。
              // ignore: deprecated_member_use
              cacheExtent: 2500, 
              slivers: [
              // 头部：全息巨幕广告 + 悬浮搜索栏
              // 将它们打包成一个 Sliver，直接放在列表最顶部！
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: Stack(
                    children: [
                      // 第一层：广告图铺满
                      Positioned.fill(
                        child: _HeroBannerContent(
                          categoryIndex: _selectedMainCategoryIndex,
                          isVisible: _isBannerVisible && widget.isTabActive,
                        ),
                      ),
                      // 第二层：搜索栏钉在广告图底部
                      Positioned(
                        left: 16.0,
                        right: 16.0,
                        bottom: 24.0, // 距离广告图底部的 padding
                        child: _MainCategorySelectorAndSearch(
                          selectedIndex: _selectedMainCategoryIndex,
                          onTap: () {
                            setState(() {
                              _selectedMainCategoryIndex = (_selectedMainCategoryIndex + 1) % 3;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 为了让商品列表不被广告图盖住，必须加上这层真正的商品列表！
              // 这个列表就是您截图中看到消失的东西。
              if (_isLoading)
                _buildSkeletonSliver(crossAxisCount)
              else if (_errorMessage != null)
                SliverToBoxAdapter(
                  child: Center(child: Text(_errorMessage!, style: AppTypography.body)),
                )
              else
                _buildHorizontalRowsSliver(),

              // 安全底部留白 (适配沉浸式导航栏)
              // 彻底删掉了那个 500px 的超级黑洞，防止出现“只剩背景”的错觉
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              )
            ],
          ),
          );
        },
      ),
    );
  }

  /// 动态分发全新的横向列表内容 (Sliver 版本)
  Widget _buildHorizontalRowsSliver() {
    if (_products.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 100, bottom: 500),
          child: Center(
            child: Text('暂无相关商品', style: AppTypography.body),
          ),
        ),
      );
    }

    // 获取当前大分类下的子分类名称
    List<String> subCategories;
    if (_selectedMainCategoryIndex == 0) {
      subCategories = ['综合商店', '网红餐饮', '精品咖啡', '深夜酒吧'];
    } else if (_selectedMainCategoryIndex == 1) {
      subCategories = ['为你推荐', '数码极客', '潮流服饰', '品质家居'];
    } else {
      subCategories = ['附近服务', '上门保洁', '家电维修', '同城搬家'];
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final categoryName = subCategories[index];
          // 为每个子分类打乱并取部分商品模拟数据，展示出差异感
          final items = [..._products]..shuffle();
          final rowItems = items.take(6).toList();

          return _buildHorizontalRow(categoryName, rowItems);
        },
        childCount: subCategories.length,
      ),
    );
  }

  Widget _buildHorizontalRow(String title, List<ProductModel> items) {
    // 动态卡片宽度与高度
    final double cardWidth = _selectedMainCategoryIndex == 1 ? 160 : 280;
    final double listHeight = _selectedMainCategoryIndex == 1 ? 220 : 160;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12.0),
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            // 关键修改：只保留左侧的 padding，去掉右侧的 padding
            // 这样最右侧的卡片就能紧贴屏幕边缘
            padding: const EdgeInsets.only(left: 16.0),
            // 使用 clipBehavior 确保滚动时不会被裁切掉阴影等
            clipBehavior: Clip.none,
            itemCount: items.length + 1, // +1 for the "全部" button
            itemBuilder: (context, index) {
              if (index == items.length) {
                // 最右侧的“全部”按钮
                return _buildSeeAllButton(listHeight);
              }
              final product = items[index];
              return Container(
                width: cardWidth,
                margin: const EdgeInsets.only(right: 12.0),
                child: _selectedMainCategoryIndex == 0 
                    ? _buildStoreCard(product) 
                    : (_selectedMainCategoryIndex == 1 ? _buildMallCard(product) : _buildLifeCard(product)),
              );
            },
          ),
        ),
        const SizedBox(height: 32), // 行间距
      ],
    );
  }

  Widget _buildSeeAllButton(double height) {
    return Container(
      width: 80, // 稍微宽一点，让按钮更饱满
      height: height, // 确保高度匹配
      margin: const EdgeInsets.only(right: 16.0), // 留出最右侧呼吸空间
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05), // 极微弱背景
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)), // 极细边框
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.arrow_forward_ios, color: Colors.black, size: 16),
          ),
          const SizedBox(height: 12),
          const Text('全部', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSkeletonSliver(int crossAxisCount) {
    return SliverToBoxAdapter(
      child: Container(
        height: 1000,
        padding: const EdgeInsets.all(16.0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[900]!, // 改成暗黑模式的骨架屏颜色
          highlightColor: Colors.grey[800]!,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(6, (index) {
              return Container(
                width: 160,
                height: index % 2 == 0 ? 250 : 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            }),
          ),
        ),
      ),
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

class HolographicHoverShowcase extends StatefulWidget {
  final List<String> imageUrls;
  final bool isVisible;

  const HolographicHoverShowcase({
    super.key,
    required this.imageUrls,
    required this.isVisible,
  });

  @override
  State<HolographicHoverShowcase> createState() => _HolographicHoverShowcaseState();
}

class _HolographicHoverShowcaseState extends State<HolographicHoverShowcase> {
  Timer? _timer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // 初始页设为一个很大的数，保证一开始就能向前和向后滑动（实现无限循环的视觉效果）
    _pageController = PageController(initialPage: widget.imageUrls.length * 100);
    _startTimer();
  }

  void _startTimer() {
    if (!widget.isVisible) return;
    // 横向 5 秒轮播
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800), // 切换动画时长
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void didUpdateWidget(HolographicHoverShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _startTimer();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox();

    final height = MediaQuery.of(context).size.height * 0.5;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: PageView.builder(
        controller: _pageController,
        // 允许用户手动滑动，BouncingScrollPhysics 提供更好的回弹体验
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          // 通过取模运算实现无限循环
          final realIndex = index % widget.imageUrls.length;
          return CachedNetworkImage(
            imageUrl: widget.imageUrls[realIndex],
            fit: BoxFit.cover,
            alignment: Alignment.topCenter, // 保证图片顶端对齐，不留黑边
            width: double.infinity,
            height: height,
            memCacheWidth: 1200, // 高清大图支持
            placeholder: (context, url) => Container(color: Colors.transparent),
            errorWidget: (context, url, error) => Container(color: Colors.transparent),
          );
        },
      ),
    );
  }
}

/// 动态比例的广告区 (全息橱窗)
class _HeroBannerContent extends StatelessWidget {
  final int categoryIndex;
  final bool isVisible;

  const _HeroBannerContent({
    required this.categoryIndex,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    // 动态生成 10 个高清广告图
    final List<String> imageUrls = List.generate(
      10, 
      (i) => 'https://picsum.photos/id/${(categoryIndex + 1) * 100 + i + 10}/1200/800'
    );

    // 彻底干掉 SafeArea 或者 MediaQuery 的 padding
    // 让图片真正从屏幕的最物理顶端开始绘制，无视任何控制栏
    return Container(
      color: Colors.transparent,
      child: HolographicHoverShowcase(
        imageUrls: imageUrls,
        isVisible: isVisible,
      ),
    );
  }
}

/// 黏性小分类导航 (纯图标横向滑动) -> 已改为跟随滚动的 _SubCategoryHeaderContent
class _MainCategorySelectorAndSearch extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onTap;

  const _MainCategorySelectorAndSearch({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 三个大类的代表图片 (头像)
    final List<String> avatars = [
      'https://picsum.photos/id/102/100/100', // 商店
      'https://picsum.photos/id/20/100/100',  // 商城
      'https://picsum.photos/id/500/100/100', // 生活
    ];

    final String hintText = selectedIndex == 0 
        ? '你想逛哪家商店？' 
        : (selectedIndex == 1 ? '你想购买什么？' : '需要什么服务？');

    return Row(
      children: [
        // 左侧：叠加的圆形头像 (点击切换)
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            // 增加容器宽度，确保最右侧的头像不会被 Clip 掉
            // 3个头像：第一个在 left:0，第二个在 left:24，第三个在 left:48
            // 最后一个头像的右边缘在 48 + 56 = 104 的位置，加上阴影的额外空间，给到 120 比较安全
            width: 120, 
            height: 56,
            child: Stack(
              clipBehavior: Clip.none, // 极其重要：允许 Stack 内部的子元素（如阴影）溢出，不被强制裁剪
              children: [
                // 底层 2 (最不重要)
                _buildAvatar(avatars[(selectedIndex + 2) % 3], 48, false, 0),
                // 底层 1
                _buildAvatar(avatars[(selectedIndex + 1) % 3], 24, false, 1),
                // 顶层 (当前选中)
                _buildAvatar(avatars[selectedIndex], 0, true, 2),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 右侧：动态搜索框
        Expanded(
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hintText,
                    style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 右侧加个麦克风图标增加细节
                const Icon(Icons.mic_none, color: Colors.white70, size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(String imageUrl, double leftPos, bool isSelected, int zIndex) {
    return Positioned(
      left: leftPos,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
            )
          ] : null,
        ),
        child: ClipOval(
          child: ColorFiltered(
            colorFilter: isSelected 
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply) 
                : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: 120,
              placeholder: (context, url) => Container(color: Colors.grey[900]),
              errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
            ),
          ),
        ),
      ),
    );
  }
}

// 已经移除 _CardOverlayPainter 类


