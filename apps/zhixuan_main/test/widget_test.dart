// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_network/core_network.dart';

import 'package:zhixuan_main/main.dart';

void main() {
  testWidgets('Super App Shell renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final apiClient = ApiClient(baseUrl: 'https://test.api.zhixuan.global');
    await tester.pumpWidget(ZhixuanSuperApp(apiClient: apiClient));

    // Verify that our app shell renders at least the bottom navigation bar
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
