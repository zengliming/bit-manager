import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/screens/site_webview_screen.dart';
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('site.baseUrl 为空时显示提示', (tester) async {
    final site = SiteConfig(id: 'a', name: 'A', baseUrl: null);

    await tester.pumpWidget(
      MaterialApp(
        home: SiteWebViewScreen(site: site, path: '/messages.php'),
      ),
    );

    expect(find.text('该站点未配置 URL'), findsOneWidget);
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

  group('cookie 注入与加载', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (call) async => null,
          );
      // mock webview_cookie_manager 平台通道，模拟注入成功
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('webview_cookie_manager'),
            (call) async => null,
          );
      LocalStorage.resetForTest();
    });

    testWidgets('cookie 存在时不出现 cookie 缺失占位', (tester) async {
      final storage = await LocalStorage.getInstance();
      await storage.setString('cookie_a', 'uid=1; pass=abc');
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
      // 让 async _bootstrap 跑完
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 关键断言：cookie 缺失占位不应出现，说明 bootstrap 走过了 cookie 检查
      expect(find.text('该站点未配置 Cookie'), findsNothing);
      expect(find.text('该站点未配置 URL'), findsNothing);
    });

    testWidgets('cookie 不存在时显示错误占位', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('该站点未配置 Cookie'), findsOneWidget);
    });
  });
}
