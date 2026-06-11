import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fetchUserInfo', () {
    test('返回 null（cookie 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://example.com',
      );
      final result = await service.fetchUserInfo(config, null);
      expect(result, isNull);
    });

    test('返回 null（baseUrl 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(id: 'test', name: 'Test');
      final result = await service.fetchUserInfo(config, 'uid=123');
      expect(result, isNull);
    });
  });

  group('parseSize', () {
    test('解析 "1.23 TB"', () {
      expect(SiteService.parseSize('1.23 TB'), closeTo(1230000000000, 1));
    });

    test('解析 "500 GB"', () {
      expect(SiteService.parseSize('500 GB'), closeTo(500000000000, 1));
    });

    test('解析 "100 MB"', () {
      expect(SiteService.parseSize('100 MB'), closeTo(100000000, 1));
    });

    test('解析 "50 KB"', () {
      expect(SiteService.parseSize('50 KB'), 50000);
    });

    test('解析纯数字', () {
      expect(SiteService.parseSize('12345'), 12345);
    });

    test('解析空字符串', () {
      expect(SiteService.parseSize(''), isNull);
      expect(SiteService.parseSize(null), isNull);
    });
  });

  group('parseRatio', () {
    test('解析 "2.5"', () {
      expect(SiteService.parseRatio('2.5'), closeTo(2.5, 0.01));
    });

    test('解析 "∞" 或 "Inf."', () {
      expect(SiteService.parseRatio('∞'), double.infinity);
      expect(SiteService.parseRatio('Inf.'), double.infinity);
    });

    test('解析空字符串', () {
      expect(SiteService.parseRatio(''), isNull);
    });
  });
}
