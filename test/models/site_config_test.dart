import 'package:bit_manager/models/site_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteConfig', () {
    test('fromJson / toJson round-trip', () {
      final original = SiteConfig(
        id: 'm-team',
        name: 'M-Team',
        baseUrl: 'https://m-team.cc',
        tags: ['电影', '官组'],
        notes: '测试备注',
        isActive: true,
        sortOrder: 3,
      );
      final json = original.toJson();
      final restored = SiteConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.tags, original.tags);
      expect(restored.notes, original.notes);
      expect(restored.isActive, original.isActive);
      expect(restored.sortOrder, original.sortOrder);
    });

    test('copyWith preserves id and addedAt', () {
      final original = SiteConfig(
        id: 'hdtime',
        name: 'HDTime',
        baseUrl: 'https://hdtime.org',
      );
      final copy = original.copyWith(name: 'HDTime-New', sortOrder: 5);

      expect(copy.id, 'hdtime');
      expect(copy.name, 'HDTime-New');
      expect(copy.sortOrder, 5);
      expect(copy.addedAt, original.addedAt);
      expect(copy.baseUrl, 'https://hdtime.org');
    });

    test('default values', () {
      final config = SiteConfig(id: 'test', name: 'Test');
      expect(config.tags, isEmpty);
      expect(config.isActive, true);
      expect(config.sortOrder, 0);
      expect(config.notes, isNull);
    });
  });

  group('SitePreset', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'm-team',
        'name': 'M-Team',
        'baseUrl': 'https://m-team.cc',
        'tags': ['电影', '综合'],
        'aka': ['馒头', 'MTeam'],
        'description': '综合性网站，有分享率要求',
        'iconAsset': 'assets/sites/icons/m-team.ico',
        'category': '影视',
      };
      final preset = SitePreset.fromJson(json);

      expect(preset.id, 'm-team');
      expect(preset.name, 'M-Team');
      expect(preset.baseUrl, 'https://m-team.cc');
      expect(preset.tags, ['电影', '综合']);
      expect(preset.aka, ['馒头', 'MTeam']);
      expect(preset.description, '综合性网站，有分享率要求');
      expect(preset.iconAsset, 'assets/sites/icons/m-team.ico');
      expect(preset.category, '影视');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 'test', 'name': 'Test'};
      final preset = SitePreset.fromJson(json);

      expect(preset.baseUrl, isNull);
      expect(preset.tags, isEmpty);
      expect(preset.iconAsset, isNull);
      expect(preset.category, isNull);
    });

    test('SitePreset 序列化/反序列化包含 schema 字段', () {
      final preset = SitePreset(
        id: 'gazelle-test',
        name: 'Gazelle Test',
        baseUrl: 'https://example.com',
        schema: 'Gazelle',
      );
      final json = preset.toJson();
      expect(json['schema'], equals('Gazelle'));

      final restored = SitePreset.fromJson(Map<String, dynamic>.from(json));
      expect(restored.schema, equals('Gazelle'));
    });

    test('SitePreset schema 为 null 时不写入 json', () {
      final preset = SitePreset(id: 'default', name: 'Default');
      final json = preset.toJson();
      expect(json.containsKey('schema'), isFalse);
    });

    test('SitePreset.fromJson 缺失 schema 时返回 null', () {
      final restored = SitePreset.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'X',
      });
      expect(restored.schema, isNull);
    });
  });

  group('SiteParseSchema', () {
    test('copyWith({schema}) 保留其它字段', () {
      final orig = SiteParseSchema(
        schema: 'NexusPHP',
        userDetailsPath: '/userdetails.php',
        fields: {
          'uploaded': const FieldRule(selector: ['td.x + td']),
        },
        bonusLabels: ['啤酒瓶'],
        seedingLabels: ['当前做种'],
      );
      final copied = orig.copyWith(schema: 'Gazelle');
      expect(copied.schema, equals('Gazelle'));
      expect(copied.userDetailsPath, equals('/userdetails.php'));
      expect(copied.fields, isNotNull);
      expect(copied.fields!['uploaded']!.selector, equals(['td.x + td']));
      expect(copied.bonusLabels, equals(['啤酒瓶']));
      expect(copied.seedingLabels, equals(['当前做种']));
    });

    test('copyWith() 不传参数时返回等价副本', () {
      final orig = SiteParseSchema(schema: 'NexusPHP', userDetailsPath: '/x');
      final copied = orig.copyWith();
      expect(copied.schema, equals('NexusPHP'));
      expect(copied.userDetailsPath, equals('/x'));
    });
  });

  group('SiteUserInfo', () {
    test('fromJson / toJson round-trip', () {
      final original = SiteUserInfo(
        siteId: 'm-team',
        username: 'testuser',
        uploaded: 1073741824,
        downloaded: 536870912,
        ratio: 2.0,
        level: 'Elite',
        bonusPoints: 5000,
        seedingCount: 42,
        leechingCount: 3,
        lastFetchedAt: DateTime(2026, 6, 10),
        fetchFailed: false,
      );
      final json = original.toJson();
      final restored = SiteUserInfo.fromJson(json);

      expect(restored.siteId, original.siteId);
      expect(restored.username, original.username);
      expect(restored.uploaded, original.uploaded);
      expect(restored.downloaded, original.downloaded);
      expect(restored.ratio, original.ratio);
      expect(restored.level, original.level);
      expect(restored.bonusPoints, original.bonusPoints);
      expect(restored.seedingCount, original.seedingCount);
      expect(restored.leechingCount, original.leechingCount);
      expect(restored.fetchFailed, false);
    });

    test('default values', () {
      final info = SiteUserInfo(siteId: 'test');
      expect(info.username, isNull);
      expect(info.fetchFailed, false);
    });
  });

  group('SiteCookie', () {
    test('default values', () {
      final cookie = SiteCookie(siteId: 'test');
      expect(cookie.siteId, 'test');
      expect(cookie.cookieString, isNull);
      expect(cookie.isLoginValid, false);
    });
  });
}
