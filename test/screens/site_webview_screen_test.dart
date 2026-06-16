import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/screens/site_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  testWidgets('site.baseUrl 为空时显示提示', (tester) async {
    final site = SiteConfig(id: 'a', name: 'A', baseUrl: null);

    await tester.pumpWidget(
      MaterialApp(
        home: SiteWebViewScreen(site: site, path: '/messages.php'),
      ),
    );

    expect(find.text('该站点未配置 URL'), findsOneWidget);
    expect(find.byType(WebViewWidget), findsNothing);
  });

  testWidgets('site 存在 baseUrl 时渲染 AppBar 标题', (tester) async {
    final site = SiteConfig(
      id: 'a',
      name: 'Example',
      baseUrl: 'https://example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiteWebViewScreen(site: site, path: '/messages.php'),
      ),
    );

    expect(find.text('Example · 消息'), findsOneWidget);
  });
}
