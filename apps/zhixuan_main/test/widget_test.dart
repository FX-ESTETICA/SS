// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:core_network/core_network.dart';

import 'package:zhixuan_main/main.dart';

void main() {
  testWidgets('App launch test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    final apiClient = ApiClient(baseUrl: 'https://test.api.zhixuan.global');
    await tester.pumpWidget(ZhixuanSuperApp(apiClient: apiClient));

    // Verify that the super app shell is mounted
    expect(find.text('智选'), findsWidgets);
    expect(find.text('短视频'), findsOneWidget);
  });
}
