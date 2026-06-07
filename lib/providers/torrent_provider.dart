import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../services/service_factory.dart';

class TorrentProvider extends ChangeNotifier {
  List<Torrent> _allTorrents = [];
  String _searchQuery = '';
  TorrentState? _stateFilter;
  String? _clientFilter;
  bool _loading = false;
  String? _error;
  bool _selectMode = false;
  final Set<String> _selectedHashes = {};

  List<Torrent> get allTorrents => List.unmodifiable(_allTorrents);

  List<Torrent> get filteredTorrents {
    var result = _allTorrents;
    if (_stateFilter != null) {
      result = result.where((t) => t.state == _stateFilter).toList();
    }
    if (_clientFilter != null) {
      result = result.where((t) => t.clientId == _clientFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.name.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  String get searchQuery => _searchQuery;
  TorrentState? get stateFilter => _stateFilter;
  String? get clientFilter => _clientFilter;
  bool get loading => _loading;
  String? get error => _error;
  bool get selectMode => _selectMode;
  Set<String> get selectedHashes => Set.unmodifiable(_selectedHashes);
  int get selectedCount => _selectedHashes.length;

  // ---- 筛选 ----

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStateFilter(TorrentState? state) {
    _stateFilter = state;
    notifyListeners();
  }

  void setClientFilter(String? clientId) {
    _clientFilter = clientId;
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

  Future<void> refreshTorrents(List<ClientConfig> activeClients) async {
    _loading = true;
    _error = null;
    notifyListeners();

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
      _loading = false;
      notifyListeners();
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
