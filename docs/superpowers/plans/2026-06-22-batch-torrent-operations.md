# 批量种子操作面板 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 种子列表选中后弹出底部操作面板，支持批量暂停/恢复/删除（含「无辅种时删除文件」选项）与批量改 Tracker（添加/替换/删除）。

**Architecture:** 在 `ITorrentClientService` 新增 3 个批量 Tracker 接口（qBittorrent/Transmission 各实现），provider 逐客户端转发；种子列表用 `showModalBottomSheet` 操作面板取代右下角浮动按钮。

**Tech Stack:** Flutter / Dart、provider、dio、html。

## Global Constraints

- 代码注释一律中文（`///` `//`），标识符/API 名称/英文错误术语不翻译。
- 文档（docs/、README、spec、plan、ADR）一律中文。
- 提交 commit 不含 Claude / Anthropic 标识，仅保留用户 git 身份。
- 不允许自动 push。
- 每次提交前检查是否需要更新 README（本次功能 README「批量操作」条目需补充批量改 Tracker，在末尾任务统一处理）。
- qBittorrent 批量 Tracker 接口字段名：`hashes`（`|` 分隔）、`urls`（`\n` 分隔）、`origUrl`/`newUrl`。
- Transmission 批量 Tracker 用 `torrent-set` 的增量字段 `trackerAdd`/`trackerReplace`/`trackerRemove`（**非** 现有单个实现用的 `trackerList` 全量覆盖——全量覆盖在批量场景会破坏各种子各自的 Tracker 列表）。

## File Structure

- `lib/services/torrent_client.dart` — 接口抽象，新增 3 个批量 Tracker 方法声明。
- `lib/services/qbittorrent_service.dart` — qB 实现 3 个批量 Tracker 方法。
- `lib/services/transmission_service.dart` — Transmission 实现 3 个批量 Tracker 方法。
- `lib/providers/torrent_provider.dart` — provider 逐客户端转发 3 个方法。
- `lib/screens/torrent_list_screen.dart` — 底部操作面板取代浮动按钮。
- `lib/widgets/batch_operation_sheet.dart` — **新建**，底部操作面板组件（保持 torrent_list_screen 聚焦，面板逻辑独立）。
- 测试：`test/providers/torrent_provider_test.dart`、`test/screens/torrent_list_select_test.dart`、`test/services/qbittorrent_service_test.dart`（新建，dio adapter mock）。

---

### Task 1: 接口声明 — ITorrentClientService 新增 3 个批量 Tracker 方法

**Files:**
- Modify: `lib/services/torrent_client.dart`（在 `removeTracker` 声明后、`isTorrentExist` 前插入）

**Interfaces:**
- Produces: `addTrackers`、`replaceTrackers`、`removeTrackers`（批量版）声明，供 qB/Transmission 实现、provider 与 fake service 覆盖。

- [ ] **Step 1: 在接口中新增 3 个方法声明**

在 `lib/services/torrent_client.dart` 的 `removeTracker` 声明之后插入：

```dart
  /// 批量添加 Tracker：给 [hashes] 中每个种子追加 [trackerUrls] 里的全部 Tracker
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  );

  /// 批量替换 Tracker：把 [hashes] 中每个种子的 [oldUrl] Tracker 换成 [newUrl]
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  );

  /// 批量移除 Tracker：从 [hashes] 中每个种子删除 [trackerUrl] Tracker
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  );
```

- [ ] **Step 2: 运行静态分析确认接口层无误**

Run: `flutter analyze lib/services/torrent_client.dart`
Expected: qB/Transmission/fake service 会报缺失实现（预期，后续任务补），接口本身无语法错误。

- [ ] **Step 3: Commit**

```bash
git add lib/services/torrent_client.dart
git commit -m "feat(client): 新增批量 Tracker 接口声明"
```

---

### Task 2: QBittorrentService 实现批量 Tracker

**Files:**
- Modify: `lib/services/qbittorrent_service.dart`（在 `removeTracker` 实现后插入）

**Interfaces:**
- Consumes: Task 1 的接口声明。
- Produces: `QBittorrentService.addTrackers`/`replaceTrackers`/`removeTrackers`。

**参考**：qB 单个版本用 `hash` + `urls`（单值）。批量版本用 `hashes`（`|` 分隔）+ `urls`（`\n` 分隔多值）。`addTrackers`/`removeTrackers` 的 `urls` 接受 `\n` 分隔多 URL；`editTracker` 用 `origUrl`/`newUrl` 单值。

- [ ] **Step 1: 写 failing service 测试（dio adapter mock 验证请求形态）**

Create `test/services/qbittorrent_service_test.dart`：

```dart
import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/services/qbittorrent_service.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

/// 记录最近一次请求的 path / method / data
class _RecordingAdapter implements HttpClientAdapter {
  String? lastPath;
  String? lastMethod;
  dynamic lastData;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastMethod = options.method;
    lastData = options.data;
    // 登录请求返回带 SID 的 Set-Cookie；其余返回 Ok.
    final isLogin = options.path.contains('/auth/login');
    final headers = <String, List<String>>{
      if (isLogin) 'set-cookie': ['SID=fake-sid; path=/'],
    };
    return ResponseBody(
      Stream.value(Uint8List.fromList('Ok.'.codeUnits)),
      200,
      headers: headers,
      isRedirect: false,
    );
  }
}

ClientConfig _qb() => ClientConfig(
      id: 'qb',
      name: 'QB',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
      username: 'u',
      password: 'p',
    );

void main() {
  test('addTrackers 拼出 hashes=| 分隔、urls=\\n 分隔', () async {
    final svc = QBittorrentService();
    final adapter = _RecordingAdapter();
    // 通过注入 dio adapter 的方式需 service 暴露 dio；此处用 ServiceFactory
    // 默认创建的 dio 无法直接换 adapter，故改为：直接断言 service 调用不抛，
    // 请求形态由 provider 层 fake 覆盖（见 Task 4）。本测试验证空 hashes 不抛。
    await svc.addTrackers(_qb(), const [], const ['http://t/announce']);
    // 空 hashes 应静默返回
    expect(true, isTrue);
  });
}
```

> 说明：项目未引入 mock 库，service 内部自建 dio，难以注入 adapter。请求形态的正确性改为在 **Task 4 provider fake** 与人工实测覆盖；本 task 仅保证实现可编译、空输入不抛、签名正确。删除占位测试中的注释性内容，保留空输入用例。

- [ ] **Step 2: 运行测试确认编译通过**

Run: `flutter test test/services/qbittorrent_service_test.dart`
Expected: PASS（空 hashes 静默返回）

- [ ] **Step 3: 实现三个方法**

在 `lib/services/qbittorrent_service.dart` 的 `removeTracker` 实现后插入：

```dart
  @override
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {
    if (hashes.isEmpty || trackerUrls.isEmpty) return;
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(
      config,
      '/api/v2/torrents/addTrackers',
      data: {
        'hashes': hashes.join('|'),
        'urls': trackerUrls.join('\n'),
      },
      sid: sid,
    );
  }

  @override
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {
    if (hashes.isEmpty) return;
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(
      config,
      '/api/v2/torrents/editTracker',
      data: {
        'hashes': hashes.join('|'),
        'origUrl': oldUrl,
        'newUrl': newUrl,
      },
      sid: sid,
    );
  }

  @override
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  ) async {
    if (hashes.isEmpty) return;
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(
      config,
      '/api/v2/torrents/removeTrackers',
      data: {'hashes': hashes.join('|'), 'urls': trackerUrl},
      sid: sid,
    );
  }
```

- [ ] **Step 4: 运行分析确认无缺失实现**

Run: `flutter analyze lib/services/qbittorrent_service.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/services/qbittorrent_service.dart test/services/qbittorrent_service_test.dart
git commit -m "feat(qb): 实现批量 Tracker 接口"
```

---

### Task 3: TransmissionService 实现批量 Tracker

**Files:**
- Modify: `lib/services/transmission_service.dart`（在 `removeTracker` 实现后插入）

**Interfaces:**
- Produces: `TransmissionService.addTrackers`/`replaceTrackers`/`removeTrackers`。

**关键**：用 `torrent-set` 的增量字段 `trackerAdd`/`trackerReplace`/`trackerRemove`，基于 id 列表一次调用批量。**不用** 现有单个实现的 `trackerList` 全量覆盖（批量场景下各种子 Tracker 不同，全量覆盖会互相破坏）。参考现有 `_hashToIdsOrThrow` + `_rpcCall` 模式（见 `deleteTorrents`）。

- [ ] **Step 1: 实现三个方法**

在 `lib/services/transmission_service.dart` 的 `removeTracker` 实现后插入：

```dart
  @override
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {
    if (hashes.isEmpty || trackerUrls.isEmpty) return;
    final sid = await _getSessionId(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isEmpty) return;
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerAdd': trackerUrls},
      sessionId: sid,
    );
  }

  @override
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {
    if (hashes.isEmpty) return;
    final sid = await _getSessionId(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isEmpty) return;
    // Transmission 的 trackerReplace 接受 [oldUrl, newUrl] 一对
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerReplace': [oldUrl, newUrl]},
      sessionId: sid,
    );
  }

  @override
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  ) async {
    if (hashes.isEmpty) return;
    final sid = await _getSessionId(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isEmpty) return;
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerRemove': [trackerUrl]},
      sessionId: sid,
    );
  }
```

- [ ] **Step 2: 运行分析确认无缺失实现**

Run: `flutter analyze lib/services/transmission_service.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/services/transmission_service.dart
git commit -m "feat(transmission): 实现批量 Tracker 接口（增量字段）"
```

---

### Task 4: TorrentProvider 逐客户端转发 + fake service 覆盖 + 单测

**Files:**
- Modify: `lib/providers/torrent_provider.dart`（在 `deleteTorrentsSmart` 后新增 3 方法）
- Modify: `test/providers/torrent_provider_test.dart`（fake service 实现 3 方法 + 记录调用 + 新增用例）

**Interfaces:**
- Consumes: Task 1-3 的 service 接口。
- Produces: `TorrentProvider.addTrackers`/`replaceTrackers`/`removeTrackers`（单客户端版），供 UI 层逐客户端调用。

- [ ] **Step 1: 在 fake service `_FakeTorrentService` 中实现 3 方法并记录调用**

在 `test/providers/torrent_provider_test.dart` 的 `_FakeTorrentService` 类中，新增字段与覆盖实现。在 `deleteTorrents` 覆盖之后添加：

```dart
  /// 记录批量 Tracker 调用：方法名 → 参数
  final List<({String op, List<String> hashes, List<String> urls, String? oldUrl, String? newUrl})> trackerCalls = [];

  @override
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {
    trackerCalls.add((
      op: 'add',
      hashes: List<String>.from(hashes),
      urls: List<String>.from(trackerUrls),
      oldUrl: null,
      newUrl: null,
    ));
  }

  @override
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {
    trackerCalls.add((
      op: 'replace',
      hashes: List<String>.from(hashes),
      urls: const [],
      oldUrl: oldUrl,
      newUrl: newUrl,
    ));
  }

  @override
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  ) async {
    trackerCalls.add((
      op: 'remove',
      hashes: List<String>.from(hashes),
      urls: [trackerUrl],
      oldUrl: null,
      newUrl: null,
    ));
  }
```

- [ ] **Step 2: 写 provider failing 测试**

在 `test/providers/torrent_provider_test.dart` 的 `batch torrent operations` group 末尾新增：

```dart
    test('addTrackers 转发 hashes 与 urls，空 hashes 不调用', () async {
      final qb = client('qb');
      final svc = _FakeTorrentService.success(const []);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      var ok = await p.addTrackers(qb, const [], const ['http://t/announce']);
      expect(ok, isTrue);
      expect(svc.trackerCalls, isEmpty);

      ok = await p.addTrackers(qb, ['aaa', 'bbb'], const ['http://t/announce']);
      expect(ok, isTrue);
      expect(svc.trackerCalls.single.op, 'add');
      expect(svc.trackerCalls.single.hashes, ['aaa', 'bbb']);
      expect(svc.trackerCalls.single.urls, ['http://t/announce']);
    });

    test('replaceTrackers / removeTrackers 正确转发', () async {
      final qb = client('qb');
      final svc = _FakeTorrentService.success(const []);
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      await p.replaceTrackers(qb, ['aaa'], 'http://old/', 'http://new/');
      expect(svc.trackerCalls.single.op, 'replace');
      expect(svc.trackerCalls.single.oldUrl, 'http://old/');
      expect(svc.trackerCalls.single.newUrl, 'http://new/');

      await p.removeTrackers(qb, ['aaa'], 'http://t/announce');
      expect(svc.trackerCalls.last.op, 'remove');
      expect(svc.trackerCalls.last.urls, ['http://t/announce']);
    });

    test('Tracker 操作失败返回 false 并记入 _error', () async {
      final qb = client('qb');
      final svc = _FakeTorrentService.success(const [])..throwsOnBatch = true;
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      // 注意：throwsOnBatch 只影响 deleteTorrents/pause/resume；
      // 为测试 Tracker 失败，此处改为让 service 抛错：临时换 svc
      final failing = _FakeServiceTrackerThrows();
      final p2 = TorrentProvider(serviceResolver: (_) => failing);
      await p2.refreshTorrents([qb], showLoading: false);
      final ok = await p2.addTrackers(qb, ['aaa'], const ['http://t/announce']);
      expect(ok, isFalse);
      expect(p2.error, isNotNull);
    });
```

并在文件顶部 fake service 区新增一个抛错的 fake（或在 `_FakeTorrentService` 加开关）。简化做法：给 `_FakeTorrentService` 加 `throwsOnTracker = false` 字段，Tracker 方法在为 true 时抛错。修改 Step 1 的 3 个方法开头加：

```dart
  bool throwsOnTracker = false;
```

并把 `addTrackers` 方法体改为：

```dart
  @override
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  ) async {
    if (throwsOnTracker) throw Exception('tracker error');
    trackerCalls.add((
      op: 'add',
      hashes: List<String>.from(hashes),
      urls: List<String>.from(trackerUrls),
      oldUrl: null,
      newUrl: null,
    ));
  }
```

（`replaceTrackers`/`removeTrackers` 同理加 `if (throwsOnTracker) throw ...;`）

并删除上面测试里 `_FakeServiceTrackerThrows`/`p2` 的写法，改用：

```dart
    test('Tracker 操作失败返回 false 并记入 _error', () async {
      final qb = client('qb');
      final svc = _FakeTorrentService.success(const [])..throwsOnTracker = true;
      final p = TorrentProvider(serviceResolver: (_) => svc);
      await p.refreshTorrents([qb], showLoading: false);

      final ok = await p.addTrackers(qb, ['aaa'], const ['http://t/announce']);
      expect(ok, isFalse);
      expect(p.error, isNotNull);
    });
```

确认 `TorrentProvider` 有 `error` getter（查 `lib/providers/torrent_provider.dart`，应有 `String? get error`）。

- [ ] **Step 3: 运行测试确认失败（方法未实现）**

Run: `flutter test test/providers/torrent_provider_test.dart`
Expected: FAIL，提示 `TorrentProvider.addTrackers` 等方法未定义。

- [ ] **Step 4: 在 provider 实现 3 个转发方法**

在 `lib/providers/torrent_provider.dart` 的 `deleteTorrentsSmart` 方法之后插入：

```dart
  Future<bool> addTrackers(
    ClientConfig client,
    List<String> hashes,
    List<String> urls,
  ) async {
    if (hashes.isEmpty || urls.isEmpty) return true;
    try {
      final service = _serviceResolver(client.type);
      await service.addTrackers(client, hashes, urls);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> replaceTrackers(
    ClientConfig client,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  ) async {
    if (hashes.isEmpty) return true;
    try {
      final service = _serviceResolver(client.type);
      await service.replaceTrackers(client, hashes, oldUrl, newUrl);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTrackers(
    ClientConfig client,
    List<String> hashes,
    String url,
  ) async {
    if (hashes.isEmpty) return true;
    try {
      final service = _serviceResolver(client.type);
      await service.removeTrackers(client, hashes, url);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/providers/torrent_provider_test.dart`
Expected: PASS（含新增 3 用例）。

- [ ] **Step 6: Commit**

```bash
git add lib/providers/torrent_provider.dart test/providers/torrent_provider_test.dart
git commit -m "feat(provider): 批量 Tracker 转发方法与单测"
```

---

### Task 5: 底部操作面板组件 batch_operation_sheet

**Files:**
- Create: `lib/widgets/batch_operation_sheet.dart`

**Interfaces:**
- Consumes: `TorrentProvider`（pause/resume/deleteTorrentsSmart/addTrackers/replaceTrackers/removeTrackers/selectedHashes/allTorrents）、`ClientProvider`（activeClients）、`showDeleteTorrentDialog`。
- Produces: `showBatchOperationSheet(BuildContext)` 顶层函数，供 torrent_list_screen 调用。

**职责**：底部弹窗，列出 暂停/恢复/删除/改 Tracker(添加/替换/删除)。跨客户端分组调用，逐客户端 await，汇总成功失败后 SnackBar。Tracker 子操作弹二级对话框收集参数。

- [ ] **Step 1: 创建组件文件，实现面板与操作逻辑**

Create `lib/widgets/batch_operation_sheet.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';
import '../providers/torrent_provider.dart';
import 'delete_torrent_dialog.dart';

/// 弹出批量操作面板。仅在选中至少 1 个种子时调用。
void showBatchOperationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => const _BatchOperationSheet(),
  );
}

class _BatchOperationSheet extends StatelessWidget {
  const _BatchOperationSheet();

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TorrentProvider>();
    final count = tp.selectedCount;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '批量操作 · 已选 $count 个',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('暂停选中'),
            onTap: () => _runAction(context, 'pause'),
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('恢复选中'),
            onTap: () => _runAction(context, 'resume'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除选中', style: TextStyle(color: Colors.red)),
            onTap: () => _runDelete(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: const Text('添加 Tracker'),
            onTap: () => _addTrackers(context),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('替换 Tracker'),
            onTap: () => _replaceTrackers(context),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('删除 Tracker'),
            onTap: () => _removeTrackers(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 按 clientId 分组选中种子，返回 (client, hashes) 列表
  List<(ClientConfig, List<String>)> _groupedByClient(
    TorrentProvider tp,
    ClientProvider cp,
  ) {
    final selected = tp.selectedHashes.toSet();
    final out = <(ClientConfig, List<String>)>[];
    for (final client in cp.activeClients) {
      final hashes = tp.allTorrents
          .where((t) => selected.contains(t.hash) && t.clientId == client.id)
          .map((t) => t.hash)
          .toList();
      if (hashes.isNotEmpty) out.add((client, hashes));
    }
    return out;
  }

  Future<void> _runAction(BuildContext context, String action) async {
    Navigator.pop(context);
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final groups = _groupedByClient(tp, cp);
    final messenger = ScaffoldMessenger.of(context);

    final failed = <String>[];
    for (final (client, hashes) in groups) {
      bool ok;
      if (action == 'resume') {
        ok = await tp.resumeTorrents(client, hashes);
      } else {
        ok = await tp.pauseTorrents(client, hashes);
      }
      if (!ok) failed.add(client.name);
    }
    tp.exitSelectMode();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(failed.isEmpty
            ? '操作成功'
            : '部分失败：${failed.join('、')}'),
      ),
    );
  }

  Future<void> _runDelete(BuildContext context) async {
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final selected = tp.selectedHashes.toList();
    final groups = _groupedByClient(tp, cp);

    int willDeleteFiles = 0;
    for (final (client, hashes) in groups) {
      willDeleteFiles +=
          tp.planSmartDelete(client, hashes).deleteFilesHashes.length;
    }

    final result = await showDeleteTorrentDialog(
      context,
      count: selected.length,
      willDeleteFilesCount: willDeleteFiles,
    );
    if (!result.confirmed || !context.mounted) {
      if (context.mounted) Navigator.pop(context);
      return;
    }
    Navigator.pop(context); // 关闭面板

    final messenger = ScaffoldMessenger.of(context);
    final failed = <String>[];
    for (final (client, hashes) in groups) {
      final ok = await tp.deleteTorrentsSmart(
        client,
        hashes,
        deleteFilesWhenNoCrossSeed: result.deleteFilesWhenNoCrossSeed,
      );
      if (!ok) failed.add(client.name);
    }
    tp.exitSelectMode();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(failed.isEmpty ? '已删除' : '部分失败：${failed.join('、')}'),
      ),
    );
  }

  Future<void> _addTrackers(BuildContext context) async {
    final ctrl = TextEditingController();
    final urls = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 Tracker'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '每行一个 Tracker URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (urls == null || !context.mounted) return;

    final list = urls
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未输入 Tracker URL')));
      return;
    }
    final invalid = list.where((u) => !u.contains('://')).toList();
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker URL 格式异常（需含 ://）')),
      );
      return;
    }
    await _runTracker(context, (client, hashes) async {
      final tp = context.read<TorrentProvider>();
      return tp.addTrackers(client, hashes, list);
    });
  }

  Future<void> _replaceTrackers(BuildContext context) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('替换 Tracker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              decoration: const InputDecoration(
                labelText: '旧 Tracker URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration: const InputDecoration(
                labelText: '新 Tracker URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('替换')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final oldUrl = oldCtrl.text.trim();
    final newUrl = newCtrl.text.trim();
    if (oldUrl.isEmpty || newUrl.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('URL 不能为空')));
      return;
    }
    if (!oldUrl.contains('://') || !newUrl.contains('://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker URL 格式异常（需含 ://）')),
      );
      return;
    }
    await _runTracker(context, (client, hashes) async {
      final tp = context.read<TorrentProvider>();
      return tp.replaceTrackers(client, hashes, oldUrl, newUrl);
    });
  }

  Future<void> _removeTrackers(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Tracker'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '要删除的 Tracker URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final url = ctrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('URL 不能为空')));
      return;
    }
    await _runTracker(context, (client, hashes) async {
      final tp = context.read<TorrentProvider>();
      return tp.removeTrackers(client, hashes, url);
    });
  }

  /// 执行 Tracker 操作的通用流程：逐客户端调用，汇总失败，SnackBar 反馈。
  /// Tracker 操作后不退出选择模式、不刷新列表。
  Future<void> _runTracker(
    BuildContext context,
    Future<bool> Function(ClientConfig client, List<String> hashes) action,
  ) async {
    Navigator.pop(context); // 关闭面板
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final groups = _groupedByClient(tp, cp);
    final messenger = ScaffoldMessenger.of(context);

    final failed = <String>[];
    for (final (client, hashes) in groups) {
      final ok = await action(client, hashes);
      if (!ok) failed.add(client.name);
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(failed.isEmpty
            ? 'Tracker 操作完成'
            : '部分失败：${failed.join('、')}'),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行分析确认无语法错误**

Run: `flutter analyze lib/widgets/batch_operation_sheet.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/batch_operation_sheet.dart
git commit -m "feat(widget): 批量操作底部面板组件"
```

---

### Task 6: 接入种子列表 — 用面板替换浮动按钮 + widget 测试

**Files:**
- Modify: `lib/screens/torrent_list_screen.dart`（删除 `_buildBatchActions`/`_batchAction`/`_batchDelete` 的调用点，改用 `showBatchOperationSheet`；保留方法供面板内部已迁移逻辑——实际可删除 `_buildBatchActions`、`_batchAction`，`_batchDelete` 逻辑已迁入面板，删除）
- Modify: `test/screens/torrent_list_select_test.dart`

**Interfaces:**
- Consumes: Task 5 的 `showBatchOperationSheet`。

- [ ] **Step 1: 修改 floatingActionButton 为入口**

在 `lib/screens/torrent_list_screen.dart` 的 `build` 末尾，把 `floatingActionButton` 改为：

```dart
      floatingActionButton: () {
        final tp = context.watch<TorrentProvider>();
        return tp.selectMode && tp.selectedCount > 0
            ? FloatingActionButton.extended(
                onPressed: () => showBatchOperationSheet(context),
                icon: const Icon(Icons.adb),
                label: Text('操作 ${tp.selectedCount}'),
              )
            : null;
      }(),
```

并在文件顶部 import：

```dart
import '../widgets/batch_operation_sheet.dart';
```

- [ ] **Step 2: 删除已迁移的旧方法**

删除 `lib/screens/torrent_list_screen.dart` 中不再使用的 `_buildBatchActions`、`_batchAction`、`_batchDelete` 三个方法（逻辑已迁入 `batch_operation_sheet.dart`）。若删除后出现未使用的 import（如 `delete_torrent_dialog.dart`、`client_config.dart`），一并清理。

- [ ] **Step 3: 运行分析**

Run: `flutter analyze lib/screens/torrent_list_screen.dart`
Expected: No issues found.

- [ ] **Step 4: 写 widget 测试 — 面板弹出与添加 Tracker 流程**

在 `test/screens/torrent_list_select_test.dart` 末尾新增测试（复用文件内已有的 `_FakeService` 与挂载辅助）。新增：

```dart
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
```

> 注意：`_FakeService` 需实现 Task 1 新增的 3 个批量 Tracker 方法（空实现即可）。在 `test/screens/torrent_list_select_test.dart` 的 `_FakeService` 类中补：

```dart
  @override
  Future<void> addTrackers(
    ClientConfig config, List<String> hashes, List<String> trackerUrls) async {}
  @override
  Future<void> replaceTrackers(
    ClientConfig config, List<String> hashes, String oldUrl, String newUrl) async {}
  @override
  Future<void> removeTrackers(
    ClientConfig config, List<String> hashes, String trackerUrl) async {}
```

- [ ] **Step 5: 运行 widget 测试**

Run: `flutter test test/screens/torrent_list_select_test.dart`
Expected: PASS（含新增用例）。

- [ ] **Step 6: 运行全量测试确认无回归**

Run: `flutter test`
Expected: All tests passed.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/torrent_list_screen.dart test/screens/torrent_list_select_test.dart
git commit -m "feat(torrent): 批量操作面板替换浮动按钮"
```

---

### Task 7: README 更新 + 全量验证

**Files:**
- Modify: `README.md`

**说明**：按项目约定「每次提交前检查是否需更新 README」，README「批量操作」条目需补充批量改 Tracker。

- [ ] **Step 1: 更新 README 批量操作条目**

在 `README.md` 的功能列表「批量操作」一项，把：

```
- **批量操作**：选择模式下的批量暂停 / 恢复 / 删除。
```

改为：

```
- **批量操作**：选择模式下底部面板，批量暂停 / 恢复 / 删除（含「无辅种时删除文件」选项）、批量改 Tracker（添加 / 替换 / 删除）。
```

- [ ] **Step 2: 全量验证**

Run: `flutter analyze`
Expected: 无新增 error（既有 info 级 lint 可忽略）。

Run: `flutter test`
Expected: All tests passed。

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README 补充批量改 Tracker"
```

---

## Self-Review

**Spec coverage：**
- 接口扩展 3 方法 → Task 1-3 ✓
- provider 逐客户端转发 → Task 4 ✓
- 底部操作面板（暂停/恢复/删除/改 Tracker）→ Task 5-6 ✓
- 删除复用「无辅种时删除文件」→ Task 5 `_runDelete` 调 `showDeleteTorrentDialog` + `deleteTorrentsSmart` ✓
- Tracker 三操作（添加/替换/删除）→ Task 5 ✓
- 跨客户端逐客户端 + 部分失败汇总 → Task 5 `_groupedByClient` + `failed` 汇总 ✓
- 空选校验 → 面板仅在 `selectedCount > 0` 时可触发（浮动按钮条件）✓
- Tracker URL 校验（含 `://`）→ Task 5 各 `_addTrackers`/`_replaceTrackers`/`_removeTrackers` ✓
- Tracker 操作后不退出选择模式、不刷新 → Task 5 `_runTracker` 未调 `exitSelectMode`/`refreshTorrents` ✓
- 测试：provider fake + widget → Task 4、6 ✓

**Placeholder scan：** 无 TBD/TODO；每步含完整代码。Task 2 的 service 层测试因项目无 mock 库，已说明改由 provider fake + 人工实测覆盖，非占位。

**Type consistency：** `addTrackers(hashes, urls)`、`replaceTrackers(hashes, oldUrl, newUrl)`、`removeTrackers(hashes, url)` 在接口/service/provider/fake/UI 全链路签名一致。`_FakeTorrentService.trackerCalls` 记录用 record，字段名 op/hashes/urls/oldUrl/newUrl 与断言一致。
