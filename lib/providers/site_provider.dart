import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/site_config.dart';
import '../models/stats.dart' show SiteStats;
import '../services/site_service.dart';
import '../utils/storage.dart';

class SiteProvider extends ChangeNotifier {
  static const String _storageKey = 'sites';
  static const String _userInfoKey = 'site_user_info';

  List<SiteConfig> _sites = [];
  final Map<String, SiteUserInfo> _userInfo = {};
  final Map<String, String> _cookies = {};
  final Set<String> _refreshing = {};
  bool _loading = false;
  bool _refreshingAll = false;
  String _searchQuery = '';
  String? _tagFilter;

  final SiteService _siteService = SiteService();

  List<SiteConfig> get sites => List.unmodifiable(_sites);
  Map<String, SiteUserInfo> get userInfo => Map.unmodifiable(_userInfo);
  bool get loading => _loading;
  bool get refreshingAll => _refreshingAll;

  /// 是否正在刷新指定站点的用户信息
  bool isRefreshing(String siteId) => _refreshing.contains(siteId);

  String get searchQuery => _searchQuery;
  set searchQuery(String v) {
    if (_searchQuery != v) {
      _searchQuery = v;
      notifyListeners();
    }
  }

  String? get tagFilter => _tagFilter;
  set tagFilter(String? v) {
    if (_tagFilter != v) {
      _tagFilter = v;
      notifyListeners();
    }
  }

  List<SiteConfig> get filteredSites {
    var result = _sites;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                s.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    if (_tagFilter != null && _tagFilter!.isNotEmpty) {
      result = result.where((s) => s.tags.contains(_tagFilter!)).toList();
    }
    return result;
  }

  Set<String> get allTags {
    final tags = <String>{};
    for (final site in _sites) {
      tags.addAll(site.tags);
    }
    return tags;
  }

  /// 从本地存储加载站点配置、Cookie 和用户信息
  Future<void> loadSites() async {
    _loading = true;
    notifyListeners();

    try {
      final storage = await LocalStorage.getInstance();

      final rawList = await storage.getJsonList(_storageKey);
      _sites = rawList.map((json) => SiteConfig.fromJson(json)).toList();

      // 旧版持久化数据可能没有 iconAsset — 用 rootBundle probe 兜底
      // （新版 importPresets 会直接复制 preset.iconAsset，不需要 probe）
      await _backfillIconAssets();

      for (final site in _sites) {
        final cookie = await storage.getString('cookie_${site.id}');
        if (cookie != null && cookie.isNotEmpty) {
          _cookies[site.id] = cookie;
        }
      }

      final uiRaw = await storage.getString(_userInfoKey);
      if (uiRaw != null) {
        final map = jsonDecode(uiRaw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final infoMap = entry.value as Map<String, dynamic>;
          _userInfo[entry.key] = SiteUserInfo.fromJson(infoMap);
        }
      }

      // 启动时自动用 preset 补齐缺失的 parseSchema
      // （场景：preset 后来加了字段，或用户先添加了同 id 站点）
      try {
        final presets = await _loadBundledPresets();
        if (presets.isNotEmpty) {
          await syncParseSchemaFromPresets(presets);
        }
      } catch (_) {
        // 加载预设失败不影响主流程
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 从 assets 加载内置站点预设
  Future<List<SitePreset>> _loadBundledPresets() async {
    final jsonStr = await rootBundle.loadString('assets/sites/presets.json');
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((j) => SitePreset.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// 用 rootBundle 探测每个站点的真实图标路径，填回 site.iconAsset
  ///
  /// 用途：老数据没存 iconAsset；新版 importPresets 已经处理，不需要 probe。
  /// probe 一次后写回存储，避免每次启动重做。
  Future<void> _backfillIconAssets() async {
    bool changed = false;
    for (final site in _sites) {
      if (site.iconAsset != null && site.iconAsset!.isNotEmpty) continue;
      final resolved = await SiteService.resolveIconAsset(site.id);
      if (resolved != null) {
        site.iconAsset = resolved;
        changed = true;
      }
    }
    if (changed) await _saveSites();
  }

  /// 持久化站点列表
  Future<void> _saveSites() async {
    final storage = await LocalStorage.getInstance();
    await storage.saveJsonList(
      _storageKey,
      _sites.map((s) => s.toJson()).toList(),
    );
  }

  /// 用 preset 列表补齐已有站点缺失的 parseSchema
  ///
  /// 场景：用户先导入了预设、之后预设新增了 parseSchema（比如我们补了 13city/cspt
  /// 的 bonusLabels）；或者用户手动添加了 id 与某个预设相同的站点（importPresets
  /// 会跳过已存在的 id，导致 parseSchema 不会被复制过来）。
  ///
  /// 只在 site.parseSchema 为 null 时复制；保留用户在站点表单里的自定义。
  Future<int> syncParseSchemaFromPresets(List<SitePreset> presets) async {
    final byId = {for (final p in presets) p.id: p};
    int updated = 0;
    for (final site in _sites) {
      if (site.parseSchema != null) continue;
      final preset = byId[site.id];
      if (preset?.parseSchema == null) continue;
      site.parseSchema = preset!.parseSchema;
      updated++;
    }
    if (updated > 0) {
      await _saveSites();
      notifyListeners();
    }
    return updated;
  }

  /// 持久化用户信息
  Future<void> _saveUserInfo() async {
    final storage = await LocalStorage.getInstance();
    final map = <String, dynamic>{};
    for (final entry in _userInfo.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await storage.setString(_userInfoKey, jsonEncode(map));
  }

  /// 添加站点，重复 id 则忽略
  Future<void> addSite(SiteConfig config) async {
    if (_sites.any((s) => s.id == config.id)) return;
    config.sortOrder = _sites.isEmpty ? 1 : _sites.last.sortOrder + 1;
    _sites.add(config);
    await _saveSites();
    notifyListeners();
  }

  /// 更新站点
  Future<void> updateSite(String id, SiteConfig updated) async {
    final index = _sites.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sites[index] = updated;
      await _saveSites();
      notifyListeners();
    }
  }

  /// 删除站点及其关联的 Cookie 和用户信息
  Future<void> deleteSite(String id) async {
    _sites.removeWhere((s) => s.id == id);
    _cookies.remove(id);
    _userInfo.remove(id);
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$id', '');
    await _saveSites();
    await _saveUserInfo();
    notifyListeners();
  }

  /// 批量导入预设，跳过已存在的站点
  Future<int> importPresets(List<SitePreset> presets) async {
    int count = 0;
    for (final preset in presets) {
      if (_sites.any((s) => s.id == preset.id)) continue;
      // 把 preset.schema 合并进 parseSchema（保留原有 fields/*Labels）
      SiteParseSchema? schema = preset.parseSchema;
      if (preset.schema != null) {
        schema = (schema ?? const SiteParseSchema()).copyWith(
          schema: preset.schema,
        );
      }
      // 优先用 rootBundle 探测真实文件路径，不信任 preset.iconAsset
      // （presets.json 里 71/287 是 null，且偶尔有写错扩展名的情况）
      final iconAsset =
          await SiteService.resolveIconAsset(preset.id) ?? preset.iconAsset;
      final config = SiteConfig(
        id: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        tags: List.from(preset.tags),
        sortOrder: _sites.isEmpty ? 1 : _sites.last.sortOrder + 1,
        iconAsset: iconAsset,
        type: preset.type,
        parseSchema: schema,
      );
      _sites.add(config);
      count++;
    }
    if (count > 0) {
      await _saveSites();
      notifyListeners();
    }
    return count;
  }

  /// 检查站点 id 是否已导入
  bool isSiteImported(String siteId) => _sites.any((s) => s.id == siteId);

  // ── Cookie 管理 ──

  /// 保存 cookie
  Future<void> saveCookie(String siteId, String cookie) async {
    _cookies[siteId] = cookie;
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$siteId', cookie);
    notifyListeners();
  }

  /// 获取 cookie 字符串
  String? getCookieString(String siteId) => _cookies[siteId];

  /// 检查是否有 cookie
  bool hasCookie(String siteId) {
    final c = _cookies[siteId];
    return c != null && c.isNotEmpty;
  }

  /// 删除 cookie
  Future<void> deleteCookie(String siteId) async {
    _cookies.remove(siteId);
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$siteId', '');
    notifyListeners();
  }

  // ── 用户信息 ──

  /// 所有站点未读消息总数（仅统计 messageCount > 0 的）
  int get unreadTotal {
    var sum = 0;
    for (final info in _userInfo.values) {
      final n = info.messageCount;
      if (n != null && n > 0) sum += n;
    }
    return sum;
  }

  /// 上次站点刷新时间（手动刷新与自动刷新都更新，用于跨组件同步）
  DateTime? _lastSiteRefreshAt;
  DateTime? get lastSiteRefreshAt => _lastSiteRefreshAt;

  /// 标记站点刷新完成时间（由 RefreshService 与 refreshAllUserInfo 调用）
  void markSiteRefreshed(DateTime time) {
    if (_lastSiteRefreshAt == null || time.isAfter(_lastSiteRefreshAt!)) {
      _lastSiteRefreshAt = time;
    }
  }

  /// 全站统计汇总 — 聚合已有 SiteUserInfo，零新增网络请求
  ///
  /// 数值字段遍历 _userInfo.values，跳过 fetchFailed 与 null；公开站点天然
  /// 不在 _userInfo 中，自动跳过。lastRefreshAt 取所有 lastFetchedAt 最大值。
  SiteStats get siteStats {
    int totalUploaded = 0;
    int totalDownloaded = 0;
    int totalBonus = 0;
    int totalSeedingCount = 0;
    int totalSeedingSize = 0;
    int hnrPreWarningTotal = 0;
    int hnrUnsatisfiedTotal = 0;
    DateTime? lastRefreshAt;

    for (final info in _userInfo.values) {
      if (info.fetchFailed) continue;
      if (info.uploaded != null) totalUploaded += info.uploaded!;
      if (info.downloaded != null) totalDownloaded += info.downloaded!;
      if (info.bonusPoints != null) totalBonus += info.bonusPoints!;
      if (info.seedingCount != null) totalSeedingCount += info.seedingCount!;
      if (info.seedingSize != null) totalSeedingSize += info.seedingSize!;
      if (info.hnrPreWarning != null) hnrPreWarningTotal += info.hnrPreWarning!;
      if (info.hnrUnsatisfied != null) {
        hnrUnsatisfiedTotal += info.hnrUnsatisfied!;
      }
      if (info.lastFetchedAt != null) {
        if (lastRefreshAt == null ||
            info.lastFetchedAt!.isAfter(lastRefreshAt)) {
          lastRefreshAt = info.lastFetchedAt;
        }
      }
    }

    return SiteStats(
      totalSites: _sites.length,
      activeSites: _sites.where((s) => s.isActive).length,
      sitesWithCookie: _sites
          .where((s) => s.isActive && !s.isPublicSite && hasCookie(s.id))
          .length,
      totalUploaded: totalUploaded,
      totalDownloaded: totalDownloaded,
      totalBonus: totalBonus,
      totalSeedingCount: totalSeedingCount,
      totalSeedingSize: totalSeedingSize,
      unreadTotal: unreadTotal,
      hnrPreWarningTotal: hnrPreWarningTotal,
      hnrUnsatisfiedTotal: hnrUnsatisfiedTotal,
      lastRefreshAt: lastRefreshAt,
    );
  }

  /// 获取站点用户信息
  SiteUserInfo? getUserInfo(String siteId) => _userInfo[siteId];

  /// 更新用户信息
  Future<void> updateUserInfo(SiteUserInfo info) async {
    _userInfo[info.siteId] = info;
    await _saveUserInfo();
    notifyListeners();
  }

  /// 抓取站点用户信息
  Future<bool> fetchUserInfo(String siteId) async {
    final idx = _sites.indexWhere((s) => s.id == siteId);
    if (idx == -1) throw StateError('Site $siteId not found');
    final site = _sites[idx];

    // 公开站点没有用户账户 / 分享率等概念，直接跳过（不污染 fetchFailed）
    if (site.isPublicSite) {
      return false;
    }

    final cookie = _cookies[siteId];

    _refreshing.add(siteId);
    notifyListeners();

    try {
      final info = await _siteService.fetchUserInfo(site, cookie);
      if (info != null) {
        await updateUserInfo(info);
        return true;
      }
      final failedInfo = SiteUserInfo(
        siteId: siteId,
        fetchFailed: true,
        lastFetchedAt: DateTime.now(),
      );
      await updateUserInfo(failedInfo);
      return false;
    } catch (_) {
      final failedInfo = SiteUserInfo(
        siteId: siteId,
        fetchFailed: true,
        lastFetchedAt: DateTime.now(),
      );
      await updateUserInfo(failedInfo);
      return false;
    } finally {
      _refreshing.remove(siteId);
      notifyListeners();
    }
  }

  /// 批量刷新所有有 Cookie 的站点用户信息（最多 3 并发）
  /// 返回 (成功数, 失败数)。public 站点会被跳过，不计入两者。
  Future<(int, int)> refreshAllUserInfo() async {
    final targets = _sites
        .where((s) => s.isActive && !s.isPublicSite && hasCookie(s.id))
        .map((s) => s.id)
        .toList();
    if (targets.isEmpty) return (0, 0);

    _refreshingAll = true;
    notifyListeners();

    int success = 0;
    int failed = 0;
    const concurrency = 3;
    try {
      for (var i = 0; i < targets.length; i += concurrency) {
        final batch = targets.skip(i).take(concurrency);
        final results = await Future.wait(batch.map(fetchUserInfo));
        for (final ok in results) {
          if (ok) {
            success++;
          } else {
            failed++;
          }
        }
      }
      // 真正执行刷新后才标记时间，与 RefreshService 同步
      if (targets.isNotEmpty) {
        markSiteRefreshed(DateTime.now());
      }
    } finally {
      _refreshingAll = false;
      notifyListeners();
    }
    return (success, failed);
  }
}
