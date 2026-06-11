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
        'iconAsset': 'assets/sites/icons/m-team.ico',
        'category': '影视',
      };
      final preset = SitePreset.fromJson(json);

      expect(preset.id, 'm-team');
      expect(preset.name, 'M-Team');
      expect(preset.baseUrl, 'https://m-team.cc');
      expect(preset.tags, ['电影', '综合']);
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
