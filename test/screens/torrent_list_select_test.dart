import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:bit_manager/models/torrent.dart';
import 'package:bit_manager/providers/client_provider.dart';
import 'package:bit_manager/providers/torrent_provider.dart';
import 'package:bit_manager/screens/torrent_list_screen.dart';
import 'package:bit_manager/services/torrent_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 最小 fake：返回一个种子，其余方法空实现
class _FakeService implements ITorrentClientService {
  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async => [
    Torrent(
      id: '1',
      hash: 'aaa',
      name: 'Test',
      clientId: config.id,
      clientType: config.type,
      state: TorrentState.downloading,
      trackerStatuses: const ['2'],
    ),
  ];

  @override
  Future<bool> testConnection(ClientConfig config) async => true;
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
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes) async {}
  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {}
  @override
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes) async {}
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
  }) async {}
  @override
  Future<void> replaceTracker(
    ClientConfig config,
    String hash,
    String oldUrl,
    String newUrl,
  ) async {}
  @override
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl) async {}
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
    online: true,
  );
  @override
  Future<int> getFreeSpace(ClientConfig config) async => 0;
  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async => [0, 0];
  @override
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {}
  @override
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {}
  @override
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  ) async {}
}

void main() {
  testWidgets('长按进入选择模式，全选与取消全选正常工作', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final clientProvider = ClientProvider();
    await clientProvider.addClient(
      ClientConfig(
        id: 'client-1',
        name: 'Client 1',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      ),
    );
    final torrentProvider = TorrentProvider(
      serviceResolver: (_) => _FakeService(),
    );
    await torrentProvider.refreshTorrents(
      clientProvider.activeClients,
      showLoading: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClientProvider>.value(value: clientProvider),
          ChangeNotifierProvider<TorrentProvider>.value(value: torrentProvider),
        ],
        child: const MaterialApp(home: TorrentListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 点击前：没有批量栏
    expect(find.textContaining('已选'), findsNothing);

    // AppBar「全选」按钮：未选时点击 = 进入选择模式 + 全选当前筛选结果
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();

    // 顶部批量栏出现，已选 1 个
    expect(find.textContaining('已选'), findsOneWidget);
    expect(torrentProvider.selectMode, isTrue);
    expect(torrentProvider.selectedCount, 1);

    // 此时 AppBar 按钮图标变为 deselect（取消全选）
    expect(find.byIcon(Icons.deselect), findsOneWidget);

    // 点「取消全选」(AppBar) → 退出选择模式、批量栏消失
    await tester.tap(find.byIcon(Icons.deselect));
    await tester.pumpAndSettle();
    expect(torrentProvider.selectMode, isFalse);
    expect(find.textContaining('已选'), findsNothing);
  });

  testWidgets('选中后点操作按钮弹出批量操作面板', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final clientProvider = ClientProvider();
    await clientProvider.addClient(
      ClientConfig(
        id: 'client-1',
        name: 'Client 1',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      ),
    );
    final torrentProvider = TorrentProvider(serviceResolver: (_) => _FakeService());
    await torrentProvider.refreshTorrents(
      clientProvider.activeClients,
      showLoading: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClientProvider>.value(value: clientProvider),
          ChangeNotifierProvider<TorrentProvider>.value(value: torrentProvider),
        ],
        child: const MaterialApp(home: TorrentListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 全选进入选择模式
    await tester.tap(find.byIcon(Icons.select_all));
    await tester.pumpAndSettle();

    // 点浮动按钮弹出面板
    await tester.tap(find.textContaining('操作'));
    await tester.pumpAndSettle();

    // 面板含 4 类入口
    expect(find.text('暂停选中'), findsOneWidget);
    expect(find.text('恢复选中'), findsOneWidget);
    expect(find.text('删除选中'), findsOneWidget);
    expect(find.text('添加 Tracker'), findsOneWidget);
  });
}
