# Code Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the confirmed code-review bugs around RSS duplicate detection, stats counting, HTTP client caching, debounce disposal, filter state, and Transmission batch behavior.

**Architecture:** Keep changes local to the providers/services already touched by the optimization diff. Replace shared mutable RSS cache state with per-call snapshots, use typed stats refresh results, invalidate Dio cache on client config changes, and make timer/batch behavior explicit. Add focused regression tests with lightweight dependency injection where static construction currently blocks testing.

**Tech Stack:** Flutter/Dart 3.12, `provider`, `dio`, `flutter_test`.

---

## File Structure

Modify:

- `lib/providers/rss_provider.dart`
  - Add small dependency-injection constructor hooks for `RssService` and torrent client service resolution.
  - Replace provider-level `_torrentsCache` with local snapshots returned by `_prefetchTorrents()`.
  - Add in-pass RSS duplicate key tracking for successful auto-downloads.

- `lib/providers/stats_provider.dart`
  - Add private `_ClientStatsRefreshResult` class.
  - Return typed objects from per-client `Future.wait` branches.
  - Compute `activeTorrents` via `Torrent.isActive`.

- `lib/providers/client_provider.dart`
  - Import `HttpClientUtil`.
  - Clear Dio cache after add/update/delete client mutations.
  - Restore loading-state notification after `_loading = true`.

- `lib/utils/http_client.dart`
  - Make Dio cache key include `baseUrl` and `timeoutSeconds`.

- `lib/providers/torrent_provider.dart`
  - Reset `_searchQueryLowerCase` in `clearAllFilters()`.
  - Override `dispose()` to cancel `_searchDebounce`.

- `lib/services/transmission_service.dart`
  - Add helper that resolves all requested hashes or throws.
  - Use it in batch pause/resume/delete methods.

Create:

- `test/providers/rss_provider_test.dart`
- `test/providers/stats_provider_test.dart`
- `test/providers/client_provider_test.dart`
- `test/utils/http_client_test.dart`
- `test/services/transmission_service_test.dart`

Modify:

- `test/providers/torrent_provider_test.dart`
  - Add tests for dispose-cancelled debounce and `clearAllFilters()` lowercase consistency.

---

### Task 1: Fix and test `HttpClientUtil` cache keys

**Files:**
- Modify: `lib/utils/http_client.dart:8-49`
- Create: `test/utils/http_client_test.dart`

- [ ] **Step 1: Write failing tests for distinct timeout cache entries**

Create `test/utils/http_client_test.dart`:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/utils/http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClientConfig clientWithTimeout(int timeoutSeconds) => ClientConfig(
        id: 'client-$timeoutSeconds',
        name: 'Client $timeoutSeconds',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
        timeoutSeconds: timeoutSeconds,
      );

  tearDown(() {
    HttpClientUtil.instance.clearClientDioCache();
  });

  test('createClientDio does not reuse a cached Dio with a different timeout', () {
    final util = HttpClientUtil.instance;

    final fast = util.createClientDio(clientWithTimeout(5));
    final slow = util.createClientDio(clientWithTimeout(30));

    expect(fast, isNot(same(slow)));
    expect(fast.options.connectTimeout, const Duration(seconds: 5));
    expect(slow.options.connectTimeout, const Duration(seconds: 30));
    expect(slow.options.receiveTimeout, const Duration(seconds: 35));
    expect(slow.options.sendTimeout, const Duration(seconds: 35));
  });

  test('clearClientDioCache forces a new Dio for the same configuration', () {
    final util = HttpClientUtil.instance;
    final config = clientWithTimeout(10);

    final first = util.createClientDio(config);
    util.clearClientDioCache();
    final second = util.createClientDio(config);

    expect(first, isNot(same(second)));
  });
}
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```powershell
flutter test test/utils/http_client_test.dart
```

Expected: first test FAILS because `createClientDio()` currently caches by `baseUrl` only and returns the same Dio for 5s and 30s timeouts.

- [ ] **Step 3: Implement cache key including timeout**

In `lib/utils/http_client.dart`, replace the cache field/comment and `createClientDio()` with:

```dart
  /// 按客户端连接配置缓存 Dio 实例，复用连接池
  final Map<String, Dio> _clientDioCache = {};
```

Add a private key helper inside `HttpClientUtil`:

```dart
  String _clientDioCacheKey(ClientConfig config) =>
      '${config.baseUrl}|timeout=${config.timeoutSeconds}';
```

Replace `createClientDio()` with:

```dart
  /// 获取或创建为特定客户端配置的 Dio 实例（按连接配置缓存复用）
  Dio createClientDio(ClientConfig config) {
    return _clientDioCache.putIfAbsent(
      _clientDioCacheKey(config),
      () => Dio(BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: Duration(seconds: config.timeoutSeconds),
        receiveTimeout: Duration(seconds: config.timeoutSeconds + 5),
        sendTimeout: Duration(seconds: config.timeoutSeconds + 5),
        headers: {'User-Agent': 'BitManager/1.0'},
      )),
    );
  }
```

- [ ] **Step 4: Run the test and verify it passes**

Run:

```powershell
flutter test test/utils/http_client_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/utils/http_client.dart test/utils/http_client_test.dart
git commit -m @'
fix: include timeout in Dio cache key

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 2: Invalidate Dio cache when client configs change

**Files:**
- Modify: `lib/providers/client_provider.dart:1-72`
- Create: `test/providers/client_provider_test.dart`

- [ ] **Step 1: Write failing tests for loading notification and cache invalidation seam**

Create `test/providers/client_provider_test.dart`:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/providers/client_provider.dart';
import 'package:bit_manager/utils/http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClientConfig client({String id = 'qb', int timeoutSeconds = 10}) => ClientConfig(
        id: id,
        name: 'Client $id',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
        timeoutSeconds: timeoutSeconds,
      );

  tearDown(() {
    HttpClientUtil.instance.clearClientDioCache();
  });

  test('addClient clears cached Dio instances after saving the config', () async {
    final util = HttpClientUtil.instance;
    final config = client(timeoutSeconds: 10);
    final cached = util.createClientDio(config);
    final provider = ClientProvider();

    await provider.addClient(config);
    final afterAdd = util.createClientDio(config);

    expect(afterAdd, isNot(same(cached)));
  });

  test('updateClient clears cached Dio instances after saving the config', () async {
    final util = HttpClientUtil.instance;
    final original = client(timeoutSeconds: 10);
    final cached = util.createClientDio(original);
    final provider = ClientProvider();

    await provider.addClient(original);
    final afterAdd = util.createClientDio(original);
    await provider.updateClient(original.id, original.copyWith(timeoutSeconds: 20));
    final afterUpdate = util.createClientDio(original.copyWith(timeoutSeconds: 20));

    expect(afterAdd, isNot(same(cached)));
    expect(afterUpdate.options.connectTimeout, const Duration(seconds: 20));
  });

  test('deleteClient clears cached Dio instances after removing the config', () async {
    final util = HttpClientUtil.instance;
    final config = client(timeoutSeconds: 10);
    final provider = ClientProvider();

    await provider.addClient(config);
    final cached = util.createClientDio(config);
    await provider.deleteClient(config.id);
    final afterDelete = util.createClientDio(config);

    expect(afterDelete, isNot(same(cached)));
  });
}
```

- [ ] **Step 2: Run the new test and verify it fails**

Run:

```powershell
flutter test test/providers/client_provider_test.dart
```

Expected: at least one cache-invalidation test FAILS because `ClientProvider` does not call `clearClientDioCache()`.

- [ ] **Step 3: Implement invalidation and restore loading notification**

In `lib/providers/client_provider.dart`, add the import:

```dart
import '../utils/http_client.dart';
```

In `loadClients()`, restore notification after `_loading = true`:

```dart
  Future<void> loadClients() async {
    _loading = true;
    notifyListeners();

    try {
```

In `addClient()`:

```dart
  Future<void> addClient(ClientConfig config) async {
    _clients.add(config);
    await _saveClients();
    HttpClientUtil.instance.clearClientDioCache();
    notifyListeners();
  }
```

In `updateClient()`:

```dart
  Future<void> updateClient(String id, ClientConfig updated) async {
    final index = _clients.indexWhere((c) => c.id == id);
    if (index != -1) {
      _clients[index] = updated;
      await _saveClients();
      HttpClientUtil.instance.clearClientDioCache();
      notifyListeners();
    }
  }
```

In `deleteClient()`:

```dart
  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    _onlineStatus.remove(id);
    _errorMessages.remove(id);
    final storage = await LocalStorage.getInstance();
    await storage.deletePassword(id);
    await _saveClients();
    HttpClientUtil.instance.clearClientDioCache();
    notifyListeners();
  }
```

- [ ] **Step 4: Run tests and verify they pass**

Run:

```powershell
flutter test test/providers/client_provider_test.dart test/utils/http_client_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/providers/client_provider.dart test/providers/client_provider_test.dart
git commit -m @'
fix: invalidate Dio cache on client changes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 3: Fix typed stats aggregation and active torrent count

**Files:**
- Modify: `lib/providers/stats_provider.dart:16-171`
- Create: `test/providers/stats_provider_test.dart`

- [ ] **Step 1: Write failing active count test**

Create `test/providers/stats_provider_test.dart`:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/stats_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClientConfig client(String id) => ClientConfig(
        id: id,
        name: 'Client $id',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      );

  Torrent torrent({
    required String id,
    required int downloadSpeed,
    required int uploadSpeed,
    TorrentState state = TorrentState.downloading,
  }) => Torrent(
        id: id,
        hash: 'hash-$id',
        name: 'Torrent $id',
        clientId: 'qb',
        clientType: ClientType.qBittorrent,
        state: state,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        trackerStatuses: const ['2'],
      );

  test('activeTorrents counts a torrent with download and upload speed once', () async {
    final provider = StatsProvider();
    final qb = client('qb');
    final bothDirections = torrent(id: 'both', downloadSpeed: 100, uploadSpeed: 50);

    await provider.refreshStats([qb], [bothDirections], {qb.id: false});

    expect(provider.globalStats.downloadingCount, 1);
    expect(provider.globalStats.uploadingCount, 1);
    expect(provider.globalStats.activeTorrents, 1);
  });

  test('refreshStats keeps totals and client stats after typed aggregation', () async {
    final provider = StatsProvider();
    final qb = client('qb');
    final t1 = torrent(id: 'one', downloadSpeed: 100, uploadSpeed: 0);
    t1.downloaded = 10;
    t1.uploaded = 5;
    t1.totalSize = 1000;

    await provider.refreshStats([qb], [t1], {qb.id: false});

    expect(provider.globalStats.downloadSpeed, 100);
    expect(provider.globalStats.uploadSpeed, 0);
    expect(provider.globalStats.totalDownloaded, 10);
    expect(provider.globalStats.totalUploaded, 5);
    expect(provider.globalStats.totalSizeOnDisk, 1000);
    expect(provider.globalStats.clientStatsList, hasLength(1));
    expect(provider.globalStats.clientStatsList.single.clientId, qb.id);
  });
}
```

- [ ] **Step 2: Run the new stats test and verify it fails**

Run:

```powershell
flutter test test/providers/stats_provider_test.dart
```

Expected: first test FAILS with `activeTorrents` equal to 2 instead of 1.

- [ ] **Step 3: Add typed result class**

At the top of `lib/providers/stats_provider.dart`, after imports and before `class StatsProvider`, add:

```dart
class _ClientStatsRefreshResult {
  final int downloadSpeed;
  final int uploadSpeed;
  final int totalDownloaded;
  final int totalUploaded;
  final int clientSize;
  final ClientStats clientStats;

  const _ClientStatsRefreshResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.totalDownloaded,
    required this.totalUploaded,
    required this.clientSize,
    required this.clientStats,
  });
}
```

- [ ] **Step 4: Replace map return with typed result**

In `refreshStats()`, replace the `return { ... };` block at current lines 93-123 with:

```dart
        return _ClientStatsRefreshResult(
          downloadSpeed: clientDl,
          uploadSpeed: clientUl,
          totalDownloaded: totalDl,
          totalUploaded: totalUl,
          clientSize: clientSize,
          clientStats: ClientStats(
            clientId: client.id,
            clientName: client.name,
            type: client.type,
            host: client.host,
            port: client.port,
            online: clientOnline,
            torrentCount: clientTorrents.length,
            downloadSpeed: clientDl,
            uploadSpeed: clientUl,
            sizeOnDisk: clientSize,
            downloadingCount: downloading,
            uploadingCount: uploading,
            seedingCount: seeding,
            pausedUpCount: pausedUp,
            pausedDlCount: pausedDl,
            errorCount: error,
            checkingCount: checking,
            waitingCount: waiting,
            seedsConnected: seedsConnected,
            freeSpace: freeSpace,
            downloadLimit: dllimit,
            uploadLimit: ullimit,
          ),
        );
```

Replace the aggregation loop body at current lines 129-143 with:

```dart
      for (final r in results) {
        downloadSpeed += r.downloadSpeed;
        uploadSpeed += r.uploadSpeed;
        totalDownloaded += r.totalDownloaded;
        totalUploaded += r.totalUploaded;
        totalSize += r.clientSize;
        final cs = r.clientStats;
        clientStatsList.add(cs);
        globalDownloading += cs.downloadingCount;
        globalUploading += cs.uploadingCount;
        globalSeeding += cs.seedingCount;
        globalPaused += cs.pausedUpCount + cs.pausedDlCount;
        globalError += cs.errorCount;
        globalChecking += cs.checkingCount;
        globalWaiting += cs.waitingCount;
      }
```

- [ ] **Step 5: Fix activeTorrents**

In the `GlobalStats` constructor call, replace:

```dart
        activeTorrents: globalDownloading + globalUploading + globalChecking,
```

with:

```dart
        activeTorrents: allTorrents.where((t) => t.isActive).length,
```

- [ ] **Step 6: Run tests and verify they pass**

Run:

```powershell
flutter test test/providers/stats_provider_test.dart test/models/stats_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/providers/stats_provider.dart test/providers/stats_provider_test.dart
git commit -m @'
fix: count active torrents without duplication

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 4: Fix TorrentProvider debounce disposal and filter reset

**Files:**
- Modify: `lib/providers/torrent_provider.dart:154-163, 296`
- Modify: `test/providers/torrent_provider_test.dart:323-483`

- [ ] **Step 1: Add failing tests**

Append these tests before the final closing brace in `test/providers/torrent_provider_test.dart`:

```dart
  test('clearAllFilters clears cached lowercase search query', () async {
    final qb = client('qb');
    final linux = torrent(id: '1', hash: 'a', name: 'Linux ISO');
    final ubuntu = torrent(id: '2', hash: 'b', name: 'Ubuntu ISO');
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.success([linux, ubuntu]),
    );
    await provider.refreshTorrents([qb], showLoading: false);

    provider.setSearchQuery('linux');
    expect(provider.filteredTorrents, hasLength(1));

    provider.clearAllFilters();
    expect(provider.searchQuery, isEmpty);
    expect(provider.filteredTorrents, hasLength(2));
  });

  test('dispose cancels pending search debounce notification', () async {
    final qb = client('qb');
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.success(const []),
    );
    await provider.refreshTorrents([qb], showLoading: false);

    var notifyCount = 0;
    provider.addListener(() => notifyCount++);
    provider.setSearchQuery('linux');
    provider.dispose();

    await Future.delayed(const Duration(milliseconds: 250));

    expect(notifyCount, 0);
  });
```

- [ ] **Step 2: Run the targeted tests and verify failure**

Run:

```powershell
flutter test test/providers/torrent_provider_test.dart --plain-name "clearAllFilters clears cached lowercase search query"
flutter test test/providers/torrent_provider_test.dart --plain-name "dispose cancels pending search debounce notification"
```

Expected: first test FAILS because `_searchQueryLowerCase` is stale; second test FAILS or errors because the timer calls `notifyListeners()` after disposal.

- [ ] **Step 3: Reset cached lowercase query**

In `lib/providers/torrent_provider.dart`, update `clearAllFilters()`:

```dart
  void clearAllFilters() {
    _stateFilter = null;
    _stateTabIndex = 0;
    _clientFilter = null;
    _errorOnly = false;
    _errorFilter = null;
    _siteFilter = null;
    _searchQuery = '';
    _searchQueryLowerCase = '';
    notifyListeners();
  }
```

- [ ] **Step 4: Cancel debounce on dispose**

At the end of `TorrentProvider`, before the final `}`, add:

```dart
  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
```

- [ ] **Step 5: Run tests and verify they pass**

Run:

```powershell
flutter test test/providers/torrent_provider_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/providers/torrent_provider.dart test/providers/torrent_provider_test.dart
git commit -m @'
fix: cancel torrent search debounce on dispose

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 5: Refactor RSS duplicate cache to local snapshots

**Files:**
- Modify: `lib/providers/rss_provider.dart:1-193`
- Create: `test/providers/rss_provider_test.dart`

- [ ] **Step 1: Add dependency injection seams to RssProvider**

In `lib/providers/rss_provider.dart`, add import:

```dart
import '../services/torrent_client.dart';
```

Add typedefs after imports:

```dart
typedef RssServiceFactory = RssService Function();
typedef RssTorrentServiceResolver = ITorrentClientService Function(ClientType type);
```

Inside `RssProvider`, add fields and constructor after `_error`:

```dart
  final RssServiceFactory _rssServiceFactory;
  final RssTorrentServiceResolver _serviceResolver;

  RssProvider({
    RssServiceFactory? rssServiceFactory,
    RssTorrentServiceResolver? serviceResolver,
  })  : _rssServiceFactory = rssServiceFactory ?? RssService.new,
        _serviceResolver = serviceResolver ?? ServiceFactory.getService;
```

Remove the provider-level field:

```dart
  final Map<String, List<Torrent>> _torrentsCache = {};
```

- [ ] **Step 2: Change prefetch to return a local snapshot**

Replace `_prefetchTorrents()` with:

```dart
  /// 批量预取所有活跃客户端的种子列表，返回本次操作的局部快照
  Future<Map<String, List<Torrent>>> _prefetchTorrents(
      List<ClientConfig> clients) async {
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
```

Replace `_isDuplicateFromCache()` signature and cache access with:

```dart
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
          link.contains(t.hash));
      if (exists) return true;
    }
    return false;
  }
```

- [ ] **Step 3: Update fetchItems to use local snapshot**

In `fetchItems()`, replace:

```dart
      final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
```

with:

```dart
      final items = await rssService.fetchItems(source, since: source.lastFetchedAt);
```

Use the local service factory by changing the earlier construction to:

```dart
    final rssService = _rssServiceFactory();
```

Replace the prefetch block with:

```dart
      if (clients != null && clients.isNotEmpty) {
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
```

- [ ] **Step 4: Add in-pass duplicate helpers**

Inside `RssProvider`, after `_isDuplicateFromCache()`, add:

```dart
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
```

- [ ] **Step 5: Update processAutoDownloads to use local snapshot and in-pass guard**

In `processAutoDownloads()`, change service construction to:

```dart
    final rssService = _rssServiceFactory();
```

Replace the upfront prefetch with:

```dart
    final torrentsCache = await _prefetchTorrents(clients);
    final downloadedKeysInCurrentPass = <String>{};
```

Replace duplicate checks inside the item loop with:

```dart
          if (_isDuplicateInCurrentPass(item, downloadedKeysInCurrentPass)) {
            continue;
          }
          if (_isDuplicateFromCache(item, clients, torrentsCache)) continue;
```

After `_downloadedGuids.add(item.guid);`, add:

```dart
            _markDownloadedInCurrentPass(item, downloadedKeysInCurrentPass);
```

Replace `ServiceFactory.getService(targetClient.type)` with:

```dart
          final service = _serviceResolver(targetClient.type);
```

- [ ] **Step 6: Write RSS provider tests**

Create `test/providers/rss_provider_test.dart`:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/rss_source.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/rss_provider.dart';
import 'package:bit_manager/services/rss_service.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRssService extends RssService {
  final Map<String, List<RssItem>> itemsByUrl;

  _FakeRssService(this.itemsByUrl);

  @override
  Future<List<RssItem>> fetchItems(RssSource source, {DateTime? since}) async {
    return List<RssItem>.from(itemsByUrl[source.url] ?? const []);
  }

  @override
  bool matchesFilter(String title, String? regex) => true;
}

class _FakeTorrentService implements ITorrentClientService {
  final List<Torrent> torrents;
  final addedUrls = <String>[];

  _FakeTorrentService({this.torrents = const []});

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async => torrents;

  @override
  Future<void> addTorrentFromUrl(
    ClientConfig config, {
    required String url,
    String? savePath,
  }) async {
    addedUrls.add(url);
  }

  @override
  Future<bool> testConnection(ClientConfig config) async => true;

  @override
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash) async => [];

  @override
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash) async => [];

  @override
  Future<void> addTorrentFile(ClientConfig config, {required String filePath, String? savePath}) async {}

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes) async {}

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes) async {}

  @override
  Future<void> deleteTorrent(ClientConfig config, String hash, {bool deleteFiles = false}) async {}

  @override
  Future<void> deleteTorrents(ClientConfig config, List<String> hashes, {bool deleteFiles = false}) async {}

  @override
  Future<void> replaceTracker(ClientConfig config, String hash, String oldUrl, String newUrl) async {}

  @override
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl) async {}

  @override
  Future<void> removeTracker(ClientConfig config, String hash, String trackerUrl) async {}

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async => false;

  @override
  Future<ClientStats> getStats(ClientConfig config) async => ClientStats(
        clientId: config.id,
        clientName: config.name,
        type: config.type,
      );

  @override
  Future<int> getFreeSpace(ClientConfig config) async => 0;

  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async => [0, 0];
}

void main() {
  ClientConfig client(String id) => ClientConfig(
        id: id,
        name: 'Client $id',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      );

  RssSource source(String id, String url, String clientId) => RssSource(
        id: id,
        name: 'Source $id',
        url: url,
        autoDownload: true,
        assignedClientId: clientId,
      );

  RssItem item(String guid, String title, String link) => RssItem(
        guid: guid,
        title: title,
        link: link,
        pubDate: DateTime(2026, 1, 1),
      );

  test('fetchItems marks duplicates from its local torrent snapshot', () async {
    final qb = client('qb');
    final torrent = Torrent(
      id: '1',
      hash: 'abc123',
      name: 'Linux ISO',
      clientId: qb.id,
      clientType: qb.type,
      trackerStatuses: const ['2'],
    );
    final torrentService = _FakeTorrentService(torrents: [torrent]);
    final rss = _FakeRssService({
      'https://rss.test/feed': [item('g1', 'Linux ISO', 'magnet:?xt=urn:btih:abc123')],
    });
    final provider = RssProvider(
      rssServiceFactory: () => rss,
      serviceResolver: (_) => torrentService,
    );
    await provider.addSource(source('s1', 'https://rss.test/feed', qb.id));

    final items = await provider.fetchItems('s1', clients: [qb]);

    expect(items.single.isDuplicate, isTrue);
  });

  test('processAutoDownloads skips duplicate RSS items added earlier in the same pass', () async {
    final qb = client('qb');
    final torrentService = _FakeTorrentService();
    final rss = _FakeRssService({
      'https://rss.test/feed': [
        item('g1', 'Linux ISO', 'magnet:?xt=urn:btih:same'),
        item('g2', 'Different Guid Same Link', 'magnet:?xt=urn:btih:same'),
      ],
    });
    final provider = RssProvider(
      rssServiceFactory: () => rss,
      serviceResolver: (_) => torrentService,
    );
    await provider.addSource(source('s1', 'https://rss.test/feed', qb.id));

    await provider.processAutoDownloads([qb]);

    expect(torrentService.addedUrls, ['magnet:?xt=urn:btih:same']);
  });
}
```

- [ ] **Step 7: Run RSS tests**

Run:

```powershell
flutter test test/providers/rss_provider_test.dart
```

Expected: PASS after implementation.

- [ ] **Step 8: Commit**

```powershell
git add lib/providers/rss_provider.dart test/providers/rss_provider_test.dart
git commit -m @'
fix: isolate RSS torrent duplicate snapshots

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 6: Make Transmission batch hash resolution explicit

**Files:**
- Modify: `lib/services/transmission_service.dart:288-372`
- Create: `test/services/transmission_service_test.dart`

- [ ] **Step 1: Add a testable service subclass**

Create `test/services/transmission_service_test.dart`:

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/services/transmission_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestTransmissionService extends TransmissionService {
  final Map<String, dynamic> torrentGetResponse;
  final rpcCalls = <String>[];

  _TestTransmissionService(this.torrentGetResponse);

  @override
  Future<Map<String, dynamic>> debugRpcCallForTest(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) async {
    rpcCalls.add(method);
    if (method == 'torrent-get') return torrentGetResponse;
    return {'result': 'success', 'arguments': {}};
  }

  @override
  Future<String?> debugGetSessionIdForTest(ClientConfig config) async => 'sid';
}

void main() {
  ClientConfig trClient() => ClientConfig(
        id: 'tr',
        name: 'Transmission',
        type: ClientType.transmission,
        host: '127.0.0.1',
        port: 9091,
      );

  test('pauseTorrents throws when not all hashes resolve to Transmission ids', () async {
    final service = _TestTransmissionService({
      'arguments': {
        'torrents': [
          {'id': 1, 'hashString': 'known'},
        ],
      },
    });

    expect(
      () => service.pauseTorrents(trClient(), ['known', 'missing']),
      throwsA(isA<Exception>().having(
        (e) => e.toString(),
        'message',
        contains('Unable to resolve torrent hashes'),
      )),
    );
  });
}
```

- [ ] **Step 2: Run the new test and verify it fails to compile**

Run:

```powershell
flutter test test/services/transmission_service_test.dart
```

Expected: FAILS to compile because `debugRpcCallForTest` and `debugGetSessionIdForTest` do not exist yet.

- [ ] **Step 3: Add protected test seams to TransmissionService**

In `lib/services/transmission_service.dart`, change `_getSessionId` from private implementation call sites to a protected wrapper pattern:

Add these methods inside `TransmissionService` after `_getSessionId()`:

```dart
  @visibleForTesting
  Future<String?> debugGetSessionIdForTest(ClientConfig config) =>
      _getSessionId(config);
```

Add this method after `_rpcCall()`:

```dart
  @visibleForTesting
  Future<Map<String, dynamic>> debugRpcCallForTest(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) =>
      _rpcCall(config, method, args: args, sessionId: sessionId);
```

Also add the import if not already present:

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Route `_hashToIds` and batch methods through test seams**

In `_hashToIds()`, replace `_rpcCall(...)` with `debugRpcCallForTest(...)`:

```dart
    final result = await debugRpcCallForTest(config, 'torrent-get',
        args: {'fields': ['id', 'hashString']}, sessionId: sid);
```

In batch methods only, replace `_getSessionId(config)` with:

```dart
    final sid = await debugGetSessionIdForTest(config);
```

Keep single-torrent methods unchanged unless the compiler requires consistency.

- [ ] **Step 5: Add all-hashes resolver helper**

After `_hashToIds()`, add:

```dart
  Future<List<int>> _hashToIdsOrThrow(
    ClientConfig config,
    List<String> hashes,
    String? sid,
  ) async {
    final ids = await _hashToIds(config, hashes, sid);
    if (ids.length != hashes.toSet().length) {
      throw Exception('Unable to resolve torrent hashes: expected ${hashes.toSet().length}, found ${ids.length}');
    }
    return ids;
  }
```

- [ ] **Step 6: Use throwing resolver in batch methods**

In `pauseTorrents()` replace:

```dart
    final ids = await _hashToIds(config, hashes, sid);
```

with:

```dart
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
```

Make the same replacement in `resumeTorrents()` and `deleteTorrents()`.

- [ ] **Step 7: Run the service test**

Run:

```powershell
flutter test test/services/transmission_service_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```powershell
git add lib/services/transmission_service.dart test/services/transmission_service_test.dart
git commit -m @'
fix: fail Transmission batch operations on missing hashes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

---

### Task 7: Run formatting and full regression suite

**Files:**
- No source files should be modified except automatic Dart formatting.

- [ ] **Step 1: Format changed Dart files**

Run:

```powershell
dart format lib/providers/rss_provider.dart lib/providers/stats_provider.dart lib/providers/client_provider.dart lib/providers/torrent_provider.dart lib/utils/http_client.dart lib/services/transmission_service.dart test/providers/rss_provider_test.dart test/providers/stats_provider_test.dart test/providers/client_provider_test.dart test/providers/torrent_provider_test.dart test/utils/http_client_test.dart test/services/transmission_service_test.dart
```

Expected: command completes and prints formatted file paths or `0 changed`.

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
flutter test test/utils/http_client_test.dart test/providers/client_provider_test.dart test/providers/stats_provider_test.dart test/providers/torrent_provider_test.dart test/providers/rss_provider_test.dart test/services/transmission_service_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run:

```powershell
flutter test
```

Expected: PASS. If failures occur, record the exact failing test and fix only failures caused by this change set.

- [ ] **Step 4: Inspect final diff**

Run:

```powershell
git diff --check
git diff --stat
git status --short
```

Expected: `git diff --check` prints no whitespace errors. `git status --short` shows only files intentionally changed by this plan and the design/plan docs.

- [ ] **Step 5: Commit final formatting/test adjustments**

If Step 1 changed files or Step 3 required fixes, commit them:

```powershell
git add lib test docs/superpowers/specs/2026-06-09-code-review-fixes-design.md docs/superpowers/plans/2026-06-09-code-review-fixes.md
git commit -m @'
test: cover code review fixes

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
'@
```

If there are no remaining uncommitted changes, skip this commit and report that no final commit was needed.

---

## Self-Review Notes

- Spec coverage: RSS cache isolation and in-pass duplicate guard are covered by Task 5. Stats active count and typed aggregation are covered by Task 3. Dio cache key and invalidation are covered by Tasks 1-2. TorrentProvider debounce and filter cache are covered by Task 4. Transmission missing hashes are covered by Task 6. Formatting and regression verification are covered by Task 7.
- Placeholder scan: no TBD/TODO placeholders are present.
- Type consistency: RssProvider injection uses `RssServiceFactory` and `RssTorrentServiceResolver`; StatsProvider uses `_ClientStatsRefreshResult`; Transmission test seams use `debugRpcCallForTest` and `debugGetSessionIdForTest` consistently.
