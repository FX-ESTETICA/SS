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
    return Scaffold(
      backgroundColor: Colors.transparent, // 必须透明以露出全局流光
      body: AnimatedSpatialBackground(
        child: _buildBody(), // 完全由 _buildBody 的 CustomScrollView 接管滚动
      ),
    );
  }

  // （已删除悬浮功能区，整合到全新的横向 Header 中）
  
  // （已删除 _buildFloatingHeader() 和 _buildFloatingHeaderContent() 方法）

  // （已删除未使用的 _buildMainCategoryItem 方法）

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

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          // 核心优化：物理级预渲染边界。
          // 提前在屏幕外 2500 像素的位置就开始在 Isolate (独立线程) 中解码图片并构建 RenderObject。
          // 这样用户滑到的时候，图片已经变成了 GPU 里的纹理 (Texture)，实现绝对的 0 毫秒掉帧。
          // ignore: deprecated_member_use
          cacheExtent: 2500, 
          slivers: [
            // 沉浸式头部区域：广告传送带完全置顶
            SliverToBoxAdapter(
              child: _HeroBannerContent(
                categoryIndex: _selectedMainCategoryIndex,
                itemWidth: itemWidth,
                itemHeight: itemHeight,
                spacing: spacing,
                borderRadius: borderRadius,
                isVisible: _isBannerVisible && widget.isTabActive,
              ),
            ),
            
            // 全新的大分类切换器与动态搜索框
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: _MainCategorySelectorAndSearch(
                  selectedIndex: _selectedMainCategoryIndex,
                  onTap: () {
                    setState(() {
                      _selectedMainCategoryIndex = (_selectedMainCategoryIndex + 1) % 3;
                    });
                  },
                ),
              ),
            ),

            // 横向浏览的子分类内容区
            if (_isLoading)
              _buildSkeletonSliver(crossAxisCount)
            else if (_errorMessage != null)
              SliverToBoxAdapter(child: Center(child: Text(_errorMessage!, style: AppTypography.body)))
            else
              _buildHorizontalRowsSliver(),
          ],
        );
      },
    );
  }

  /// 动态分发全新的横向列表内容
  Widget _buildHorizontalRowsSliver() {
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
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // 移除多余的 bottom 参数
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12.0), // 用 SizedBox 替代 bottom padding
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 【终极方案】：放弃手动计算时间差，直接使用 Flutter 底层极其成熟的 AnimationController
    // 它可以完美对齐 VSync，并由引擎在底层进行最平滑的插值计算，拒绝任何手工计算导致的微小撕裂
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // 初始给个默认值，build 中会根据真实宽度动态计算
    );
    if (widget.isVisible) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ContinuousMarqueeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isVisible && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

    // 动态计算 duration：比如设定移动速度为 50 像素/秒
    // 这样不管屏幕多宽、图片多少，移动速度永远恒定
    final int durationMs = (totalWidth / 50.0 * 1000).toInt();
    _controller.duration = Duration(milliseconds: durationMs);

    return SizedBox(
      height: widget.itemHeight,
      width: double.infinity, // 强制撑满全宽
      child: ClipRect( // 裁剪掉溢出的部分
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // _controller.value 在 0.0 到 1.0 之间随 VSync 匀速变化
            final double scrollOffset = _controller.value * totalWidth;

            return Stack(
              clipBehavior: Clip.none, // 允许子元素溢出 Stack
              children: List.generate(n, (i) {
                final double basePos = i * totalItemWidth;
                // 核心循环算法：让卡片在 -totalItemWidth 到 (totalWidth - totalItemWidth) 之间循环移动
                // 修复断层：确保卡片是从屏幕最右侧进入，向最左侧移出
                final double x = ((basePos - scrollOffset) % totalWidth);
                
                // 如果计算出的位置太靠右（超过了总宽度减去一个元素的宽度），把它挪到最左边去，实现无缝衔接
                final double adjustedX = x > totalWidth - totalItemWidth ? x - totalWidth : x;

                // 恢复纯粹的浮点数 Transform.translate，让 GPU 处理亚像素抗锯齿 (Sub-pixel AA)
                // 彻底去掉 roundToDouble()，因为它就是导致你感觉“晃动得更厉害”（阶梯跳跃感）的罪魁祸首！
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
    
    // 因为没有了悬浮导航栏，这里我们大大缩小 top padding
    // 仅保留一个极小的安全区避让，让广告图最大程度贴顶
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(top: topPadding), // 极小顶距，实现视觉冲顶
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
            width: 100, // 3个头像叠加的宽度
            height: 56,
            child: Stack(
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


