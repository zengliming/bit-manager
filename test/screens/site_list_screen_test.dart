import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:bit_manager/screens/site_list_screen.dart';
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig _site(String id) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: const ['电影'],
    );

Widget _wrap(SiteProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: SiteListScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('站点非空时顶部显示统计卡片含站点数', (tester) async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1'));
    await provider.updateUserInfo(SiteUserInfo(
      siteId: 's1',
      uploaded: 1024,
      lastFetchedAt: DateTime(2026, 6, 17, 10),
    ));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    // 卡片顶部概览行应含"站点 1"
    expect(find.textContaining('站点 1'), findsOneWidget);
  });

  testWidgets('站点为空时不显示统计卡片，显示空状态', (tester) async {
    final provider = SiteProvider();

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('还没有添加站点'), findsOneWidget);
  });
}
