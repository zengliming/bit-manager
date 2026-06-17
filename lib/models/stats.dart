import 'client_config.dart';

class GlobalStats {
  int totalTorrents;
  int activeTorrents;
  int downloadingCount;
  int uploadingCount;
  int seedingCount;
  int pausedCount;
  int errorCount;
  int checkingCount;
  int waitingCount;
  int downloadSpeed;
  int uploadSpeed;
  int totalDownloaded;
  int totalUploaded;
  int totalSizeOnDisk;
  List<ClientStats> clientStatsList;

  GlobalStats({
    this.totalTorrents = 0,
    this.activeTorrents = 0,
    this.downloadingCount = 0,
    this.uploadingCount = 0,
    this.seedingCount = 0,
    this.pausedCount = 0,
    this.errorCount = 0,
    this.checkingCount = 0,
    this.waitingCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalDownloaded = 0,
    this.totalUploaded = 0,
    this.totalSizeOnDisk = 0,
    this.clientStatsList = const [],
  });
}

class ClientStats {
  String clientId;
  String clientName;
  ClientType type;
  String host;
  int port;
  bool online;
  int torrentCount;
  int downloadSpeed;
  int uploadSpeed;
  int sizeOnDisk;

  // 各状态计数
  int downloadingCount;
  int uploadingCount;
  int seedingCount;
  int pausedUpCount;
  int pausedDlCount;
  int errorCount;
  int checkingCount;
  int waitingCount;

  // 做种连接数
  int seedsConnected;

  // 限速与空间
  int downloadLimit;
  int uploadLimit;
  int freeSpace;

  ClientStats({
    required this.clientId,
    required this.clientName,
    required this.type,
    this.host = '',
    this.port = 0,
    this.online = false,
    this.torrentCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.sizeOnDisk = 0,
    this.downloadingCount = 0,
    this.uploadingCount = 0,
    this.seedingCount = 0,
    this.pausedUpCount = 0,
    this.pausedDlCount = 0,
    this.errorCount = 0,
    this.checkingCount = 0,
    this.waitingCount = 0,
    this.seedsConnected = 0,
    this.downloadLimit = 0,
    this.uploadLimit = 0,
    this.freeSpace = 0,
  });
}

/// 站点统计汇总 — 聚合所有站点的 SiteUserInfo，零新增网络请求
class SiteStats {
  final int totalSites;
  final int activeSites;
  final int sitesWithCookie;
  final int totalUploaded;
  final int totalDownloaded;
  final int totalBonus;
  final int totalSeedingCount;
  final int totalSeedingSize;
  final int unreadTotal;
  final int hnrPreWarningTotal;
  final int hnrUnsatisfiedTotal;
  final DateTime? lastRefreshAt;

  SiteStats({
    required this.totalSites,
    required this.activeSites,
    required this.sitesWithCookie,
    required this.totalUploaded,
    required this.totalDownloaded,
    required this.totalBonus,
    required this.totalSeedingCount,
    required this.totalSeedingSize,
    required this.unreadTotal,
    required this.hnrPreWarningTotal,
    required this.hnrUnsatisfiedTotal,
    this.lastRefreshAt,
  });
}
