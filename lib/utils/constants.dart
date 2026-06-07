class AppConstants {
  static const String appName = 'Bit Manager';

  // 默认刷新间隔
  static const int defaultPollIntervalSeconds = 3;
  static const int defaultRssRefreshMinutes = 15;
  static const int defaultTimeoutSeconds = 10;
  static const int maxRetryCount = 3;

  // 存储 Key
  static const String storageKeyClients = 'clients';
  static const String storageKeyRssSources = 'rss_sources';
  static const String storageKeyRssDownloaded = 'rss_downloaded_guids';
  static const String storageKeyThemeMode = 'theme_mode';
  static const String storageKeyPollInterval = 'poll_interval';

  // qBittorrent API 路径
  static const String qbLogin = '/api/v2/auth/login';
  static const String qbTorrents = '/api/v2/torrents/info';
  static const String qbTorrentAdd = '/api/v2/torrents/add';
  static const String qbTorrentDelete = '/api/v2/torrents/delete';
  static const String qbTorrentPause = '/api/v2/torrents/pause';
  static const String qbTorrentResume = '/api/v2/torrents/resume';
  static const String qbTorrentTrackers = '/api/v2/torrents/trackers';
  static const String qbTransferInfo = '/api/v2/transfer/info';

  // Transmission RPC 路径
  static const String trRpc = '/transmission/rpc';
}
