import 'client_config.dart';

class GlobalStats {
  int totalTorrents;
  int activeTorrents;
  int downloadingCount;
  int seedingCount;
  int pausedCount;
  int errorCount;
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
    this.seedingCount = 0,
    this.pausedCount = 0,
    this.errorCount = 0,
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
  bool online;
  int torrentCount;
  int downloadSpeed;
  int uploadSpeed;
  int sizeOnDisk;

  ClientStats({
    required this.clientId,
    required this.clientName,
    required this.type,
    this.online = false,
    this.torrentCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.sizeOnDisk = 0,
  });
}
