import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/services/qbittorrent_service.dart';
import 'package:flutter_test/flutter_test.dart';

ClientConfig _qb() => ClientConfig(
      id: 'qb',
      name: 'QB',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
      username: 'u',
      password: 'p',
    );

void main() {
  // 项目未引入 mock 库，service 内部自建 dio 难注入 adapter；
  // 请求形态的正确性由 provider 层 fake 覆盖（见 torrent_provider_test）。
  // 此处仅验证空输入静默返回、不抛错、签名正确。
  group('QBittorrentService 批量 Tracker 空输入', () {
    final svc = QBittorrentService();

    test('addTrackers 空 hashes 静默返回', () async {
      await svc.addTrackers(_qb(), const [], const ['http://t/announce']);
    });

    test('addTrackers 空 urls 静默返回', () async {
      await svc.addTrackers(_qb(), const ['aaa'], const []);
    });

    test('replaceTrackers 空 hashes 静默返回', () async {
      await svc.replaceTrackers(_qb(), const [], 'http://old/', 'http://new/');
    });

    test('removeTrackers 空 hashes 静默返回', () async {
      await svc.removeTrackers(_qb(), const [], 'http://t/announce');
    });
  });
}
