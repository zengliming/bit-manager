import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/torrent_provider.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTorrentService implements ITorrentClientService {
  final List<Torrent> torrents;
  final Object? error;
  final bool throwsOnBatch;
  /// 按客户端 id 区分返回不同种子列表；非空时优先于 [torrents]。
  final Map<String, List<Torrent>> byClient;

  /// 记录批量删除调用：(hashes, deleteFiles)
  final List<(List<String>, bool)> deleteCalls = [];

  _FakeTorrentService.success(this.torrents)
    : error = null,
      throwsOnBatch = false,
      byClient = const {};
  _FakeTorrentService.failure(this.error)
    : torrents = const [],
      throwsOnBatch = false,
      byClient = const {};
  _FakeTorrentService({this.throwsOnBatch = false})
    : torrents = const [],
      error = null,
      byClient = const {};
  _FakeTorrentService.byClient(this.byClient)
    : torrents = const [],
      error = null,
      throwsOnBatch = false;

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final error = this.error;
    if (error != null) throw error;
    if (byClient.containsKey(config.id)) return byClient[config.id]!;
    return torrents;
  }

  @override
  Future<bool> testConnection(ClientConfig config) async => error == null;

  @override
  Future<List<TorrentFile>> getTorrentFiles(
    ClientConfig config,
    String hash,
  ) async => [];

  @override
  Future<List<TrackerInfo>> getTrackers(
    ClientConfig config,
    String hash,
  ) async => [];

  @override
  Future<void> addTorrentFile(
    ClientConfig config, {
    required String filePath,
    String? savePath,
  }) async {}

  @override
  Future<void> addTorrentFromUrl(
    ClientConfig config, {
    required String url,
    String? savePath,
  }) async {}

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes) async {
    if (throwsOnBatch) throw Exception('batch error');
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {}

  @override
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes) async {
    if (throwsOnBatch) throw Exception('batch error');
  }

  @override
  Future<void> deleteTorrent(
    ClientConfig config,
    String hash, {
    bool deleteFiles = false,
  }) async {}

  @override
  Future<void> deleteTorrents(
    ClientConfig config,
    List<String> hashes, {
    bool deleteFiles = false,
  }) async {
    if (throwsOnBatch) throw Exception('batch error');
    deleteCalls.add((List<String>.from(hashes), deleteFiles));
  }

  @override
  Future<void> replaceTracker(
    ClientConfig config,
    String hash,
    String oldUrl,
    String newUrl,
  ) async {}

  @override
  Future<void> addTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {}

  @override
  Future<void> removeTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {}

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async => false;

  @override
  Future<ClientStats> getStats(ClientConfig config) async => ClientStats(
    clientId: config.id,
    clientName: config.name,
    type: config.type,
    online: error == null,
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

  Torrent torrent({
    required String id,
    required String hash,
    String name = 'Test Torrent',
    TorrentState state = TorrentState.downloading,
    String? error,
    String? savePath,
    String? contentPath,
    String clientId = 'qb',
    List<String> trackers = const [],
  }) => Torrent(
    id: id,
    hash: hash,
    name: name,
    clientId: clientId,
    clientType: ClientType.qBittorrent,
    state: state,
    error: error,
    savePath: savePath,
    contentPath: contentPath,
    trackers: trackers,
    trackerStatuses: const ['2'], // 标记 tracker 成功，避免 isError 误判
  );

  // ---- 辅种数计算测试 ----

  group('multiSource cross-seed counting', () {
    final qb = ClientConfig(
      id: 'qb',
      name: 'Client qb',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
    );

    test('same contentPath with different names count as cross-seed', () async {
      // 同一份数据，不同站点以不同名称发布——真正的辅种场景
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        name: 'Movie.2024.BluRay',
        contentPath: '/data/Movie.2024',
      );
      final t2 = torrent(
        id: '2',
        hash: 'bbb',
        name: '电影2024蓝光版',
        contentPath: '/data/Movie.2024',
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      expect(p.allTorrents.firstWhere((t) => t.id == '1').multiSource, 1);
      expect(p.allTorrents.firstWhere((t) => t.id == '2').multiSource, 1);
    });

    test('same name but different contentPath is not cross-seed', () async {
      // 名称相同但数据完全不同，不应被误判为辅种
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        name: 'Same Name',
        contentPath: '/data/A',
      );
      final t2 = torrent(
        id: '2',
        hash: 'bbb',
        name: 'Same Name',
        contentPath: '/data/B',
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      expect(p.allTorrents.firstWhere((t) => t.id == '1').multiSource, 0);
      expect(p.allTorrents.firstWhere((t) => t.id == '2').multiSource, 0);
    });

    test('torrents without contentPath are not counted', () async {
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        name: 'No Path',
        contentPath: null,
      );
      final t2 = torrent(
        id: '2',
        hash: 'bbb',
        name: 'No Path',
        contentPath: null,
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      expect(p.allTorrents.firstWhere((t) => t.id == '1').multiSource, 0);
      expect(p.allTorrents.firstWhere((t) => t.id == '2').multiSource, 0);
    });

    test('same contentPath across different clients is NOT merged', () async {
      // 两个客户端实例各自持有一份相同 contentPath 的种子——它们是不同机器上的不同数据，
      // 不应合并算作辅种；每个客户端内部的辅种数应独立计算。
      final qb1 = ClientConfig(
        id: 'qb1',
        name: 'Client qb1',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      );
      final qb2 = ClientConfig(
        id: 'qb2',
        name: 'Client qb2',
        type: ClientType.qBittorrent,
        host: '127.0.0.2',
        port: 8080,
      );
      // 每个客户端各两份，contentPath 相同但属于该实例内部——各自应为 1
      final qb1Torrents = [
        torrent(
          id: '1a',
          hash: 'aaa',
          name: 'Movie A',
          contentPath: '/data/Movie',
          clientId: 'qb1',
        ),
        torrent(
          id: '1b',
          hash: 'bbb',
          name: '电影A',
          contentPath: '/data/Movie',
          clientId: 'qb1',
        ),
      ];
      final qb2Torrents = [
        torrent(
          id: '2a',
          hash: 'ccc',
          name: 'Movie A',
          contentPath: '/data/Movie',
          clientId: 'qb2',
        ),
        torrent(
          id: '2b',
          hash: 'ddd',
          name: '电影A',
          contentPath: '/data/Movie',
          clientId: 'qb2',
        ),
      ];
      final mockService = _FakeTorrentService.byClient({
        'qb1': qb1Torrents,
        'qb2': qb2Torrents,
      });
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb1, qb2], showLoading: false);

      // 每个实例内部 2 份相同 contentPath → 辅种数 1（不是跨实例合并后的 3）
      for (final id in ['1a', '1b', '2a', '2b']) {
        expect(
          p.allTorrents.firstWhere((t) => t.id == id).multiSource,
          1,
          reason: '$id 应只算本实例内的辅种，跨实例不应合并',
        );
      }
    });

    test(
      'same contentPath but different size are separate cross-seed groups',
      () async {
        // 真实场景：cross-seed 硬链接把多个不同资源放进同名目录，
        // 它们 contentPath 相同但 totalSize 不同，不是同一份数据，不应合并算辅种。
        final qb = ClientConfig(
          id: 'qb',
          name: 'Client qb',
          type: ClientType.qBittorrent,
          host: '127.0.0.1',
          port: 8080,
        );
        // 同目录、同大小（21G）的两份——同一资源的辅种
        final big1 = torrent(
          id: 'b1',
          hash: 'aaa',
          name: '[耀眼].Dazzling.2026',
          contentPath: '/media/tv/[耀眼].Dazzling.2026',
          savePath: '/media/tv',
        )..totalSize = 23041830587;
        final big2 = torrent(
          id: 'b2',
          hash: 'bbb',
          name: '[耀眼].Dazzling.2026',
          contentPath: '/media/tv/[耀眼].Dazzling.2026',
          savePath: '/media/tv',
        )..totalSize = 23041830587;
        // 同目录、不同大小（10G）的两份——另一个资源，与 21G 不是同一份数据
        final mid1 = torrent(
          id: 'm1',
          hash: 'ccc',
          name: '[耀眼].Dazzling.2026',
          contentPath: '/media/tv/[耀眼].Dazzling.2026',
          savePath: '/media/tv',
        )..totalSize = 11123468644;
        final mid2 = torrent(
          id: 'm2',
          hash: 'ddd',
          name: '[耀眼].Dazzling.2026',
          contentPath: '/media/tv/[耀眼].Dazzling.2026',
          savePath: '/media/tv',
        )..totalSize = 11123468644;
        final mockService = _FakeTorrentService.success([
          big1,
          big2,
          mid1,
          mid2,
        ]);
        final p = TorrentProvider(serviceResolver: (_) => mockService);
        await p.refreshTorrents([qb], showLoading: false);

        // 21G 组：2 份 → 辅种 1；10G 组：2 份 → 辅种 1（不是合并后的 3）
        expect(
          p.allTorrents.firstWhere((t) => t.id == 'b1').multiSource,
          1,
          reason: '同 size 的才互为辅种',
        );
        expect(p.allTorrents.firstWhere((t) => t.id == 'b2').multiSource, 1);
        expect(p.allTorrents.firstWhere((t) => t.id == 'm1').multiSource, 1);
        expect(p.allTorrents.firstWhere((t) => t.id == 'm2').multiSource, 1);
      },
    );
  });

  // ---- 智能删除（无辅种时删除文件）测试 ----
  group('smart delete (deleteFilesWhenNoCrossSeed)', () {
    final qb = ClientConfig(
      id: 'qb',
      name: 'Client qb',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
    );

    test('无辅种种子：勾选后归入删文件组', () async {
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        contentPath: '/data/A',
      )..totalSize = 1000;
      final svc = _FakeTorrentService.success([t1]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final plan = p.planSmartDelete(qb, ['aaa']);
      expect(plan.deleteFilesHashes, ['aaa']);
      expect(plan.keepFilesHashes, isEmpty);
    });

    test('有辅种保留：仅删种子，保留文件', () async {
      // 两份同 contentPath 同 size 互为辅种；只删其中一份
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        contentPath: '/data/Movie',
      )..totalSize = 1000;
      final t2 = torrent(
        id: '2',
        hash: 'bbb',
        contentPath: '/data/Movie',
      )..totalSize = 1000;
      final svc = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final plan = p.planSmartDelete(qb, ['aaa']);
      expect(plan.deleteFilesHashes, isEmpty);
      expect(plan.keepFilesHashes, ['aaa']);
    });

    test('辅种组全部被删：可安全删文件', () async {
      // 两份互为辅种，本次同时删除两者 → 删后无人引用 → 删文件
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        contentPath: '/data/Movie',
      )..totalSize = 1000;
      final t2 = torrent(
        id: '2',
        hash: 'bbb',
        contentPath: '/data/Movie',
      )..totalSize = 1000;
      final svc = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final plan = p.planSmartDelete(qb, ['aaa', 'bbb']);
      expect(plan.deleteFilesHashes, containsAll(['aaa', 'bbb']));
      expect(plan.keepFilesHashes, isEmpty);
    });

    test('contentPath 为空：保守保留文件', () async {
      final t1 = torrent(id: '1', hash: 'aaa', contentPath: null);
      final svc = _FakeTorrentService.success([t1]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final plan = p.planSmartDelete(qb, ['aaa']);
      expect(plan.deleteFilesHashes, isEmpty);
      expect(plan.keepFilesHashes, ['aaa']);
    });

    test('未勾选时：全部保留文件，单次调用 deleteFiles=false', () async {
      final t1 = torrent(
        id: '1',
        hash: 'aaa',
        contentPath: '/data/A',
      )..totalSize = 1000;
      final svc = _FakeTorrentService.success([t1]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final ok = await p.deleteTorrentsSmart(
        qb,
        ['aaa'],
        deleteFilesWhenNoCrossSeed: false,
      );
      expect(ok, isTrue);
      expect(svc.deleteCalls.length, 1);
      expect(svc.deleteCalls.single.$1, ['aaa']);
      expect(svc.deleteCalls.single.$2, isFalse);
    });

    test('勾选时：拆成两组分别调用，deleteFiles 标志正确', () async {
      // a: 无辅种 → 删文件；b/c: 互为辅种但本次只删 b → 保留文件
      final ta = torrent(
        id: 'a',
        hash: 'aaa',
        contentPath: '/data/A',
      )..totalSize = 1000;
      final tb = torrent(
        id: 'b',
        hash: 'bbb',
        contentPath: '/data/Movie',
      )..totalSize = 2000;
      final tc = torrent(
        id: 'c',
        hash: 'ccc',
        contentPath: '/data/Movie',
      )..totalSize = 2000;
      final svc = _FakeTorrentService.success([ta, tb, tc]);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final ok = await p.deleteTorrentsSmart(
        qb,
        ['aaa', 'bbb'],
        deleteFilesWhenNoCrossSeed: true,
      );
      expect(ok, isTrue);
      expect(svc.deleteCalls.length, 2);
      // 一组 deleteFiles=true（aaa），一组 deleteFiles=false（bbb）
      final byFlag = {
        for (final c in svc.deleteCalls) c.$2: c.$1,
      };
      expect(byFlag[true], containsAll(['aaa']));
      expect(byFlag[false], containsAll(['bbb']));
    });
  });

  // ---- 在线状态测试 ----

  test(
    'marks client online when torrent API succeeds with an empty list',
    () async {
      final provider = TorrentProvider(
        serviceResolver: (_) => _FakeTorrentService.success(const []),
      );
      final qb = client('qb');

      await provider.refreshTorrents([qb], showLoading: false);

      expect(provider.allTorrents, isEmpty);
      expect(provider.lastRefreshOnlineStatus[qb.id], isTrue);
    },
  );

  test('marks client offline when torrent API throws', () async {
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.failure(Exception('offline')),
    );
    final qb = client('qb');

    await provider.refreshTorrents([qb], showLoading: false);

    expect(provider.allTorrents, isEmpty);
    expect(provider.lastRefreshOnlineStatus[qb.id], isFalse);
  });

  // ---- 并行拉取测试 ----

  test('parallel fetching: mixed success/failure across clients', () async {
    ClientConfig qbClient(String id) => ClientConfig(
      id: id,
      name: 'Client $id',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
    );
    ClientConfig trClient(String id) => ClientConfig(
      id: id,
      name: 'Client $id',
      type: ClientType.transmission,
      host: '127.0.0.2',
      port: 9091,
    );
    final qb = qbClient('qb');
    final tr = trClient('tr');
    final successService = _FakeTorrentService.success([
      torrent(id: 't1', hash: 'aaa'),
    ]);
    final failService = _FakeTorrentService.failure(Exception('offline'));

    final provider = TorrentProvider(
      serviceResolver: (type) =>
          type == ClientType.qBittorrent ? successService : failService,
    );

    await provider.refreshTorrents([qb, tr], showLoading: false);

    expect(provider.allTorrents, hasLength(1));
    expect(provider.lastRefreshOnlineStatus[qb.id], isTrue);
    expect(provider.lastRefreshOnlineStatus[tr.id], isFalse);
  });

  // ---- 单次遍历过滤测试 ----

  group('filteredTorrents single-pass filtering', () {
    late ClientConfig qb;

    setUp(() {
      qb = client('qb');
    });

    test('returns all torrents when no filter is applied', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Linux ISO',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Ubuntu ISO',
        state: TorrentState.seeding,
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      expect(p.filteredTorrents, hasLength(2));
    });

    test('filters by state', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Linux ISO',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Ubuntu ISO',
        state: TorrentState.seeding,
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      p.setStateFilter({TorrentState.downloading});
      expect(p.filteredTorrents, hasLength(1));
      expect(p.filteredTorrents.single.id, '1');
    });

    test('filters by search query', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Linux ISO',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Ubuntu ISO',
        state: TorrentState.seeding,
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      p.setSearchQuery('linux');
      expect(p.filteredTorrents, hasLength(1));
      expect(p.filteredTorrents.single.name, 'Linux ISO');
    });

    test('filters by error only', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Good',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Bad',
        state: TorrentState.error,
        error: 'fail',
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      p.setErrorOnly(true);
      expect(p.filteredTorrents, hasLength(1));
      expect(p.filteredTorrents.single.id, '2');
    });

    test('combines state and search filters', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Linux ISO',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Ubuntu ISO',
        state: TorrentState.seeding,
      );
      final t3 = torrent(
        id: '3',
        hash: 'c',
        name: 'Linux Mint',
        state: TorrentState.seeding,
      );
      final mockService = _FakeTorrentService.success([t1, t2, t3]);
      final p = TorrentProvider(serviceResolver: (_) => mockService);
      await p.refreshTorrents([qb], showLoading: false);

      p.setStateFilter({TorrentState.seeding});
      p.setSearchQuery('linux');
      expect(p.filteredTorrents, hasLength(1));
      expect(p.filteredTorrents.single.name, 'Linux Mint');
    });
  });

  // ---- 缓存 errorCount 测试 ----

  test('errorCount caches result from refresh', () async {
    final t1 = torrent(
      id: '1',
      hash: 'a',
      name: 'Good',
      state: TorrentState.downloading,
    );
    final t2 = torrent(
      id: '2',
      hash: 'b',
      name: 'Error File',
      state: TorrentState.error,
      error: 'IO error',
    );
    final mockService = _FakeTorrentService.success([t1, t2]);
    final qb = client('qb');
    final provider = TorrentProvider(serviceResolver: (_) => mockService);

    await provider.refreshTorrents([qb], showLoading: false);
    expect(provider.errorCount, 1);

    // 再次刷新，数据变化
    final mockService2 = _FakeTorrentService.success([t1]);
    final provider2 = TorrentProvider(serviceResolver: (_) => mockService2);
    await provider2.refreshTorrents([qb], showLoading: false);
    expect(provider2.errorCount, 0);
  });

  test('errorCount is zero when no torrents are in error state', () async {
    final t1 = torrent(
      id: '1',
      hash: 'a',
      name: 'Good DL',
      state: TorrentState.downloading,
    );
    final t2 = torrent(
      id: '2',
      hash: 'b',
      name: 'Good Seed',
      state: TorrentState.seeding,
    );
    final mockService = _FakeTorrentService.success([t1, t2]);
    final qb = client('qb');
    final provider = TorrentProvider(serviceResolver: (_) => mockService);

    await provider.refreshTorrents([qb], showLoading: false);
    expect(provider.errorCount, 0);
  });

  // ---- 空守卫测试 ----

  test('setSearchQuery no-op guard prevents duplicate notification', () async {
    final qb = client('qb');
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.success(const []),
    );
    await provider.refreshTorrents([qb], showLoading: false);

    int notifyCount = 0;
    provider.addListener(() => notifyCount++);

    provider.setSearchQuery('test');
    // 搜索有 200ms 防抖，先更新值但不立即通知
    expect(provider.searchQuery, 'test');
    expect(notifyCount, 0);

    // 等待防抖触发
    await Future.delayed(const Duration(milliseconds: 250));
    expect(notifyCount, 1);

    // 相同的查询不应触发额外通知
    provider.setSearchQuery('test');
    await Future.delayed(const Duration(milliseconds: 250));
    expect(notifyCount, 1);
  });

  test(
    'setStateTabIndex changes to a different index triggers notification',
    () async {
      final qb = client('qb');
      final provider = TorrentProvider(
        serviceResolver: (_) => _FakeTorrentService.success(const []),
      );
      await provider.refreshTorrents([qb], showLoading: false);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      // 切换到下载中标签
      provider.setStateTabIndex(1);
      expect(notifyCount, 1);

      // 再次切换相同标签不应触发通知
      provider.setStateTabIndex(1);
      expect(notifyCount, 1);

      // 切换到不同标签
      provider.setStateTabIndex(2);
      expect(notifyCount, 2);
    },
  );

  test('setClientFilter no-op guard prevents duplicate notification', () async {
    final qb = client('qb');
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.success(const []),
    );
    await provider.refreshTorrents([qb], showLoading: false);

    int notifyCount = 0;
    provider.addListener(() => notifyCount++);

    provider.setClientFilter('client-1');
    expect(notifyCount, 1);

    provider.setClientFilter('client-1');
    expect(notifyCount, 1);
  });

  test(
    'setStateFilter no-op guard compares set contents, not references',
    () async {
      final qb = client('qb');
      final provider = TorrentProvider(
        serviceResolver: (_) => _FakeTorrentService.success(const []),
      );
      await provider.refreshTorrents([qb], showLoading: false);

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setStateFilter({TorrentState.downloading});
      expect(notifyCount, 1);

      // 相同内容的 Set（不同实例）不应触发通知
      provider.setStateFilter({TorrentState.downloading});
      expect(notifyCount, 1);

      // 不同的 Set 内容应触发通知
      provider.setStateFilter({TorrentState.seeding});
      expect(notifyCount, 2);
    },
  );

  test('setErrorOnly no-op guard prevents duplicate notification', () async {
    final qb = client('qb');
    final provider = TorrentProvider(
      serviceResolver: (_) => _FakeTorrentService.success(const []),
    );
    await provider.refreshTorrents([qb], showLoading: false);

    int notifyCount = 0;
    provider.addListener(() => notifyCount++);

    provider.setErrorOnly(true);
    expect(notifyCount, 1);

    provider.setErrorOnly(true);
    expect(notifyCount, 1);

    provider.setErrorOnly(false);
    expect(notifyCount, 2);
  });

  // ---- 批量操作测试 ----

  group('batch torrent operations', () {
    test('pauseTorrents calls service batch method and returns true', () async {
      final qb = client('qb');
      final service = _FakeTorrentService.success(const []);
      final provider = TorrentProvider(serviceResolver: (_) => service);
      await provider.refreshTorrents([qb], showLoading: false);

      final result = await provider.pauseTorrents(qb, ['a', 'b', 'c']);
      expect(result, isTrue);
    });

    test(
      'resumeTorrents calls service batch method and returns true',
      () async {
        final qb = client('qb');
        final service = _FakeTorrentService.success(const []);
        final provider = TorrentProvider(serviceResolver: (_) => service);
        await provider.refreshTorrents([qb], showLoading: false);

        final result = await provider.resumeTorrents(qb, ['a', 'b']);
        expect(result, isTrue);
      },
    );

    test(
      'deleteTorrents calls service batch method with deleteFiles flag',
      () async {
        final qb = client('qb');
        final service = _FakeTorrentService.success(const []);
        final provider = TorrentProvider(serviceResolver: (_) => service);
        await provider.refreshTorrents([qb], showLoading: false);

        final result = await provider.deleteTorrents(qb, [
          'a',
        ], deleteFiles: true);
        expect(result, isTrue);
      },
    );

    test('clearAllFilters clears cached lowercase search query', () async {
      final t1 = torrent(
        id: '1',
        hash: 'a',
        name: 'Linux ISO',
        state: TorrentState.downloading,
      );
      final t2 = torrent(
        id: '2',
        hash: 'b',
        name: 'Ubuntu ISO',
        state: TorrentState.seeding,
      );
      final mockService = _FakeTorrentService.success([t1, t2]);
      final qb = client('qb');
      final provider = TorrentProvider(serviceResolver: (_) => mockService);
      await provider.refreshTorrents([qb], showLoading: false);

      provider.setSearchQuery('linux');
      // 等待防抖
      await Future.delayed(const Duration(milliseconds: 250));
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

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.setSearchQuery('test');
      // 在防抖触发前 dispose
      provider.dispose();

      // 等待超过防抖时间
      await Future.delayed(const Duration(milliseconds: 250));
      expect(notifyCount, 0);
    });

    test('batch operations return false on service error', () async {
      final qb = client('qb');
      final failService = _FakeTorrentService(throwsOnBatch: true);
      final provider = TorrentProvider(serviceResolver: (_) => failService);
      await provider.refreshTorrents([qb], showLoading: false);

      final result = await provider.pauseTorrents(qb, ['a']);
      expect(result, isFalse);
    });
  });
}
