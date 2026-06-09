import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/rss_source.dart';
import '../models/torrent.dart';
import '../services/rss_service.dart';
import '../services/service_factory.dart';
import '../services/torrent_client.dart';
import '../utils/storage.dart';

typedef RssServiceFactory = RssService Function();
typedef RssTorrentServiceResolver = ITorrentClientService Function(ClientType type);

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  final Map<String, List<RssItem>> _itemsCache = {};
  Set<String> _downloadedGuids = {};
  bool _loading = false;
  String? _error;

  final RssServiceFactory _rssServiceFactory;
  final RssTorrentServiceResolver _serviceResolver;

  RssProvider({
    RssServiceFactory? rssServiceFactory,
    RssTorrentServiceResolver? serviceResolver,
  })  : _rssServiceFactory = rssServiceFactory ?? RssService.new,
        _serviceResolver = serviceResolver ?? ServiceFactory.getService;

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

  /// 批量预取所有活跃客户端的种子列表，返回本次操作的局部快照
  Future<Map<String, List<Torrent>>> _prefetchTorrents(List<ClientConfig> clients) async {
    final cache = <String, List<Torrent>>{};
    await Future.wait(clients.map((client) async {
      try {
        final service = _serviceResolver(client.type);
        final torrents = await service.getTorrents(client);
        cache[client.id] = torrents;
      } catch (_) {
        cache[client.id] = [];
      }
    }));
    return cache;
  }

  /// 统一查重逻辑：跨所有客户端检查种子是否已存在
  /// 使用传入的快照中的种子列表，不再重复调用 API
  bool _isDuplicateFromCache(
    RssItem item,
    List<ClientConfig> clients,
    Map<String, List<Torrent>> torrentsCache,
  ) {
    if (item.link == null) return false;
    final link = item.link!;
    for (final client in clients) {
      final torrents = torrentsCache[client.id] ?? [];
      final exists = torrents.any((t) =>
          t.name == item.title ||
          (link.startsWith('magnet:') && link.contains(t.hash)) ||
          (link.contains(t.hash)));
      if (exists) return true;
    }
    return false;
  }

  // ---- 获取条目 ----

  Future<List<RssItem>> fetchItems(String sourceId, {List<ClientConfig>? clients}) async {
    final source = _sources.firstWhere((s) => s.id == sourceId);
    final rssService = _rssServiceFactory();
    try {
      final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
      if (clients != null && clients.isNotEmpty) {
        // 一次性预取所有客户端的种子列表
        final torrentsCache = await _prefetchTorrents(clients);
        for (final item in items) {
          if (_downloadedGuids.contains(item.guid)) {
            item.isDownloaded = true;
          }
          if (_isDuplicateFromCache(item, clients, torrentsCache)) {
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

  Set<String> _rssItemKeys(RssItem item) {
    return {
      if (item.guid.isNotEmpty) 'guid:${item.guid}',
      if (item.link != null && item.link!.isNotEmpty) 'link:${item.link}',
      if (item.title.isNotEmpty) 'title:${item.title}',
    };
  }

  bool _isDuplicateInCurrentPass(RssItem item, Set<String> downloadedKeys) {
    final keys = _rssItemKeys(item);
    return keys.any(downloadedKeys.contains);
  }

  void _markDownloadedInCurrentPass(RssItem item, Set<String> downloadedKeys) {
    downloadedKeys.addAll(_rssItemKeys(item));
  }

  Future<void> processAutoDownloads(List<ClientConfig> clients) async {
    final rssService = _rssServiceFactory();
    // 一次性预取所有客户端的种子列表，供本轮所有 RSS 源查重使用
    final torrentsCache = await _prefetchTorrents(clients);
    final downloadedKeysInCurrentPass = <String>{};
    for (final source in _sources) {
      if (!source.autoDownload || source.assignedClientId == null) continue;
      final targetClient = clients.where((c) => c.id == source.assignedClientId).firstOrNull;
      if (targetClient == null) continue;
      try {
        final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
        for (final item in items) {
          if (_downloadedGuids.contains(item.guid)) continue;
          if (item.link == null) continue;
          if (source.enableRegex && source.filterRegex != null &&
              !rssService.matchesFilter(item.title, source.filterRegex)) {
            continue;
          }
          if (_isDuplicateInCurrentPass(item, downloadedKeysInCurrentPass)) continue;
          if (_isDuplicateFromCache(item, clients, torrentsCache)) continue;
          final service = _serviceResolver(targetClient.type);
          try {
            await service.addTorrentFromUrl(targetClient, url: item.link!, savePath: source.savePath);
            _downloadedGuids.add(item.guid);
            _markDownloadedInCurrentPass(item, downloadedKeysInCurrentPass);
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
