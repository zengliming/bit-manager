import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../services/service_factory.dart';

class TorrentProvider extends ChangeNotifier {
  List<Torrent> _allTorrents = [];
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

  List<Torrent> get allTorrents => List.unmodifiable(_allTorrents);

  List<Torrent> get filteredTorrents {
    var result = _allTorrents;
    if (_stateFilter != null && _stateFilter!.isNotEmpty) {
      result = result.where((t) => _stateFilter!.contains(t.state)).toList();
    }
    if (_clientFilter != null) {
      result = result.where((t) => t.clientId == _clientFilter).toList();
    }
    if (_errorOnly) {
      result = result.where((t) => t.isError).toList();
    }
    if (_errorFilter != null) {
      result = result.where((t) => t.error == _errorFilter).toList();
    }
    if (_siteFilter != null && _siteFilter!.isNotEmpty) {
      result = result.where((t) => t.trackers.any((tr) => tr.contains(_siteFilter!))).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.name.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  String get searchQuery => _searchQuery;
  Set<TorrentState>? get stateFilter => _stateFilter;
  int get stateTabIndex => _stateTabIndex;
  String? get clientFilter => _clientFilter;
  bool get errorOnly => _errorOnly;
  String? get errorFilter => _errorFilter;
  String? get siteFilter => _siteFilter;
  bool get loading => _loading;
  String? get error => _error;
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

  int get errorCount => _allTorrents.where((t) => t.isError).length;

  // ---- 筛选 ----

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStateFilter(Set<TorrentState>? states) {
    _stateFilter = states;
    notifyListeners();
  }

  void setStateTabIndex(int index) {
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
    _clientFilter = clientId;
    notifyListeners();
  }

  void setErrorOnly(bool v) {
    _errorOnly = v;
    notifyListeners();
  }

  void setErrorFilter(String? errorMsg) {
    _errorFilter = errorMsg;
    notifyListeners();
  }

  void setSiteFilter(String? site) {
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

  Future<void> refreshTorrents(List<ClientConfig> activeClients, {bool showLoading = true}) async {
    if (showLoading) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final allTorrents = <Torrent>[];
      for (final client in activeClients) {
        try {
          final service = ServiceFactory.getService(client.type);
          final torrents = await service.getTorrents(client);
          allTorrents.addAll(torrents);
        } catch (e) {
          debugPrint('Error fetching torrents from ${client.name}: $e');
        }
      }
      _allTorrents = allTorrents;
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
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.pauseTorrent(client, hash);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resumeTorrents(ClientConfig client, List<String> hashes) async {
    try {
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.resumeTorrent(client, hash);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTorrents(ClientConfig client, List<String> hashes, {bool deleteFiles = false}) async {
    try {
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.deleteTorrent(client, hash, deleteFiles: deleteFiles);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> replaceTracker(ClientConfig client, String hash, String oldUrl, String newUrl) async {
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
}
