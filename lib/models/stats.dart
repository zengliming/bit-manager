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
