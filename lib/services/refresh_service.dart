import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../providers/client_provider.dart';
import '../providers/site_provider.dart';
import '../providers/torrent_provider.dart';
import '../providers/stats_provider.dart';
import '../utils/constants.dart';
import '../utils/storage.dart';

class RefreshService {
  Timer? _pollTimer;
  Timer? _sitePollTimer;

  final ClientProvider clientProvider;
  final TorrentProvider torrentProvider;
  final StatsProvider statsProvider;
  final SiteProvider siteProvider;

  bool _isRunning = false;

  /// 上次站点刷新时间（内存镜像，与 SiteProvider.lastSiteRefreshAt 双向同步）
  DateTime? _lastSiteRefreshAt;

  /// 站点刷新间隔（小时）
  static const int sitePollIntervalHours = 2;

  /// 站点错开刷新间隔（每站之间）
  static const Duration siteStaggerDelay = Duration(seconds: 5);

  /// 持久化 key
  static const String _lastSiteRefreshKey = 'site_last_refresh_at';

  RefreshService({
    required this.clientProvider,
    required this.torrentProvider,
    required this.statsProvider,
    required this.siteProvider,
  });

  bool get isRunning => _isRunning;

  /// 启动轮询
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 种子客户端轮询
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.defaultPollIntervalSeconds),
      (_) => _pollAll(),
    );
    _pollAll();

    // 站点用户信息轮询（2h）
    _loadLastSiteRefreshAt().then((_) {
      _sitePollTimer = Timer.periodic(
        Duration(hours: sitePollIntervalHours),
        (_) => _maybeRefreshSites(),
      );
      // 启动时立即检查：若距上次超 2h 则刷新（覆盖"打开 app 超时自动刷新"）
      _maybeRefreshSites();
    });
  }

  /// 停止轮询
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _sitePollTimer?.cancel();
    _sitePollTimer = null;
  }

  /// 手动强制刷新全部（种子客户端）
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

  // ── 站点用户信息刷新 ──

  /// 从存储读取上次站点刷新时间
  Future<void> _loadLastSiteRefreshAt() async {
    try {
      final storage = await LocalStorage.getInstance();
      final raw = await storage.getString(_lastSiteRefreshKey);
      if (raw != null) {
        _lastSiteRefreshAt = DateTime.tryParse(raw);
      }
    } catch (_) {
      _lastSiteRefreshAt = null;
    }
  }

  /// 持久化上次站点刷新时间
  Future<void> _persistLastSiteRefreshAt() async {
    try {
      final storage = await LocalStorage.getInstance();
      if (_lastSiteRefreshAt != null) {
        await storage.setString(
          _lastSiteRefreshKey,
          _lastSiteRefreshAt!.toIso8601String(),
        );
      }
    } catch (_) {
      // 持久化失败仅影响下次超时判断精度，忽略
    }
  }

  /// 判断是否需要刷新站点信息（距上次超 2h 或从未刷新）
  ///
  /// 先从 siteProvider.lastSiteRefreshAt 同步最新值（手动刷新可能已更新）。
  @visibleForTesting
  Future<void> maybeRefreshSitesForTest() async {
    await _loadLastSiteRefreshAt();
    await _maybeRefreshSites();
  }

  @visibleForTesting
  DateTime? get lastSiteRefreshAtForTest => _lastSiteRefreshAt;

  Future<void> _maybeRefreshSites() async {
    // 同步 SiteProvider 端可能更新的时间（手动刷新路径）
    if (siteProvider.lastSiteRefreshAt != null) {
      if (_lastSiteRefreshAt == null ||
          siteProvider.lastSiteRefreshAt!.isAfter(_lastSiteRefreshAt!)) {
        _lastSiteRefreshAt = siteProvider.lastSiteRefreshAt;
      }
    }

    final now = DateTime.now();
    final shouldRefresh = _lastSiteRefreshAt == null ||
        now.difference(_lastSiteRefreshAt!) >=
            const Duration(hours: sitePollIntervalHours);
    if (!shouldRefresh) return;

    await _refreshSitesStaggered();
  }

  /// 顺序错开刷新所有有 Cookie 的活跃私有站点
  ///
  /// 并发 1，每站间隔 siteStaggerDelay，避免集中请求冲击站点。
  /// 即使 targets 为空也标记时间，表示已尝试刷新（避免重复触发）。
  Future<void> _refreshSitesStaggered() async {
    final targets = siteProvider.sites
        .where(
            (s) => s.isActive && !s.isPublicSite && siteProvider.hasCookie(s.id))
        .map((s) => s.id)
        .toList();

    final now = DateTime.now();
    _lastSiteRefreshAt = now;
    siteProvider.markSiteRefreshed(now);
    await _persistLastSiteRefreshAt();

    for (final siteId in targets) {
      await siteProvider.fetchUserInfo(siteId);
      await Future.delayed(siteStaggerDelay);
    }
  }
}
