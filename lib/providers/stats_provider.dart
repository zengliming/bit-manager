import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../services/service_factory.dart';

class StatsProvider extends ChangeNotifier {
  GlobalStats _globalStats = GlobalStats();
  bool _loading = false;
  String? _error;

  GlobalStats get globalStats => _globalStats;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> refreshStats(
    List<ClientConfig> activeClients,
    List<Torrent> allTorrents,
    Map<String, bool> onlineStatus,
  ) async {
    _loading = true;
    notifyListeners();

    try {
      int downloadSpeed = 0;
      int uploadSpeed = 0;
      int totalDownloaded = 0;
      int totalUploaded = 0;
      int totalSize = 0;
      final clientStatsList = <ClientStats>[];

      for (final client in activeClients) {
        final online = onlineStatus[client.id] ?? false;
        int clientDl = 0;
        int clientUl = 0;
        int clientSize = 0;

        if (online) {
          try {
            final service = ServiceFactory.getService(client.type);
            final stats = await service.getStats(client);
            clientDl = stats.downloadSpeed;
            clientUl = stats.uploadSpeed;
          } catch (_) {}
        }

        final clientTorrents = allTorrents.where((t) => t.clientId == client.id);
        for (final t in clientTorrents) {
          clientSize += t.totalSize;
          if (!online) {
            clientDl += t.downloadSpeed;
            clientUl += t.uploadSpeed;
          }
        }

        downloadSpeed += clientDl;
        uploadSpeed += clientUl;
        totalDownloaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.downloaded);
        totalUploaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.uploaded);
        totalSize += clientSize;

        clientStatsList.add(ClientStats(
          clientId: client.id,
          clientName: client.name,
          type: client.type,
          online: online,
          torrentCount: clientTorrents.length,
          downloadSpeed: clientDl,
          uploadSpeed: clientUl,
          sizeOnDisk: clientSize,
        ));
      }

      _globalStats = GlobalStats(
        totalTorrents: allTorrents.length,
        activeTorrents: allTorrents.where((t) => t.isActive).length,
        downloadingCount: allTorrents.where((t) => t.isDownloading).length,
        seedingCount: allTorrents.where((t) => t.isSeeding).length,
        pausedCount: allTorrents.where((t) => t.isPaused).length,
        errorCount: allTorrents.where((t) => t.isError).length,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        totalDownloaded: totalDownloaded,
        totalUploaded: totalUploaded,
        totalSizeOnDisk: totalSize,
        clientStatsList: clientStatsList,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
