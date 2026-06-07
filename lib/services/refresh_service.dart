import 'dart:async';
import '../providers/client_provider.dart';
import '../providers/torrent_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/rss_provider.dart';
import '../utils/constants.dart';

class RefreshService {
  Timer? _pollTimer;
  Timer? _rssTimer;
  final ClientProvider clientProvider;
  final TorrentProvider torrentProvider;
  final StatsProvider statsProvider;
  final RssProvider rssProvider;
  bool _isRunning = false;

  RefreshService({
    required this.clientProvider,
    required this.torrentProvider,
    required this.statsProvider,
    required this.rssProvider,
  });

  bool get isRunning => _isRunning;

  /// 启动轮询
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.defaultPollIntervalSeconds),
      (_) => _pollAll(),
    );

    _rssTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkRssRefresh(),
    );

    _pollAll();
    _checkRssRefresh();
  }

  /// 停止轮询
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _rssTimer?.cancel();
    _rssTimer = null;
  }

  /// 手动强制刷新全部
  Future<void> refreshNow() async {
    await _pollAll();
    await _checkRssRefresh();
  }

  Future<void> _pollAll() async {
    final activeClients = clientProvider.activeClients;
    if (activeClients.isEmpty) return;

    await torrentProvider.refreshTorrents(activeClients);
    await statsProvider.refreshStats(
      activeClients,
      torrentProvider.allTorrents,
      clientProvider.onlineStatus,
    );
  }

  Future<void> _checkRssRefresh() async {
    final now = DateTime.now();
    for (final source in rssProvider.sources) {
      if (!source.autoDownload) continue;
      final lastFetched = source.lastFetchedAt;
      if (lastFetched != null) {
        final diff = now.difference(lastFetched).inMinutes;
        if (diff < source.refreshIntervalMinutes) continue;
      }
      await rssProvider.processAutoDownloads(clientProvider.activeClients);
    }
  }
}
