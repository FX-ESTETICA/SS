import 'package:flutter/material.dart';
import 'package:core_design_system/core_design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:feature_shop/feature_shop.dart'; // 引入商城模块以获取 ProductModel 和详情页

class BookingRecordsScreen extends StatefulWidget {
  const BookingRecordsScreen({super.key});

  @override
  State<BookingRecordsScreen> createState() => _BookingRecordsScreenState();
}

class _BookingRecordsScreenState extends State<BookingRecordsScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedSpatialBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32), // 给顶部系统控制条留出拖拽空间
              _buildTopBar(),
              const SizedBox(height: 24),
              _buildTabs(),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double width = constraints.maxWidth;
                    // 屏幕越宽，一行显示的卡片越多，保持卡片比例不要被无限拉长
                    int crossAxisCount = 1;
                    if (width > 1200) {
                      crossAxisCount = 4;
                    } else if (width > 800) {
                      crossAxisCount = 3;
                    } else if (width > 600) {
                      crossAxisCount = 2;
                    }

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: width / crossAxisCount / 180, // 动态计算宽高比，让高度固定在 180 左右
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      physics: const BouncingScrollPhysics(),
                      children: _selectedTabIndex == 0
                          ? [
                              // Tab 0: 预约记录
                              _buildPendingCard(),
                              _buildCompletedCard(),
                              _buildCancelledCard(),
                            ]
                          : [
                              // Tab 1: 消费记录
                              _buildConsumptionCard(
                                shopName: '智选官方直营',
                                shopImageUrl: 'https://picsum.photos/id/210/800/450',
                                serviceName: '高级剪发套餐',
                                date: '2023-10-25 15:30',
                                amount: '128.00',
                              ),
                              _buildConsumptionCard(
                                shopName: '罗马阳光直邮',
                                shopImageUrl: 'https://picsum.photos/id/101/800/450',
                                serviceName: '意大利进口洗发水',
                                date: '2023-10-20 11:00',
                                amount: '356.00',
                              ),
                              _buildConsumptionCard(
                                shopName: '极速出行',
                                shopImageUrl: 'https://picsum.photos/id/310/800/450',
                                serviceName: '深度保洁服务',
                                date: '2023-09-12 14:00',
                                amount: '299.00',
                              ),
                            ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: const DecorationImage(
                image: CachedNetworkImageProvider(
                  'https://pub-43cf2479c66540898a3717f1a1ba26cc.r2.dev/shop_item_1.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'ManageMe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 28),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildTabItem('预约记录', 0),
          const SizedBox(width: 24),
          _buildTabItem('消费记录', 1),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.filter_list, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSelected ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: 3,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return _buildBaseCard(
      shopName: '智选官方直营',
      shopImageUrl: 'https://picsum.photos/id/210/800/450', // 引用真实且有效的网络图片
      serviceName: '理发服务',
      statusText: '待服务',
      statusIsSolid: true, // 纯白底黑字，最醒目
      date: '2023-10-25 14:00',
      bottomContent: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildOutlinedButton('修改预约'),
        ],
      ),
    );
  }

  Widget _buildCompletedCard() {
    return _buildBaseCard(
      shopName: '罗马阳光直邮',
      shopImageUrl: 'https://picsum.photos/id/101/800/450',
      serviceName: '高端洗发护理',
      statusText: '已完成',
      statusIsSolid: false, // 白框白字
      date: '2023-10-20 10:30',
      bottomContent: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildSolidButton('欢迎评价'),
        ],
      ),
    );
  }

  Widget _buildCancelledCard() {
    return _buildBaseCard(
      shopName: '极速出行',
      shopImageUrl: 'https://picsum.photos/id/310/800/450',
      serviceName: '头皮深层清洁',
      statusText: '已取消',
      statusIsSolid: false,
      date: '2023-10-15 16:00',
    );
  }

  /// 消费记录专属卡片
  Widget _buildConsumptionCard({
    required String shopName,
    required String shopImageUrl,
    required String serviceName,
    required String date,
    required String amount,
  }) {
    return _buildBaseCard(
      shopName: shopName,
      shopImageUrl: shopImageUrl,
      serviceName: serviceName,
      statusText: '已支付',
      statusIsSolid: true,
      date: date,
      bottomContent: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text(
            '¥',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22, // 金额使用稍大字号突出
              fontWeight: FontWeight.w800, // 稍微加粗
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseCard({
    required String shopName,
    required String shopImageUrl,
    required String serviceName,
    required String statusText,
    required bool statusIsSolid,
    required String date,
    Widget? bottomContent,
  }) {
    return GestureDetector(
      onTap: () {
        // 构建一个模拟的 ProductModel 并跳转到服务详情页
        final mockProduct = ProductModel(
          title: serviceName,
          imageUrl: shopImageUrl,
          mediaUrls: [shopImageUrl],
          price: 0,
          salesCount: 0,
          shopName: shopName,
          category: '2', // 生活服务
          subCategory: '附近服务',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocalServiceDetailScreen(
              product: mockProduct,
              isStore: false,
              isMerchantMode: false, // 消费者视角
            ),
          ),
        );
      },
      child: Container(
        height: 180, // 固定高度，确保背景图有足够的展示空间
        clipBehavior: Clip.antiAlias, // 必须加上裁剪，否则图片可能会溢出圆角
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 底层图片：使用 CachedNetworkImage Widget 替代 Provider 以确保可靠渲染和异常处理
            CachedNetworkImage(
              imageUrl: shopImageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
              placeholder: (context, url) => Container(color: Colors.grey[900]),
            ),
            
            // 2. 遮罩层与内容层
            Container(
              // 添加渐变遮罩，确保底层白色文字清晰可见
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1), // 顶部微暗，透出图片
                    Colors.black.withValues(alpha: 0.7), // 底部加深，承载文字和按钮
                    Colors.black.withValues(alpha: 0.9), // 极底更深，承载按钮
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 上下两端对齐
                children: [
                  // 顶部：只保留状态标签 (放在右上角)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusIsSolid ? Colors.white : Colors.transparent,
                          border: statusIsSolid
                              ? null
                              : Border.all(color: Colors.white, width: 1.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusIsSolid ? Colors.black : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 底部：商铺名、服务名、时间与操作按钮
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$serviceName · $shopName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    date,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8), // 时间稍弱化
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (bottomContent != null) 
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: bottomContent,
                            ),
                        ],
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

  Widget _buildOutlinedButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: Colors.white, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSolidButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}


