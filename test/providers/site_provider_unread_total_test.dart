import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  SiteConfig testSite(String id) => SiteConfig(id: id, name: 'Site $id');

  SiteUserInfo infoWithCount(String siteId, int? n) =>
      SiteUserInfo(siteId: siteId, messageCount: n);

  group('SiteProvider.unreadTotal', () {
    test('空 _userInfo 返回 0', () {
      final provider = SiteProvider();
      expect(provider.unreadTotal, 0);
    });

    test('含 null messageCount 返回 0', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.updateUserInfo(infoWithCount('a', null));
      expect(provider.unreadTotal, 0);
    });

    test('含 0 messageCount 返回 0', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.updateUserInfo(infoWithCount('a', 0));
      expect(provider.unreadTotal, 0);
    });

    test('累加所有 > 0 的 messageCount', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.addSite(testSite('b'));
      await provider.addSite(testSite('c'));
      await provider.addSite(testSite('d'));
      await provider.updateUserInfo(infoWithCount('a', 3));
      await provider.updateUserInfo(infoWithCount('b', 5));
      await provider.updateUserInfo(infoWithCount('c', null));
      await provider.updateUserInfo(infoWithCount('d', 0));
      expect(provider.unreadTotal, 8);
    });
  });
}
