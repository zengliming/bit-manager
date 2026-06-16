import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SiteService.messagePathFor', () {
    test('null schema 返回 NexusPHP 消息页', () {
      expect(SiteService.messagePathFor(null), '/messages.php');
    });

    test('NexusPHP schema 返回 /messages.php', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'NexusPHP')),
        '/messages.php',
      );
    });

    test('Gazelle schema 返回 /inbox.php', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'Gazelle')),
        '/inbox.php',
      );
    });

    test('未知 schema 回落到 NexusPHP', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'MagicSite')),
        '/messages.php',
      );
    });
  });

  group('SiteService.resolveIconAsset', () {
    test('已知 .ico 站点返回 .ico 路径', () async {
      // aither.ico 存在
      expect(
        await SiteService.resolveIconAsset('aither'),
        'assets/sites/icons/aither.ico',
      );
    });

    test('已知 .png 站点返回 .png 路径', () async {
      // agsvpt.png 存在
      expect(
        await SiteService.resolveIconAsset('agsvpt'),
        'assets/sites/icons/agsvpt.png',
      );
    });

    test('不存在的站点返回 null', () async {
      expect(
        await SiteService.resolveIconAsset('this-site-does-not-exist-xyz'),
        isNull,
      );
    });
  });
}
