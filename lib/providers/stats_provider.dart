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
        final clientTorrents = allTorrents.where((t) => t.clientId == client.id);
        // 客户端在线状态：主动测试结果 或 能获取到种子（说明连通）
        final clientOnline = (onlineStatus[client.id] ?? false) || clientTorrents.isNotEmpty;
        int clientDl = 0;
        int clientUl = 0;
        int clientSize = 0;

        if (clientOnline) {
          try {
            final service = ServiceFactory.getService(client.type);
            final s = await service.getStats(client);
            clientDl = s.downloadSpeed;
            clientUl = s.uploadSpeed;
          } catch (_) {}
        }

        for (final t in clientTorrents) {
          clientSize += t.totalSize;
          if (!clientOnline) {
            clientDl += t.downloadSpeed;
            clientUl += t.uploadSpeed;
          }
        }

        int freeSpace = 0, dllimit = 0, ullimit = 0;
        if (clientOnline) {
          try {
            final service = ServiceFactory.getService(client.type);
            freeSpace = await service.getFreeSpace(client);
            final limits = await service.getSpeedLimits(client);
            if (limits.length >= 2) {
              dllimit = limits[0];
              ullimit = limits[1];
            }
          } catch (_) {}
        }

        downloadSpeed += clientDl;
        uploadSpeed += clientUl;
        totalDownloaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.downloaded);
        totalUploaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.uploaded);
        totalSize += clientSize;

        int downloading = 0, seeding = 0, pausedUp = 0, pausedDl = 0, error = 0, checking = 0, waiting = 0;
        int seedsConnected = 0;
        for (final t in clientTorrents) {
          seedsConnected += t.seedsConnected;
          if (t.state == TorrentState.downloading || t.state == TorrentState.metaDL) {
            downloading++;
          } else if (t.state == TorrentState.seeding) {
            seeding++;
          } else if (t.state == TorrentState.paused) {
            if (t.progress >= 1.0) {
              pausedUp++;
            } else {
              pausedDl++;
            }
          } else if (t.state == TorrentState.error) {
            error++;
          } else if (t.state == TorrentState.checking) {
            checking++;
          } else if (t.state == TorrentState.queued) {
            waiting++;
          }
        }

        clientStatsList.add(ClientStats(
          clientId: client.id,
          clientName: client.name,
          type: client.type,
          host: client.host,
          port: client.port,
          online: clientOnline,
          torrentCount: clientTorrents.length,
          downloadSpeed: clientDl,
          uploadSpeed: clientUl,
          sizeOnDisk: clientSize,
          downloadingCount: downloading,
          seedingCount: seeding,
          pausedUpCount: pausedUp,
          pausedDlCount: pausedDl,
          errorCount: error,
          checkingCount: checking,
          waitingCount: waiting,
          seedsConnected: seedsConnected,
          freeSpace: freeSpace,
          downloadLimit: dllimit,
          uploadLimit: ullimit,
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
