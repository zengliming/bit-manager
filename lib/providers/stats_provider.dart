import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../services/service_factory.dart';

class _ClientStatsRefreshResult {
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalDownloaded;
  final int totalUploaded;
  final int clientSize;
  final ClientStats clientStats;

  _ClientStatsRefreshResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalDownloaded,
    required this.totalUploaded,
    required this.clientSize,
    required this.clientStats,
  });
}

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
      // 并行获取所有客户端的统计信息
      final results = await Future.wait(activeClients.map((client) async {
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

        final totalDl = clientTorrents.fold<int>(0, (sum, t) => sum + t.downloaded);
        final totalUl = clientTorrents.fold<int>(0, (sum, t) => sum + t.uploaded);

        int downloading = 0, uploading = 0, seeding = 0, pausedUp = 0, pausedDl = 0, error = 0, checking = 0, waiting = 0;
        int seedsConnected = 0;
        for (final t in clientTorrents) {
          seedsConnected += t.seedsConnected;
          if (t.isActivelyDownloading) downloading++;
          if (t.isActivelyUploading) uploading++;
          if (t.isSeeding) seeding++;
          if (t.isPaused) {
            if (t.isComplete) {
              pausedUp++;
            } else {
              pausedDl++;
            }
          }
          if (t.isError) error++;
          if (t.isChecking) checking++;
          if (t.isWaiting) waiting++;
        }

        return _ClientStatsRefreshResult(
          downloadSpeed: clientDl,
          uploadSpeed: clientUl,
          totalDownloaded: totalDl,
          totalUploaded: totalUl,
          clientSize: clientSize,
          clientStats: ClientStats(
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
            uploadingCount: uploading,
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
          ),
        );
      }));

      // 汇总并行结果，同时累加全局计数（避免再次遍历 allTorrents）
      int downloadSpeed = 0;
      int uploadSpeed = 0;
      int totalDownloaded = 0;
      int totalUploaded = 0;
      int totalSize = 0;
      final clientStatsList = <ClientStats>[];
      int globalDownloading = 0, globalUploading = 0, globalSeeding = 0;
      int globalPaused = 0, globalError = 0, globalChecking = 0, globalWaiting = 0;
      for (final r in results) {
        downloadSpeed += r.downloadSpeed;
        uploadSpeed += r.uploadSpeed;
        totalDownloaded += r.totalDownloaded;
        totalUploaded += r.totalUploaded;
        totalSize += r.clientSize;
        final cs = r.clientStats;
        clientStatsList.add(cs);
        globalDownloading += cs.downloadingCount;
        globalUploading += cs.uploadingCount;
        globalSeeding += cs.seedingCount;
        globalPaused += cs.pausedUpCount + cs.pausedDlCount;
        globalError += cs.errorCount;
        globalChecking += cs.checkingCount;
        globalWaiting += cs.waitingCount;
      }

      _globalStats = GlobalStats(
        totalTorrents: allTorrents.length,
        activeTorrents: allTorrents.where((t) => t.isActive).length,
        downloadingCount: globalDownloading,
        uploadingCount: globalUploading,
        seedingCount: globalSeeding,
        pausedCount: globalPaused,
        errorCount: globalError,
        checkingCount: globalChecking,
        waitingCount: globalWaiting,
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
