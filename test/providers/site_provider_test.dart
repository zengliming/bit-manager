import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:bit_manager/utils/storage.dart';
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
    LocalStorage.resetForTest();
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
      expect(
        provider2.sites.map((s) => s.id),
        containsAll(['site-1', 'site-2']),
      );
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

    test('importPresets 把 preset.iconAsset 复制到 site.iconAsset', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(
          id: 'agsvpt',
          name: 'AGSV',
          iconAsset: 'assets/sites/icons/agsvpt.png',
        ),
        const SitePreset(id: 'noicon', name: 'NoIcon'),
      ];

      await provider.importPresets(presets);

      final agsv = provider.sites.firstWhere((s) => s.id == 'agsvpt');
      expect(agsv.iconAsset, 'assets/sites/icons/agsvpt.png');

      final noicon = provider.sites.firstWhere((s) => s.id == 'noicon');
      expect(noicon.iconAsset, isNull);
    });

    test('importPresets 把 preset.type 复制到 site.type', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(id: 'dmhy', name: 'DMHY', type: 'public'),
        const SitePreset(id: 'mteam', name: 'M-Team'), // 私有（默认）
      ];

      await provider.importPresets(presets);

      expect(provider.sites.firstWhere((s) => s.id == 'dmhy').type, 'public');
      expect(provider.sites.firstWhere((s) => s.id == 'mteam').type, isNull);
    });

    test('importPresets 对 preset.iconAsset 为 null 的站做 probe 兜底', () async {
      // 提前加载默认 schema 资源
      await SiteService.ensureDefaultSchemaLoaded();

      final provider = SiteProvider();
      // aither.ico 存在；preset.iconAsset 故意留 null，验证 probe 兜底
      const presets = [SitePreset(id: 'aither', name: 'Aither')];

      await provider.importPresets(presets);

      final aither = provider.sites.firstWhere((s) => s.id == 'aither');
      expect(aither.iconAsset, 'assets/sites/icons/aither.ico');
    });

    test('importPresets 优先用 probe 结果，覆盖 preset.iconAsset 错误值', () async {
      // 验证即使 preset.iconAsset 指向不存在的文件，probe 找到正确路径后用 probe 的
      await SiteService.ensureDefaultSchemaLoaded();

      final provider = SiteProvider();
      // preset.iconAsset 故意写错（指向不存在的 .ico），但实际文件是 .png
      const presets = [
        SitePreset(
          id: 'agsvpt',
          name: 'AGSV',
          iconAsset: 'assets/sites/icons/agsvpt.ico', // 错的：实际是 .png
        ),
      ];

      await provider.importPresets(presets);

      final agsv = provider.sites.firstWhere((s) => s.id == 'agsvpt');
      expect(agsv.iconAsset, 'assets/sites/icons/agsvpt.png');
    });

    test('SiteConfig JSON 序列化保留 type 字段', () {
      final site = SiteConfig(id: 'dmhy', name: 'DMHY', type: 'public');
      final json = site.toJson();
      expect(json['type'], 'public');

      final restored = SiteConfig.fromJson({
        'id': 'dmhy',
        'name': 'DMHY',
        'type': 'public',
        'tags': [],
        'isActive': true,
        'sortOrder': 1,
        'addedAt': '2024-01-01T00:00:00.000',
      });
      expect(restored.type, 'public');
    });

    test('SiteConfig JSON 反序列化缺 type 字段时默认为 null', () {
      final restored = SiteConfig.fromJson({
        'id': 'old',
        'name': 'Old',
        'tags': [],
        'isActive': true,
        'sortOrder': 1,
        'addedAt': '2024-01-01T00:00:00.000',
      });
      expect(restored.type, isNull);
    });

    test('loadSites 对老数据（iconAsset 为 null）做 probe 兜底', () async {
      // 旧版 JSON 没有 iconAsset 字段
      SharedPreferences.setMockInitialValues({
        'sites':
            '[{"id":"aither","name":"Aither","baseUrl":"https://aither.example","tags":[],"isActive":true,"sortOrder":1,"addedAt":"2024-01-01T00:00:00.000"}]',
      });

      final provider = SiteProvider();
      await provider.loadSites();

      expect(provider.sites.length, 1);
      expect(provider.sites.first.iconAsset, 'assets/sites/icons/aither.ico');
    });

    test('refreshAllUserInfo 跳过 public 类型的站点', () async {
      // 提前加载默认 schema 资源
      await SiteService.ensureDefaultSchemaLoaded();

      final provider = SiteProvider();
      // 一个 public 站，一个 private 站
      await provider.addSite(
        SiteConfig(
          id: 'dmhy',
          name: 'DMHY',
          baseUrl: 'https://share.dmhy.org',
          type: 'public',
        ),
      );
      await provider.addSite(
        SiteConfig(
          id: 'mteam',
          name: 'M-Team',
          baseUrl: 'https://m-team.example',
        ),
      );
      // 给两个都加 cookie
      await provider.saveCookie('dmhy', 'uid=1');
      await provider.saveCookie('mteam', 'uid=2');

      final (success, failed) = await provider.refreshAllUserInfo();

      // public 站 dmhy 应被跳过：既不成功也不失败
      expect(success + failed, lessThan(2));
      // dmhy 不应有 userInfo（被跳过）
      expect(provider.getUserInfo('dmhy'), isNull);
    });

    test('fetchUserInfo 对 public 站直接返回 false，不污染 fetchFailed', () async {
      await SiteService.ensureDefaultSchemaLoaded();

      final provider = SiteProvider();
      await provider.addSite(
        SiteConfig(
          id: 'dmhy',
          name: 'DMHY',
          baseUrl: 'https://share.dmhy.org',
          type: 'public',
        ),
      );

      final result = await provider.fetchUserInfo('dmhy');
      expect(result, isFalse);
      // 不应写入任何 userInfo（包括 fetchFailed=true 的占位）
      expect(provider.getUserInfo('dmhy'), isNull);
    });

    test('importPresets 把 preset.schema 复制到 site.parseSchema.schema', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(id: 'gazelle-x', name: 'Gazelle X', schema: 'Gazelle'),
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
      await provider.addSite(
        SiteConfig(id: 'a', name: 'Alpha', tags: ['电影', '官组']),
      );
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      expect(provider.allTags, containsAll(['电影', '官组', '音乐']));
    });
  });

  group('refreshAllUserInfo 时间标记', () {
    test('无可刷新站点时不标记 lastSiteRefreshAt', () async {
      // 无 Cookie 站点 → targets 为空 → 直接返回 (0,0)，不标记时间
      final provider = SiteProvider();
      await provider.addSite(testSite('s1'));

      expect(provider.lastSiteRefreshAt, isNull);

      final (success, failed) = await provider.refreshAllUserInfo();

      expect(success, 0);
      expect(failed, 0);
      // 无可刷新站点不应标记时间（保持 null）
      expect(provider.lastSiteRefreshAt, isNull);
    });
  });
}
