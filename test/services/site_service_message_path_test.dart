import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
