import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../services/service_factory.dart';
import '../services/torrent_client.dart';

typedef TorrentServiceResolver =
    ITorrentClientService Function(ClientType type);

/// 排序字段
enum TorrentSortField {
  addedAt,
  downloadSpeed,
  uploadSpeed,
  ratio,
  uploaded,
  downloaded,
  totalSize,
  progress,
  eta,
  lastActivity,
  seedsConnected,
  leechers,
  multiSource,
}

class TorrentProvider extends ChangeNotifier {
  final TorrentServiceResolver _serviceResolver;
  List<Torrent> _allTorrents = [];
  final Map<String, bool> _lastRefreshOnlineStatus = {};
  String _searchQuery = '';
  Set<TorrentState>? _stateFilter;
  String? _clientFilter;
  bool _errorOnly = false;
  String? _errorFilter;
  String? _siteFilter;
  bool _loading = false;
  String? _error;
  bool _selectMode = false;
  final Set<String> _selectedHashes = {};
  int _stateTabIndex = 0;

  /// 排序
  TorrentSortField _sortField = TorrentSortField.addedAt;
  bool _sortAsc = false;

  /// 缓存的错误种子计数，避免每次 UI 重建时 O(n) 遍历
  int _errorCount = 0;

  /// 缓存的异常原因统计（按数量降序），避免每次 UI 重建时 O(n log n) 重建
  List<MapEntry<String, int>> _errorReasonsCache = const [];

  /// 搜索防抖定时器：用户停止输入 200ms 后才触发筛选
  Timer? _searchDebounce;

  TorrentProvider({TorrentServiceResolver? serviceResolver})
    : _serviceResolver = serviceResolver ?? ServiceFactory.getService;

  List<Torrent> get allTorrents => List.unmodifiable(_allTorrents);

  TorrentSortField get sortField => _sortField;
  bool get sortAsc => _sortAsc;

  void setSortField(TorrentSortField field) {
    if (_sortField == field) {
      _sortAsc = !_sortAsc;
    } else {
      _sortField = field;
      _sortAsc = false;
    }
    notifyListeners();
  }

  int _sortValue(Torrent t, TorrentSortField field) {
    return switch (field) {
      TorrentSortField.addedAt => t.addedAt?.millisecondsSinceEpoch ?? 0,
      TorrentSortField.downloadSpeed => t.downloadSpeed,
      TorrentSortField.uploadSpeed => t.uploadSpeed,
      TorrentSortField.ratio => (t.ratio * 1000000).round(),
      TorrentSortField.uploaded => t.uploaded,
      TorrentSortField.downloaded => t.downloaded,
      TorrentSortField.totalSize => t.totalSize,
      TorrentSortField.progress => (t.progress * 1000000).round(),
      TorrentSortField.eta => t.eta,
      TorrentSortField.lastActivity => t.lastActivity?.millisecondsSinceEpoch ?? 0,
      TorrentSortField.seedsConnected => t.seedsConnected,
      TorrentSortField.leechers => t.leechers,
      TorrentSortField.multiSource => t.multiSource,
    };
  }

  /// 单次遍历过滤：所有筛选条件在一次迭代中完成，避免链式 .where().toList() 创建多个中间列表
  List<Torrent> get filteredTorrents {
    var result = _allTorrents.where((t) {
      if (_stateFilter != null &&
          _stateFilter!.isNotEmpty &&
          !_stateFilter!.contains(t.state))
        return false;
      if (_clientFilter != null && t.clientId != _clientFilter) return false;
      if (_errorOnly && !t.isError) return false;
      if (_errorFilter != null && t.error != _errorFilter) return false;
      if (_siteFilter != null &&
          _siteFilter!.isNotEmpty &&
          !t.trackers.any((tr) => tr.contains(_siteFilter!)))
        return false;
      if (_searchQuery.isNotEmpty &&
          !t.name.toLowerCase().contains(_searchQueryLowerCase))
        return false;
      return true;
    }).toList();

    result.sort((a, b) {
      final va = _sortValue(a, _sortField);
      final vb = _sortValue(b, _sortField);
      return _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
    });

    return result;
  }

  /// 缓存的搜索查询小写，避免每次筛选时重复转换
  String _searchQueryLowerCase = '';

  String get searchQuery => _searchQuery;
  Set<TorrentState>? get stateFilter => _stateFilter;
  int get stateTabIndex => _stateTabIndex;
  String? get clientFilter => _clientFilter;
  bool get errorOnly => _errorOnly;
  String? get errorFilter => _errorFilter;
  String? get siteFilter => _siteFilter;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, bool> get lastRefreshOnlineStatus =>
      Map.unmodifiable(_lastRefreshOnlineStatus);
  bool get selectMode => _selectMode;
  Set<String> get selectedHashes => Set.unmodifiable(_selectedHashes);
  int get selectedCount => _selectedHashes.length;

  int get activeFilterCount => [
    if (_stateFilter != null && _stateFilter!.isNotEmpty) 1,
    if (_clientFilter != null) 1,
    if (_errorOnly) 1,
    if (_errorFilter != null) 1,
    if (_siteFilter != null) 1,
  ].length;

  int get errorCount => _errorCount;

  /// 按异常原因聚合计数，供筛选面板展示
  /// 仅返回有异常原因的种子，按数量降序排列
  List<MapEntry<String, int>> get errorReasons => _errorReasonsCache;

  // ---- 筛选 ----

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _searchQueryLowerCase = query.toLowerCase();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      notifyListeners();
    });
  }

  void setStateFilter(Set<TorrentState>? states) {
    // 比较集合内容而非引用，避免不同 Set 实例但内容相同导致的不必要通知
    if (_stateFilter == states) return;
    if (_stateFilter != null &&
        states != null &&
        _stateFilter!.length == states.length) {
      if (states.every((s) => _stateFilter!.contains(s))) {
        return;
      }
    }
    _stateFilter = states;
    notifyListeners();
  }

  void setStateTabIndex(int index) {
    if (_stateTabIndex == index) return;
    _stateTabIndex = index;
    switch (index) {
      case 0:
        _stateFilter = null;
        _errorOnly = false;
        break;
      case 1:
        _stateFilter = {TorrentState.downloading, TorrentState.metaDL};
        _errorOnly = false;
        break;
      case 2:
        _stateFilter = null;
        _errorOnly = true;
        break;
      case 3:
        _stateFilter = {TorrentState.seeding};
        _errorOnly = false;
        break;
      default:
        _stateFilter = null;
    }
    notifyListeners();
  }

  void setClientFilter(String? clientId) {
    if (_clientFilter == clientId) return;
    _clientFilter = clientId;
    notifyListeners();
  }

  void setErrorOnly(bool v) {
    if (_errorOnly == v) return;
    _errorOnly = v;
    notifyListeners();
  }

  void setErrorFilter(String? errorMsg) {
    if (_errorFilter == errorMsg) return;
    _errorFilter = errorMsg;
    notifyListeners();
  }

  void setSiteFilter(String? site) {
    if (_siteFilter == site) return;
    _siteFilter = site;
    notifyListeners();
  }

  void clearAllFilters() {
    _stateFilter = null;
    _stateTabIndex = 0;
    _clientFilter = null;
    _errorOnly = false;
    _errorFilter = null;
    _siteFilter = null;
    _searchQuery = '';
    _searchQueryLowerCase = '';
    _sortField = TorrentSortField.addedAt;
    _sortAsc = false;
    notifyListeners();
  }

  // ---- 批量选择模式 ----

  void enterSelectMode() {
    _selectMode = true;
    notifyListeners();
  }

  void exitSelectMode() {
    _selectMode = false;
    _selectedHashes.clear();
    notifyListeners();
  }

  void toggleSelection(String hash) {
    if (_selectedHashes.contains(hash)) {
      _selectedHashes.remove(hash);
    } else {
      _selectedHashes.add(hash);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedHashes.addAll(filteredTorrents.map((t) => t.hash));
    notifyListeners();
  }

  void clearSelection() {
    _selectedHashes.clear();
    notifyListeners();
  }

  // ---- 数据刷新 ----

  Future<void> refreshTorrents(
    List<ClientConfig> activeClients, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final allTorrents = <Torrent>[];
      final onlineStatus = <String, bool>{};
      await Future.wait(
        activeClients.map((client) async {
          try {
            final service = _serviceResolver(client.type);
            final torrents = await service.getTorrents(client);
            allTorrents.addAll(torrents);
            onlineStatus[client.id] = true;
          } catch (e) {
            onlineStatus[client.id] = false;
            debugPrint('Error fetching torrents from ${client.name}: $e');
          }
        }),
      );
      _allTorrents = allTorrents;
      _errorCount = allTorrents.where((t) => t.isError).length;
      _lastRefreshOnlineStatus
        ..clear()
        ..addAll(onlineStatus);

      // 按保存路径+名称计算辅种数：相同路径下同名种子的数量 - 1（自身），即真正的 cross-seed 数
      final groupCounts = <String, int>{};
      for (final t in allTorrents) {
        if (t.savePath != null && t.savePath!.isNotEmpty) {
          final key = '${t.savePath}::${t.name}';
          groupCounts[key] = (groupCounts[key] ?? 0) + 1;
        }
      }
      for (final t in _allTorrents) {
        if (t.savePath != null && t.savePath!.isNotEmpty) {
          final key = '${t.savePath}::${t.name}';
          final count = groupCounts[key] ?? 0;
          t.multiSource = count > 0 ? count - 1 : 0;
        } else {
          t.multiSource = 0;
        }
      }

      // 计算并缓存异常原因统计（按数量降序）
      final reasonCounts = <String, int>{};
      for (final t in allTorrents) {
        if (t.error != null && t.error!.isNotEmpty) {
          reasonCounts[t.error!] = (reasonCounts[t.error!] ?? 0) + 1;
        }
      }
      final reasonEntries = reasonCounts.entries.toList();
      reasonEntries.sort((a, b) => b.value.compareTo(a.value));
      _errorReasonsCache = reasonEntries;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (showLoading) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ---- 种子操作 ----

  Future<bool> pauseTorrents(ClientConfig client, List<String> hashes) async {
    try {
      final service = _serviceResolver(client.type);
      await service.pauseTorrents(client, hashes);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resumeTorrents(ClientConfig client, List<String> hashes) async {
    try {
      final service = _serviceResolver(client.type);
      await service.resumeTorrents(client, hashes);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTorrents(
    ClientConfig client,
    List<String> hashes, {
    bool deleteFiles = false,
  }) async {
    try {
      final service = _serviceResolver(client.type);
      await service.deleteTorrents(client, hashes, deleteFiles: deleteFiles);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> replaceTracker(
    ClientConfig client,
    String hash,
    String oldUrl,
    String newUrl,
  ) async {
    try {
      final service = ServiceFactory.getService(client.type);
      await service.replaceTracker(client, hash, oldUrl, newUrl);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
