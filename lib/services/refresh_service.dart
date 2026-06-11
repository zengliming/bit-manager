import 'dart:async';
import '../providers/client_provider.dart';
import '../providers/torrent_provider.dart';
import '../providers/stats_provider.dart';
import '../utils/constants.dart';

class RefreshService {
  Timer? _pollTimer;
  final ClientProvider clientProvider;
  final TorrentProvider torrentProvider;
  final StatsProvider statsProvider;
  bool _isRunning = false;

  RefreshService({
    required this.clientProvider,
    required this.torrentProvider,
    required this.statsProvider,
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

    _pollAll();
  }

  /// 停止轮询
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 手动强制刷新全部
  Future<void> refreshNow() async {
    await _pollAll();
  }

  Future<void> _pollAll() async {
    final activeClients = clientProvider.activeClients;
    if (activeClients.isEmpty) return;

    await torrentProvider.refreshTorrents(activeClients, showLoading: false);
    await statsProvider.refreshStats(
      activeClients,
      torrentProvider.allTorrents,
      torrentProvider.lastRefreshOnlineStatus,
    );
  }
}
