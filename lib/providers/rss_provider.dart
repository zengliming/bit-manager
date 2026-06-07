import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/rss_source.dart';
import '../services/rss_service.dart';
import '../services/service_factory.dart';
import '../utils/storage.dart';

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  final Map<String, List<RssItem>> _itemsCache = {};
  Set<String> _downloadedGuids = {};
  bool _loading = false;
  String? _error;

  List<RssSource> get sources => List.unmodifiable(_sources);
  bool get loading => _loading;
  String? get error => _error;

  List<RssItem> getItems(String sourceId) => _itemsCache[sourceId] ?? [];

  // ---- 持久化 ----

  Future<void> loadSources() async {
    _loading = true;
    notifyListeners();
    try {
      final storage = await LocalStorage.getInstance();
      final rawList = await storage.getJsonList('rss_sources');
      _sources = rawList.map((json) => RssSource.fromJson(json)).toList();
      final downloadedRaw = await storage.getString('rss_downloaded_guids');
      if (downloadedRaw != null) {
        _downloadedGuids = downloadedRaw.split(',').where((s) => s.isNotEmpty).toSet();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSources() async {
    final storage = await LocalStorage.getInstance();
    await storage.saveJsonList('rss_sources', _sources.map((s) => s.toJson()).toList());
  }

  Future<void> _saveDownloadedGuids() async {
    final storage = await LocalStorage.getInstance();
    await storage.setString('rss_downloaded_guids', _downloadedGuids.join(','));
  }

  // ---- CRUD ----

  Future<void> addSource(RssSource source) async {
    _sources.add(source);
    await _saveSources();
    notifyListeners();
  }

  Future<void> updateSource(String id, RssSource updated) async {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sources[index] = updated;
      await _saveSources();
      notifyListeners();
    }
  }

  Future<void> deleteSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    _itemsCache.remove(id);
    await _saveSources();
    notifyListeners();
  }

  // ---- 查重 ----

  /// 统一查重逻辑：跨所有客户端检查种子是否已存在
  Future<bool> _isDuplicate(RssItem item, List<ClientConfig> clients) async {
    if (item.link == null) return false;
    final link = item.link!;
    for (final client in clients) {
      try {
        final service = ServiceFactory.getService(client.type);
        final torrents = await service.getTorrents(client);
        final exists = torrents.any((t) =>
            t.name == item.title ||
            (link.startsWith('magnet:') && link.contains(t.hash)) ||
            (link.contains(t.hash)));
        if (exists) return true;
      } catch (_) {}
    }
    return false;
  }

  // ---- 获取条目 ----

  Future<List<RssItem>> fetchItems(String sourceId, {List<ClientConfig>? clients}) async {
    final source = _sources.firstWhere((s) => s.id == sourceId);
    final rssService = RssService();
    try {
      final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
      if (clients != null && clients.isNotEmpty) {
        for (final item in items) {
          if (_downloadedGuids.contains(item.guid)) {
            item.isDownloaded = true;
          }
          if (await _isDuplicate(item, clients)) {
            item.isDuplicate = true;
          }
        }
      }
      source.lastFetchedAt = DateTime.now();
      await _saveSources();
      _itemsCache[sourceId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ---- 自动下载 ----

  Future<void> processAutoDownloads(List<ClientConfig> clients) async {
    final rssService = RssService();
    for (final source in _sources) {
      if (!source.autoDownload || source.assignedClientId == null) continue;
      final targetClient = clients.where((c) => c.id == source.assignedClientId).firstOrNull;
      if (targetClient == null) continue;
      try {
        final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
        final allClients = clients; // check all clients, not just target
        for (final item in items) {
          if (_downloadedGuids.contains(item.guid)) continue;
          if (item.link == null) continue;
          if (source.enableRegex && source.filterRegex != null &&
              !rssService.matchesFilter(item.title, source.filterRegex)) {
            continue;
          }
          if (await _isDuplicate(item, allClients)) continue;
          final service = ServiceFactory.getService(targetClient.type);
          try {
            await service.addTorrentFromUrl(targetClient, url: item.link!, savePath: source.savePath);
            _downloadedGuids.add(item.guid);
            await _saveDownloadedGuids();
          } catch (e) {
            debugPrint('Auto-download failed for ${item.title}: $e');
          }
        }
      } catch (e) {
        debugPrint('RSS auto-download error for ${source.name}: $e');
      }
    }
  }

  Future<bool> downloadItem(String link, ClientConfig client, {String? savePath}) async {
    try {
      final service = ServiceFactory.getService(client.type);
      await service.addTorrentFromUrl(client, url: link, savePath: savePath);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> markDownloaded(String guid) async {
    _downloadedGuids.add(guid);
    await _saveDownloadedGuids();
  }
}
