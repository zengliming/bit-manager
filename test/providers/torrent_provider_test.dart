import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/torrent_provider.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTorrentService implements ITorrentClientService {
  final List<Torrent> torrents;
  final Object? error;

  _FakeTorrentService.success(this.torrents) : error = null;
  _FakeTorrentService.failure(this.error) : torrents = const [];

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final error = this.error;
    if (error != null) throw error;
    return torrents;
  }

  @override
  Future<bool> testConnection(ClientConfig config) async => error == null;

  @override
  Future<List<TorrentFile>> getTorrentFiles(
    ClientConfig config,
    String hash,
  ) async => [];

  @override
  Future<List<TrackerInfo>> getTrackers(
    ClientConfig config,
    String hash,
  ) async => [];

  @override
  Future<void> addTorrentFile(
    ClientConfig config, {
    required String filePath,
    String? savePath,
  }) async {}

  @override
  Future<void> addTorrentFromUrl(
    ClientConfig config, {
    required String url,
    String? savePath,
  }) async {}

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> deleteTorrent(
    ClientConfig config,
    String hash, {
    bool deleteFiles = false,
  }) async {}

  @override
  Future<void> replaceTracker(
    ClientConfig config,
    String hash,
    String oldUrl,
    String newUrl,
  ) async {}

  @override
  Future<void> addTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {}

  @override
  Future<void> removeTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {}

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async => false;

  @override
  Future<ClientStats> getStats(ClientConfig config) async => ClientStats(
    clientId: config.id,
    clientName: config.name,
    type: config.type,
    online: error == null,
  );

  @override
  Future<int> getFreeSpace(ClientConfig config) async => 0;

  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async => [0, 0];
}

void main() {
  ClientConfig client(String id) => ClientConfig(
    id: id,
    name: 'Client $id',
    type: ClientType.qBittorrent,
    host: '127.0.0.1',
    port: 8080,
  );

  test(
    'marks client online when torrent API succeeds with an empty list',
    () async {
      final provider = TorrentProvider(
        serviceResolver: (_) => _FakeTorrentService.success(const []),
      );
      final qb = client('qb');

      await provider.refreshTorrents([qb], showLoading: false);

      expect(provider.allTorrents, isEmpty);
      expect(provider.lastRefreshOnlineStatus[qb.id], isTrue);
    },
  );

  test('marks client offline when torrent API throws', () async {
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.failure(Exception('offline')),
    );
    final qb = client('qb');

    await provider.refreshTorrents([qb], showLoading: false);

    expect(provider.allTorrents, isEmpty);
    expect(provider.lastRefreshOnlineStatus[qb.id], isFalse);
  });
}
