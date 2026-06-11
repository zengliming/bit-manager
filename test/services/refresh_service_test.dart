import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/client_provider.dart';
import 'package:bit_manager/providers/stats_provider.dart';
import 'package:bit_manager/providers/torrent_provider.dart';
import 'package:bit_manager/services/refresh_service.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyTorrentService implements ITorrentClientService {
  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async => [];

  @override
  Future<bool> testConnection(ClientConfig config) async => true;

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

void main() {
  test(
    'keeps client online when torrent refresh succeeds with an empty list',
    () async {
      SharedPreferences.setMockInitialValues({});

      final clientProvider = ClientProvider();
      final torrentProvider = TorrentProvider(
        serviceResolver: (_) => _EmptyTorrentService(),
      );
      final statsProvider = StatsProvider();
      final refreshService = RefreshService(
        clientProvider: clientProvider,
        torrentProvider: torrentProvider,
        statsProvider: statsProvider,
      );

      await clientProvider.addClient(
        ClientConfig(
          id: 'qb',
          name: 'qBittorrent',
          type: ClientType.qBittorrent,
          host: '127.0.0.1',
          port: 8080,
        ),
      );

      await refreshService.refreshNow();

      expect(torrentProvider.allTorrents, isEmpty);
      expect(statsProvider.globalStats.clientStatsList, hasLength(1));
      expect(statsProvider.globalStats.clientStatsList.single.online, isTrue);
    },
  );
}
