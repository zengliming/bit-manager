import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/stats_provider.dart';
import 'package:bit_manager/services/service_factory.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStatsService implements ITorrentClientService {
  @override
  Future<bool> testConnection(ClientConfig config) async => true;

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async => [];

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
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes) async {}

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes) async {}

  @override
  Future<void> deleteTorrent(
    ClientConfig config,
    String hash, {
    bool deleteFiles = false,
  }) async {}

  @override
  Future<void> deleteTorrents(
    ClientConfig config,
    List<String> hashes, {
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
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {}

  @override
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {}

  @override
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  ) async {}

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async => false;

  @override
  Future<ClientStats> getStats(ClientConfig config) async => ClientStats(
    clientId: config.id,
    clientName: config.name,
    type: config.type,
    online: true,
  );

  @override
  Future<int> getFreeSpace(ClientConfig config) async => 0;

  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async => [0, 0];
}

ClientConfig _client(String id) => ClientConfig(
  id: id,
  name: 'Client $id',
  type: ClientType.qBittorrent,
  host: '127.0.0.1',
  port: 8080,
);

Torrent _torrent({
  required String clientId,
  int downloadSpeed = 0,
  int uploadSpeed = 0,
  int downloaded = 0,
  int uploaded = 0,
  int totalSize = 0,
}) => Torrent(
  id: '${clientId}-t',
  hash: 'abc${clientId}',
  name: 'Torrent $clientId',
  clientId: clientId,
  clientType: ClientType.qBittorrent,
  downloadSpeed: downloadSpeed,
  uploadSpeed: uploadSpeed,
  downloaded: downloaded,
  uploaded: uploaded,
  totalSize: totalSize,
);

void main() {
  setUp(() {
    ServiceFactory.reset();
    ServiceFactory.getService(ClientType.qBittorrent);
    ServiceFactory.getService(ClientType.transmission);
  });

  test('activeTorrents counts a torrent with both downloadSpeed>0 and'
      ' uploadSpeed>0 once after refreshStats', () async {
    final provider = StatsProvider();
    final client = _client('c1');
    final torrent = _torrent(
      clientId: client.id,
      downloadSpeed: 100,
      uploadSpeed: 50,
    );

    await provider.refreshStats([client], [torrent], {client.id: false});

    final stats = provider.globalStats;
    expect(stats.downloadingCount, 1);
    expect(stats.uploadingCount, 1);
    expect(
      stats.activeTorrents,
      1,
      reason:
          'activeTorrents should count the torrent once even though'
          ' it has both downloadSpeed>0 and uploadSpeed>0',
    );
  });

  test('refreshStats keeps totals and client stats after typed aggregation;'
      ' offline client one torrent', () async {
    final provider = StatsProvider();
    final client = _client('c1');
    final torrent = _torrent(
      clientId: client.id,
      downloadSpeed: 200,
      uploadSpeed: 100,
      downloaded: 5000,
      uploaded: 3000,
      totalSize: 8000,
    );

    await provider.refreshStats([client], [torrent], {client.id: false});

    final stats = provider.globalStats;
    // Client has torrents, so clientOnline becomes true.
    // The fake service.getStats returns 0 speeds, but
    // torrent-level totals (downloaded, uploaded, totalSize)
    // are accumulated from the torrent loop.
    expect(stats.downloadSpeed, 0);
    expect(stats.uploadSpeed, 0);
    expect(stats.totalDownloaded, torrent.downloaded);
    expect(stats.totalUploaded, torrent.uploaded);
    expect(stats.totalSizeOnDisk, torrent.totalSize);
    expect(stats.clientStatsList.length, 1);
    expect(stats.clientStatsList.single.clientId, client.id);
  });
}
