import 'package:go_router/go_router.dart';

import 'package:feature_shop/feature_shop.dart';
import '../main.dart';

// @AI_CONTEXT: [2026-06-26] 引入 go_router 进行物理路由解耦。
// 所有的模块互不依赖，全部在这个全局 AppRouter 中进行中转。
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/shop/detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};

        // 构建一个模拟的 ProductModel 用于跳转
        final mockProduct = ProductModel(
          title: extra['serviceName'] ?? '未知服务',
          imageUrl: extra['shopImageUrl'] ?? '',
          mediaUrls: [extra['shopImageUrl'] ?? ''],
          price: 0,
          salesCount: 0,
          shopName: extra['shopName'] ?? '未知店铺',
          category: '2', // 生活服务
          subCategory: '附近服务',
        );

        return LocalServiceDetailScreen(
          product: mockProduct,
          isStore: false,
          isMerchantMode: false,
        );
      },
    ),
  ],
);
