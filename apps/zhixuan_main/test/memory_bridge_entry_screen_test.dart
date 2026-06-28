import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhixuan_main/memory_bridge/memory_bridge_entry_screen.dart';

void main() {
  testWidgets('Memory bridge route screen renders expected content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MemoryBridgeEntryScreen(),
      ),
    );

    expect(find.text('项目记忆桥接'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Memory Bridge 已正式接入 App 路由'), findsOneWidget);
    expect(find.text('读取记忆'), findsOneWidget);
  });
}
