import 'dart:async';
import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'product_detail_screen.dart'; // 引入详情页
import 'local_service_detail_screen.dart'; // 引入本地生活/商店详情页

/// 商品数据模型
class ProductModel {
  final String? id;
  final String title;
  final String imageUrl; // 依然保留作为封面图 (Cover)
  final List<String> mediaUrls; // 新增：多媒体画廊数组 (图片/视频)
  final double price;
  final int salesCount;
  final String shopName;
  final String category; // 0: 商店, 1: 商城, 2: 生活
  final String subCategory; // 具体小分类，如 '数码极客'

  ProductModel({
    this.id,
    required this.title,
    required this.imageUrl,
    List<String>? mediaUrls,
    required this.price,
    required this.salesCount,
    required this.shopName,
    this.category = '1',
    this.subCategory = '为你推荐',
  }) : mediaUrls = mediaUrls ?? [imageUrl]; // 默认将封面图放入画廊第一张

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final coverUrl = json['image_url'] ?? '';

    // 解析媒体数组，如果后端没传，则默认用封面图
    List<String> parsedMedia = [];
    if (json['media_urls'] != null && json['media_urls'] is List) {
      parsedMedia = List<String>.from(json['media_urls']);
    }
    if (parsedMedia.isEmpty && coverUrl.isNotEmpty) {
      parsedMedia = [coverUrl];
    }

    return ProductModel(
      id: json['id']?.toString(),
      title: json['title'] ?? '',
      imageUrl: coverUrl,
      mediaUrls: parsedMedia,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      salesCount: json['sales_count'] ?? 0,
      shopName: json['shop_name'] ?? '',
      category: json['category']?.toString() ?? '1',
      subCategory: json['sub_category'] ?? '为你推荐',
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
          final fetchedProducts =
              data.map((e) => ProductModel.fromJson(e)).toList();
          if (fetchedProducts.isEmpty) {
            // 如果云端没有任何数据，强制降级使用本地 Mock 数据，防止白屏
            _products.addAll(_generateMockProducts());
          } else {
            _products.addAll(fetchedProducts);
            // 如果云端数据缺乏 category/subCategory 字段，补充 Mock 数据混合显示
            _products.addAll(_generateMockProducts());
          }
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
    final List<ProductModel> mocks = [];

    // 真实感极强的商铺名称字典
    final Map<String, List<String>> realShopNames = {
      '综合商店': ['无印良品 MUJI', 'Costco 极简生活', 'KKV 潮流集合', '优衣库 UNIQLO'],
      '网红餐饮': ['Shake Shack', '海底捞火锅', '太二酸菜鱼', '文和友'],
      '精品咖啡': ['% Arabica', 'Manner Coffee', 'Seesaw Coffee', '瑞幸咖啡'],
      '深夜酒吧': ['COMMUNE', '胡桃里', 'Helens 海伦司', 'TAO 酒吧'],
      '附近服务': ['极速开锁', '天鹅到家', '啄木鸟维修', '同城快送'],
      '上门保洁': ['自如保洁', '58同城精选', '闪电家政', '阿姨帮'],
      '家电维修': ['苏宁维修', '极客修', '十分到家', '百修将'],
      '同城搬家': ['货拉拉搬家', '快狗打车', '蓝犀牛', '蚂蚁搬家'],
    };

    // 真实感极强的商品/服务标题字典
    final Map<String, List<String>> realProductTitles = {
      '综合商店': ['超大容量旅行双肩包', '北欧风纯色纯棉床笠', '桌面收纳亚克力盲盒', '香薰蜡烛无火扩香'],
      '网红餐饮': ['招牌经典双人特惠套餐', '招牌牛蛙酸菜鱼套餐', '网红瀑布冰沙拿铁', '黯然销魂小龙虾'],
      '精品咖啡': ['西班牙拿铁', '桂花燕麦拿铁', '冷萃冰滴咖啡', '手冲瑰夏咖啡豆'],
      '深夜酒吧': ['百威纯生精酿畅饮', '长岛冰茶特调鸡尾酒', '莫吉托微醺套餐', '德式烤肠拼盘'],
      '为你推荐': ['2026新款降噪蓝牙耳机', '护眼级人体工学办公椅', '无绳跳绳燃脂健身', '便携式迷你筋膜枪', '桌面加湿器', '复古黑胶唱片机'],
      '数码极客': ['AirPods Pro 2代', '罗技机械键盘茶轴', '雷蛇无线游戏鼠标', '大疆头戴式运动相机', 'GaN 120W氮化镓快充', '便携式磁吸充电宝'],
      '潮流服饰': ['纯棉重磅宽松T恤', '复古直筒阔腿牛仔裤', '防晒冰丝透气外套', '阿甘鞋复古慢跑鞋', '极简无痕保暖内衣', '防水户外冲锋衣'],
      '品质家居': ['泰国进口乳胶枕', '智能感应垃圾桶', '北欧极简落地灯', '记忆棉护腰靠垫', '除螨吸尘器', '陶瓷不粘平底锅'],
      '附近服务': ['极速上门开锁换锁', '管道疏通/漏水维修', '家庭电路检测维修', '同城加急文件快送'],
      '上门保洁': ['日常深度保洁 3小时', '新居开荒保洁特惠', '厨房油烟机深度清洗', '全屋玻璃双面擦洗'],
      '家电维修': ['空调深度拆洗除菌', '洗衣机加氟/维修', '冰箱内筒消毒清洗', '电视机主板维修'],
      '同城搬家': ['金牌师傅同城搬家', '面包车小型拉货', '日式收纳打包搬家', '大件家具拆装搬运'],
    };

    // --- 0. 商店 (Store) ---
    final storeCategories = ['综合商店', '网红餐饮', '精品咖啡', '深夜酒吧'];
    for (var sub in storeCategories) {
      for (int i = 0; i < 4; i++) {
        final img1 = 'https://picsum.photos/id/${100 + i * 10}/800/450';
        final img2 = 'https://picsum.photos/id/${101 + i * 10}/800/450';
        final img3 = 'https://picsum.photos/id/${102 + i * 10}/800/450';
        mocks.add(
          ProductModel(
            title: realProductTitles[sub]?[i % 4] ?? '$sub - 招牌体验套餐 ${i + 1}',
            imageUrl: img1, // 16:9
            mediaUrls: [img1, img2, img3], // 模拟商家上传了 3 张图
            price: 99.0 + (i * 50),
            salesCount: 500 + i * 120,
            shopName: realShopNames[sub]?[i % 4] ?? '$sub 本地旗舰店',
            category: '0',
            subCategory: sub,
          ),
        );
      }
    }

    // --- 1. 商城 (Mall) ---
    final mallCategories = ['为你推荐', '数码极客', '潮流服饰', '品质家居'];
    for (var sub in mallCategories) {
      for (int i = 0; i < 6; i++) {
        mocks.add(
          ProductModel(
            title: realProductTitles[sub]?[i % 6] ?? '$sub - 2026新款降维打击极品 ${i + 1}',
            imageUrl: 'https://picsum.photos/id/${200 + i * 10}/400/600', // 竖向
            price: 199.0 + (i * 200),
            salesCount: 1000 + i * 300,
            shopName: '智选官方直营',
            category: '1',
            subCategory: sub,
          ),
        );
      }
    }

    // --- 2. 生活 (Life) ---
    final lifeCategories = ['附近服务', '上门保洁', '家电维修', '同城搬家'];
    for (var sub in lifeCategories) {
      for (int i = 0; i < 4; i++) {
        mocks.add(
          ProductModel(
            title: realProductTitles[sub]?[i % 4] ?? '$sub - 专业上门极速响应 ${i + 1}',
            imageUrl:
                'https://picsum.photos/id/${300 + i * 10}/800/450', // 16:9
            price: 50.0 + (i * 80),
            salesCount: 200 + i * 50,
            shopName: realShopNames[sub]?[i % 4] ?? '智选同城金牌',
            category: '2',
            subCategory: sub,
          ),
        );
      }
    }

    return mocks;
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

          // 使用 ScrollConfiguration 隐藏右侧的原生滚动条
          return ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              // 核心优化：物理级预渲染边界。
              // ignore: deprecated_member_use
              cacheExtent: 2500,
              slivers: [
                // 1. 顶部：模块化横向跑马灯 (Continuous Marquee)
                SliverSafeArea(
                  bottom: false,
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: SizedBox(
                        height: 140, // 仅占 140px 高度的长条形画廊
                        child: _HeroBannerContent(
                          categoryIndex: _selectedMainCategoryIndex,
                          isVisible: _isBannerVisible && widget.isTabActive,
                          onTap: (imageUrl) {
                            // 点击跑马灯，生成一个广告商品数据并跳转详情页
                            final adProduct = ProductModel(
                              title: '全息橱窗精选推荐',
                              imageUrl: imageUrl,
                              price: 999.0,
                              salesCount: 8888,
                              shopName: '智选官方广告',
                              category: _selectedMainCategoryIndex.toString(),
                              subCategory: '官方推荐',
                            );
                            _navigateToDetail(adProduct);
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. 中间：大分类和搜索框
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      top: 24.0,
                      bottom: 24.0,
                    ),
                    child: _MainCategorySelectorAndSearch(
                      selectedIndex: _selectedMainCategoryIndex,
                      onTap: () {
                        setState(() {
                          _selectedMainCategoryIndex =
                              (_selectedMainCategoryIndex + 1) % 3;
                        });
                      },
                    ),
                  ),
                ),

                // 为了让商品列表不被广告图盖住，必须加上这层真正的商品列表！
                // 这个列表就是您截图中看到消失的东西。
                if (_isLoading)
                  _buildSkeletonSliver(crossAxisCount)
                else if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Text(_errorMessage!, style: AppTypography.bodyLarge),
                    ),
                  )
                else
                  _buildHorizontalRowsSliver(),

                // 安全底部留白 (适配沉浸式导航栏)
                // 彻底删掉了那个 500px 的超级黑洞，防止出现“只剩背景”的错觉
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
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
            child: Text('暂无相关商品', style: AppTypography.bodyLarge),
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
          // 核心逻辑：精准过滤属于当前大类（category）且属于当前小类（subCategory）的商品
          final currentCategoryId = _selectedMainCategoryIndex.toString();

          final items = _products.where((p) {
            return p.category == currentCategoryId &&
                p.subCategory == categoryName;
          }).toList();

          // 如果该分类下没有数据，可以考虑隐藏该行，或者显示一个空状态。这里我们至少保证程序不崩溃。
          if (items.isEmpty) return const SizedBox.shrink();

          return _buildHorizontalRow(categoryName, items);
        },
        childCount: subCategories.length,
      ),
    );
  }

  Widget _buildHorizontalRow(String title, List<ProductModel> items) {
    // 动态卡片宽度与高度，进一步缩小尺寸提升空间利用率
    final double cardWidth = _selectedMainCategoryIndex == 1 ? 140 : 240;
    final double listHeight = _selectedMainCategoryIndex == 1 ? 190 : 135;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12.0),

        // 展位 (Hero Banner) - 每个模块专属的大图推荐位
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildSubCategoryBanner(
            title,
            items.isNotEmpty ? items.first : null,
          ),
        ),
        const SizedBox(height: 16.0),

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
                    : (_selectedMainCategoryIndex == 1
                        ? _buildMallCard(product)
                        : _buildLifeCard(product)),
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
            child: const Icon(
              Icons.arrow_forward_ios,
              color: Colors.black,
              size: 16,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '全部',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建每个子分类专属的展位（大图推荐）
  Widget _buildSubCategoryBanner(String title, ProductModel? product) {
    // 动态生成一个与分类相关的图片 URL，利用字符串的 hashCode 保证同一个分类每次加载图片一致
    final imageId = (title.hashCode % 500) + 10;

    return GestureDetector(
      onTap: () {
        if (product != null) {
          // 点击展位，跳转到该分类的广告聚合页或商品页，模拟广告点击效果
          final adProduct = ProductModel(
            title: '$title · 官方精选推荐',
            imageUrl: 'https://picsum.photos/id/$imageId/1000/400',
            price: product.price,
            salesCount: 9999,
            shopName: '智选精选展位',
            category: product.category,
            subCategory: product.subCategory,
          );
          _navigateToDetail(adProduct);
        }
      },
      child: Container(
        width: double.infinity,
        height: 160, // 展位固定高度，形成强烈的视觉冲击
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: 'https://picsum.photos/id/$imageId/1000/400',
              fit: BoxFit.cover,
              memCacheWidth: 1000,
              placeholder: (context, url) =>
                  Container(color: Colors.white.withValues(alpha: 0.05)),
            ),
            // 深色渐变遮罩，确保文字清晰
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
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            // 展位文案
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
                          '$title · 官方精选',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '发现本周最具人气的热门精选',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w300,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '去看看',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  /// 1. 商店卡片：横向 16:9 比例，侧重展示商店名、评分和距离
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
                memCacheWidth: 800, // 强制内存熔断
              ),
            ),
            // 沉浸式渐变遮罩 (底部)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100, // 减小遮罩高度
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            // 覆盖在上面的文字信息
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, // 减小字号
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        '4.9',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11, // 减小字号
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '1.2km',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11, // 减小字号
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '本地严选',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9, // 极小字号标签
                          ),
                        ),
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
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12, // 减小字号
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '¥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10, // 减小字号
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        product.price.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16, // 减小字号
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已售 ${product.salesCount}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 9, // 极小字号
                        ),
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

  /// 3. 生活卡片：58同城类服务，侧重展示服务商家名、评分和距离
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
            Container(color: Colors.black.withValues(alpha: 0.1)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100, // 减小遮罩高度
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            // 服务信息
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.shopName, // 展示商家名而不是标题
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14, // 减小字号
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '4.9',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11, // 减小字号
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '1.2km',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11, // 减小字号
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white, // 强制纯白
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '预约',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 11, // 减小字号
                        fontWeight: FontWeight.w500,
                      ),
                    ), // 强制纯黑
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
          Widget page = _selectedMainCategoryIndex == 1
              ? ProductDetailScreen(product: product)
              : LocalServiceDetailScreen(
                  product: product,
                  isStore: _selectedMainCategoryIndex == 0,
                );

          return FadeTransition(
            opacity: animation,
            child: page,
          );
        },
      ),
    );
  }
}

class HolographicHoverShowcase extends StatefulWidget {
  final List<String> imageUrls;
  final bool isVisible;
  final Function(String)? onTap;

  const HolographicHoverShowcase({
    super.key,
    required this.imageUrls,
    required this.isVisible,
    this.onTap,
  });

  @override
  State<HolographicHoverShowcase> createState() =>
      _HolographicHoverShowcaseState();
}

class _HolographicHoverShowcaseState extends State<HolographicHoverShowcase> {
  Timer? _timer;
  PageController? _pageController; // 改为可空，因为需要在 build 中动态获取屏幕宽度
  double _currentViewportFraction = 0.85;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _initPageControllerIfNeeded(double screenWidth) {
    // 动态计算视口比例：手机上是 0.85 (一张图占 85%)，宽屏上根据宽度分配，例如每张图固定约 300-400px 宽
    double targetFraction = 0.85;
    if (screenWidth > 1200) {
      targetFraction = 0.25; // 宽屏显示 4 张
    } else if (screenWidth > 800) {
      targetFraction = 0.4; // 中屏显示 2.5 张
    }

    // 如果比例变了，或者还没初始化，就重新创建控制器
    if (_pageController == null || _currentViewportFraction != targetFraction) {
      _currentViewportFraction = targetFraction;
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: widget.imageUrls.length * 100,
        viewportFraction: _currentViewportFraction,
      );
    }
  }

  void _startTimer() {
    if (!widget.isVisible) return;
    // 横向 5 秒轮播
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _pageController != null && _pageController!.hasClients) {
        _pageController!.nextPage(
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
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox();

    // 修改为使用父组件的约束高度，或者默认高度
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final screenWidth = MediaQuery.of(context).size.width;

        // 根据当前屏幕宽度初始化或更新 PageController
        _initPageControllerIfNeeded(screenWidth);

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
              return GestureDetector(
                onTap: () => widget.onTap?.call(widget.imageUrls[realIndex]),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0), // 添加卡片间距
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // 增加圆角
                  ),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[realIndex],
                    fit: BoxFit.cover,
                    alignment: Alignment.center, // 居中对齐
                    width: double.infinity,
                    height: height,
                    memCacheWidth: 800, // 适当降低缓存大小
                    placeholder: (context, url) =>
                        Container(color: Colors.white.withValues(alpha: 0.1)),
                    errorWidget: (context, url, error) =>
                        Container(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// 动态比例的广告区 (全息橱窗)
class _HeroBannerContent extends StatelessWidget {
  final int categoryIndex;
  final bool isVisible;
  final Function(String)? onTap;

  const _HeroBannerContent({
    required this.categoryIndex,
    required this.isVisible,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 动态生成 10 个高清广告图
    final List<String> imageUrls = List.generate(
      10,
      (i) =>
          'https://picsum.photos/id/${(categoryIndex + 1) * 100 + i + 10}/1200/800',
    );

    // 彻底干掉 SafeArea 或者 MediaQuery 的 padding
    // 让图片真正从屏幕的最物理顶端开始绘制，无视任何控制栏
    return Container(
      color: Colors.transparent,
      child: HolographicHoverShowcase(
        imageUrls: imageUrls,
        isVisible: isVisible,
        onTap: onTap,
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
      'https://picsum.photos/id/20/100/100', // 商城
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
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

  Widget _buildAvatar(
    String imageUrl,
    double leftPos,
    bool isSelected,
    int zIndex,
  ) {
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ]
              : null,
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
              errorWidget: (context, url, error) =>
                  Container(color: Colors.grey[900]),
            ),
          ),
        ),
      ),
    );
  }
}

// 已经移除 _CardOverlayPainter 类
