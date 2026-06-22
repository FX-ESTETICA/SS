import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 商品数据模型
class ProductModel {
  final String title;
  final String imageUrl;
  final double price;
  final int salesCount;
  final String shopName;

  ProductModel({
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.salesCount,
    required this.shopName,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
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

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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
      if (mounted) {
        setState(() {
          _errorMessage = '获取商品失败，请检查网络或数据库配置';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildSearchBar(),
      body: _buildBody(),
    );
  }

  /// 仿淘宝顶部搜索栏
  PreferredSizeWidget _buildSearchBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text('搜索全网低价好物', style: AppTypography.body.copyWith(color: Colors.grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('搜索', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildSkeleton(); // 降维打击：骨架屏加载
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: AppTypography.body));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _isLoading = true);
        _products.clear();
        await _fetchProducts();
      },
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(8),
        crossAxisCount: 2, // 两列瀑布流
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: _products.length,
        itemBuilder: (context, index) {
          return _ProductCard(product: _products[index]);
        },
      ),
    );
  }

  /// 骨架屏 (Skeleton) 渲染
  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: MasonryGridView.count(
        padding: const EdgeInsets.all(8),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            height: index % 2 == 0 ? 250 : 300, // 错落有致的骨架
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }
}

/// 单个商品卡片
class _ProductCard extends StatelessWidget {
  final ProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 商品主图 (带网络缓存)
          AspectRatio(
            aspectRatio: 1, // 正方形图或者根据实际图片比例计算
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.grey[200]),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          
          // 2. 商品信息区
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题 (最多两行)
                Text(
                  product.title,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // 价格与销量
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('¥', style: AppTypography.caption.copyWith(color: AppColors.error)),
                    Text(
                      product.price.toStringAsFixed(2),
                      style: AppTypography.h1.copyWith(color: AppColors.error, fontSize: 18),
                    ),
                    const Spacer(),
                    Text(
                      '已售 ${product.salesCount}',
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // 店铺名称
                Row(
                  children: [
                    Text(product.shopName, style: AppTypography.caption),
                    const Icon(Icons.chevron_right, size: 12, color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
