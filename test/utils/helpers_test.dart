import 'package:bit_manager/utils/helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractSiteFromUrl', () {
    test('returns empty for null or empty url', () {
      expect(extractSiteFromUrl(null), '');
      expect(extractSiteFromUrl(''), '');
    });

    test('extracts registered domain body from compound TLD', () {
      // tracker 前缀被跳过，注册域名主体为 m-team
      expect(
        extractSiteFromUrl('https://tracker.m-team.cc/announce'),
        'm-team',
      );
    });

    test('skips cdn prefix', () {
      expect(extractSiteFromUrl('https://cdn.hdtime.org/announce'), 'hdtime');
    });

    test('returns IP address verbatim', () {
      expect(extractSiteFromUrl('https://192.168.1.1/announce'), '192.168.1.1');
    });

    test('skips single-letter subdomain prefix like t.ubits.club', () {
      // t 是子域名前缀，注册域名主体应为 ubits，而非 t
      expect(extractSiteFromUrl('https://t.ubits.club/announce'), 'ubits');
    });

    test('skips tr prefix', () {
      expect(extractSiteFromUrl('https://tr.example.com/announce'), 'example');
    });

    test('handles host without subdomain prefix', () {
      expect(extractSiteFromUrl('https://hdtime.org/announce'), 'hdtime');
    });
  });
}
