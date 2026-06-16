import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig testSite(String id) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: ['电影'],
    );

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

  group('站点 CRUD', () {
    test('addSite 添加站点并通知监听者', () async {
      final provider = SiteProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addSite(testSite('site-1'));

      expect(provider.sites.length, 1);
      expect(provider.sites.first.id, 'site-1');
      expect(notified, true);
    });

    test('updateSite 更新站点并通知监听者', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      var notified = false;
      provider.addListener(() => notified = true);

      final updated = testSite('site-1').copyWith(name: 'Updated');
      await provider.updateSite('site-1', updated);

      expect(provider.sites.first.name, 'Updated');
      expect(notified, true);
    });

    test('deleteSite 删除站点并通知监听者', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));
      await provider.addSite(testSite('site-2'));

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deleteSite('site-1');

      expect(provider.sites.length, 1);
      expect(provider.sites.first.id, 'site-2');
      expect(notified, true);
    });

    test('loadSites 从存储加载站点', () async {
      final provider1 = SiteProvider();
      await provider1.addSite(testSite('site-1'));
      await provider1.addSite(testSite('site-2'));

      final provider2 = SiteProvider();
      await provider2.loadSites();

      expect(provider2.sites.length, 2);
      expect(provider2.sites.map((s) => s.id), containsAll(['site-1', 'site-2']));
    });

    test('addSite 不允许重复 id', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      await provider.addSite(testSite('site-1'));
      expect(provider.sites.length, 1);
    });
  });

  group('预设导入', () {
    test('importPresets 批量导入预设', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(id: 'a', name: 'A'),
        const SitePreset(id: 'b', name: 'B'),
      ];

      await provider.importPresets(presets);

      expect(provider.sites.length, 2);
      expect(provider.sites.first.sortOrder, 1);
      expect(provider.sites.last.sortOrder, 2);
    });

    test('importPresets 跳过已存在的站点', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));

      final presets = [
        const SitePreset(id: 'a', name: 'A-New'),
        const SitePreset(id: 'b', name: 'B'),
      ];

      await provider.importPresets(presets);

      expect(provider.sites.length, 2);
      expect(provider.sites.firstWhere((s) => s.id == 'a').name, 'Site a');
    });

    test('importPresets 把 preset.schema 复制到 site.parseSchema.schema', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(
          id: 'gazelle-x',
          name: 'Gazelle X',
          schema: 'Gazelle',
        ),
        // preset 无 schema 时不创建 parseSchema
        const SitePreset(id: 'default', name: 'Default'),
        // preset 同时有 schema 和 parseSchema 时合并
        const SitePreset(
          id: 'merge',
          name: 'Merge',
          schema: 'Gazelle',
          parseSchema: SiteParseSchema(bonusLabels: ['啤酒瓶']),
        ),
      ];

      await provider.importPresets(presets);

      final gz = provider.sites.firstWhere((s) => s.id == 'gazelle-x');
      expect(gz.parseSchema, isNotNull);
      expect(gz.parseSchema!.schema, equals('Gazelle'));

      final def = provider.sites.firstWhere((s) => s.id == 'default');
      expect(def.parseSchema, isNull);

      final m = provider.sites.firstWhere((s) => s.id == 'merge');
      expect(m.parseSchema, isNotNull);
      expect(m.parseSchema!.schema, equals('Gazelle'));
      expect(m.parseSchema!.bonusLabels, equals(['啤酒瓶']));
    });
  });

  group('Cookie 管理', () {
    test('saveCookie 持久化并通知', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.saveCookie('site-1', 'uid=123; pass=abc');

      expect(provider.getCookieString('site-1'), 'uid=123; pass=abc');
      expect(notified, true);
    });

    test('deleteCookie 清除 cookie', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));
      await provider.saveCookie('site-1', 'uid=123');

      await provider.deleteCookie('site-1');

      expect(provider.getCookieString('site-1'), isNull);
    });
  });

  group('用户信息', () {
    test('updateUserInfo 更新并通知', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      final info = SiteUserInfo(
        siteId: 'site-1',
        username: 'testuser',
        ratio: 2.5,
        uploaded: 1000,
      );

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateUserInfo(info);

      expect(provider.getUserInfo('site-1')?.username, 'testuser');
      expect(provider.getUserInfo('site-1')?.ratio, 2.5);
      expect(notified, true);
    });

    test('getUserInfo 返回 null（无数据）', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      expect(provider.getUserInfo('site-1'), isNull);
    });
  });

  group('fetchUserInfo', () {
    test('站点不存在时抛出异常', () async {
      final provider = SiteProvider();
      await provider.loadSites();
      expect(
        () => provider.fetchUserInfo('nonexistent'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('筛选与搜索', () {
    test('filteredSites 按搜索关键词过滤', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      provider.searchQuery = 'Alpha';
      expect(provider.filteredSites.length, 1);
      expect(provider.filteredSites.first.name, 'Alpha');

      provider.searchQuery = '';
      expect(provider.filteredSites.length, 2);
    });

    test('filteredSites 按标签过滤', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      provider.tagFilter = '电影';
      expect(provider.filteredSites.length, 1);
      expect(provider.filteredSites.first.name, 'Alpha');

      provider.tagFilter = null;
      expect(provider.filteredSites.length, 2);
    });

    test('allTags 收集所有站点的标签', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影', '官组']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      expect(provider.allTags, containsAll(['电影', '官组', '音乐']));
    });
  });
}
