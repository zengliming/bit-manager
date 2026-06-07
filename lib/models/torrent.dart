import 'client_config.dart';

enum TorrentState {
  downloading,
  seeding,
  paused,
  checking,
  queued,
  error,
  metaDL,
  unknown,
}

class Torrent {
  final String id;
  final String hash;
  String name;
  final String clientId;
  final ClientType clientType;
  double progress;
  TorrentState state;
  int downloadSpeed;
  int uploadSpeed;
  int downloaded;
  int uploaded;
  int totalSize;
  double ratio;
  int peersConnected;
  int seedsConnected;
  int peersTotal;
  int seedsTotal;
  int eta;
  String? error;
  String? savePath;
  DateTime? addedAt;
  DateTime? completedAt;
  List<String> trackers;
  List<String> trackerStatuses;

  Torrent({
    required this.id,
    required this.hash,
    required this.name,
    required this.clientId,
    required this.clientType,
    this.progress = 0,
    this.state = TorrentState.unknown,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.downloaded = 0,
    this.uploaded = 0,
    this.totalSize = 0,
    this.ratio = 0,
    this.peersConnected = 0,
    this.seedsConnected = 0,
    this.peersTotal = 0,
    this.seedsTotal = 0,
    this.eta = 0,
    this.error,
    this.savePath,
    this.addedAt,
    this.completedAt,
    this.trackers = const [],
    this.trackerStatuses = const [],
  });

  bool get hasSuccessfulTracker {
    if (clientType == ClientType.qBittorrent) {
      return trackerStatuses.any((status) => status == '2');
    }
    return trackerStatuses.any((status) => status.contains('Success'));
  }
  bool get hasTrackerError => !hasSuccessfulTracker;
  bool get isActivelyUploading => uploadSpeed > 0;
  bool get isActivelyDownloading => downloadSpeed > 0;
  bool get isChecking => state == TorrentState.checking;
  bool get isWaiting => state == TorrentState.queued;

  bool get isDownloading => state == TorrentState.downloading || state == TorrentState.metaDL;
  bool get isSeeding => state == TorrentState.seeding;
  bool get isPaused => state == TorrentState.paused;
  bool get isComplete => progress >= 1.0;
  bool get isError => state == TorrentState.error || state == TorrentState.unknown || hasTrackerError;
  bool get isActive => isActivelyDownloading || isActivelyUploading || isChecking;
}
