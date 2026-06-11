import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/site_config.dart';
import '../services/site_service.dart';
import '../utils/storage.dart';

class SiteProvider extends ChangeNotifier {
  static const String _storageKey = 'sites';
  static const String _userInfoKey = 'site_user_info';

  List<SiteConfig> _sites = [];
  final Map<String, SiteUserInfo> _userInfo = {};
  final Map<String, String> _cookies = {};
  bool _loading = false;
  String _searchQuery = '';
  String? _tagFilter;

  final SiteService _siteService = SiteService();

  List<SiteConfig> get sites => List.unmodifiable(_sites);
  Map<String, SiteUserInfo> get userInfo => Map.unmodifiable(_userInfo);
  bool get loading => _loading;

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
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)))
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
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 持久化站点列表
  Future<void> _saveSites() async {
    final storage = await LocalStorage.getInstance();
    await storage.saveJsonList(
      _storageKey,
      _sites.map((s) => s.toJson()).toList(),
    );
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
      final config = SiteConfig(
        id: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        tags: List.from(preset.tags),
        sortOrder: _sites.isEmpty ? 1 : _sites.last.sortOrder + 1,
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
    final cookie = _cookies[siteId];

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
    }
  }
}
