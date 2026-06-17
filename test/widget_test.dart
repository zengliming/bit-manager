import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bit_manager/main.dart';

void main() {
  testWidgets('App should build without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BitManagerApp());

    // 默认侧边栏收起，汉堡按钮存在
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // 点汉堡按钮展开侧边栏，展开后显示 4 个文字标签
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('站点'), findsWidgets);
    expect(find.text('下载器'), findsWidgets);
    expect(find.text('种子'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
