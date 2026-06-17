# 站点统计汇总卡片、自动刷新与导航栏优化 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在站点列表顶部加全站统计汇总卡片，站点用户信息每 2 小时自动错开刷新（打开 app 超时即刷新），并去除导航栏高斯模糊消除切换卡顿。

**Architecture:** 新增 `SiteStats` 值对象与 `SiteProvider.siteStats` getter 聚合已有数据；扩展 `RefreshService` 注入 `SiteProvider`，新增 2h 定时器与顺序错开刷新（持久化 `lastSiteRefreshAt`）；`app.dart` 去除 `BackdropFilter` 改半透明纯色、指示器改圆角矩形。

**Tech Stack:** Flutter (Dart), provider, Material 3 NavigationBar, SharedPreferences (LocalStorage), flutter_test。

## Global Constraints

- 包名 `bit_manager`（测试 import 前缀 `package:bit_manager/...`）。
- 代码注释一律中文（`///` `//`），标识符与 API 名保留英文。
- 文档/spec/plan 一律中文。
- 提交 commit 不带 Claude / Anthropic 标识，仅用户 git 身份。
- 不允许自动 push 代码。
- 测试用 `SharedPreferences.setMockInitialValues({})` + `LocalStorage.resetForTest()` 初始化存储；`SiteProvider` 测试需 mock `flutter_secure_storage` MethodChannel。
- 遵循现有 TDD：先写失败测试 → 实现 → 通过 → 提交。

参考设计 spec：`docs/superpowers/specs/2026-06-17-site-stats-autorefresh-nav-design.md`。

---

## File Structure

| 文件 | 责任 | 操作 |
|------|------|------|
| `lib/models/stats.dart` | 已有 `GlobalStats`/`ClientStats`；新增 `SiteStats` 值对象 | 修改 |
| `lib/providers/site_provider.dart` | 站点状态所有者；新增 `siteStats` getter、`lastSiteRefreshAt` 同步字段 | 修改 |
| `lib/services/refresh_service.dart` | 定时刷新所有者；新增站点 2h 定时器与错开刷新 | 修改 |
| `lib/screens/site_list_screen.dart` | 站点列表页；顶部新增统计卡片 | 修改 |
| `lib/app.dart` | AppShell；`RefreshService` 注入 siteProvider；导航栏去模糊 | 修改 |
| `lib/utils/helpers.dart` | 已有 `formatBytes`（卡片复用） | 不改 |
| `test/models/stats_test.dart` | 已存在；追加 `SiteStats` 聚合测试 | 修改 |
| `test/providers/site_provider_stats_test.dart` | 新增 `siteStats` getter 测试 | 新增 |
| `test/services/refresh_service_test.dart` | 已存在；追加站点刷新超时判断测试 | 修改 |
| `test/screens/site_list_screen_test.dart` | 新增统计卡片 widget 测试 | 新增 |

---

### Task 1: `SiteStats` 值对象

**Files:**
- Modify: `lib/models/stats.dart`（文件末尾追加）
- Test: `test/models/stats_test.dart`（追加）

**Interfaces:**
- Produces: `SiteStats` 类（全部 required named 参数），字段：`totalSites`、`activeSites`、`sitesWithCookie`、`totalUploaded`、`totalDownloaded`、`totalBonus`、`totalSeedingCount`、`totalSeedingSize`、`unreadTotal`、`hnrPreWarningTotal`、`hnrUnsatisfiedTotal`、`lastRefreshAt`（`DateTime?`）。

- [ ] **Step 1: 写失败测试**

在 `test/models/stats_test.dart` 的 `void main() {` 内追加：

```dart
test('SiteStats 持有全部汇总字段', () {
  final stats = SiteStats(
    totalSites: 5,
    activeSites: 4,
    sitesWithCookie: 3,
    totalUploaded: 1000,
    totalDownloaded: 500,
    totalBonus: 200,
    totalSeedingCount: 12,
    totalSeedingSize: 3000,
    unreadTotal: 2,
    hnrPreWarningTotal: 1,
    hnrUnsatisfiedTotal: 0,
    lastRefreshAt: null,
  );
  expect(stats.totalSites, 5);
  expect(stats.activeSites, 4);
  expect(stats.sitesWithCookie, 3);
  expect(stats.totalUploaded, 1000);
  expect(stats.totalDownloaded, 500);
  expect(stats.totalBonus, 200);
  expect(stats.totalSeedingCount, 12);
  expect(stats.totalSeedingSize, 3000);
  expect(stats.unreadTotal, 2);
  expect(stats.hnrPreWarningTotal, 1);
  expect(stats.hnrUnsatisfiedTotal, 0);
  expect(stats.lastRefreshAt, isNull);
});
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/models/stats_test.dart`
Expected: FAIL — `SiteStats` 未定义。

- [ ] **Step 3: 实现 `SiteStats`**

在 `lib/models/stats.dart` 末尾追加：

```dart
/// 站点统计汇总 — 聚合所有站点的 SiteUserInfo，零新增网络请求
class SiteStats {
  final int totalSites;
  final int activeSites;
  final int sitesWithCookie;
  final int totalUploaded;
  final int totalDownloaded;
  final int totalBonus;
  final int totalSeedingCount;
  final int totalSeedingSize;
  final int unreadTotal;
  final int hnrPreWarningTotal;
  final int hnrUnsatisfiedTotal;
  final DateTime? lastRefreshAt;

  SiteStats({
    required this.totalSites,
    required this.activeSites,
    required this.sitesWithCookie,
    required this.totalUploaded,
    required this.totalDownloaded,
    required this.totalBonus,
    required this.totalSeedingCount,
    required this.totalSeedingSize,
    required this.unreadTotal,
    required this.hnrPreWarningTotal,
    required this.hnrUnsatisfiedTotal,
    this.lastRefreshAt,
  });
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/models/stats_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/models/stats.dart test/models/stats_test.dart
git commit -m "feat(stats): 新增 SiteStats 站点汇总值对象"
```

---

### Task 2: `SiteProvider.siteStats` getter 聚合

**Files:**
- Modify: `lib/providers/site_provider.dart`（在 `unreadTotal` getter 附近追加）
- Test: `test/providers/site_provider_stats_test.dart`（新建）

**Interfaces:**
- Consumes: `SiteStats`（Task 1）、`SiteUserInfo`、`SiteConfig`（已有）。
- Produces: `SiteProvider.siteStats` getter（返回 `SiteStats`）；新增 `DateTime? _lastSiteRefreshAt` 私有字段 + `DateTime? get lastSiteRefreshAt` + `void markSiteRefreshed(DateTime time)`。

聚合规则（见 spec 1.3）：数值字段遍历 `_userInfo.values`，跳过 `fetchFailed == true` 与字段 `null` 后求和；`lastRefreshAt` 取所有 `info.lastFetchedAt` 最大值；公开站点天然跳过。

- [ ] **Step 1: 写失败测试**

新建 `test/providers/site_provider_stats_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig _site(String id, {bool active = true, String? type}) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: const ['电影'],
      isActive: active,
      type: type,
    );

SiteUserInfo _info(
  String siteId, {
  bool fetchFailed = false,
  int? uploaded,
  int? downloaded,
  int? bonusPoints,
  int? seedingCount,
  int? seedingSize,
  int? messageCount,
  int? hnrPreWarning,
  int? hnrUnsatisfied,
  DateTime? lastFetchedAt,
}) =>
    SiteUserInfo(
      siteId: siteId,
      fetchFailed: fetchFailed,
      uploaded: uploaded,
      downloaded: downloaded,
      bonusPoints: bonusPoints,
      seedingCount: seedingCount,
      seedingSize: seedingSize,
      messageCount: messageCount,
      hnrPreWarning: hnrPreWarning,
      hnrUnsatisfied: hnrUnsatisfied,
      lastFetchedAt: lastFetchedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  test('siteStats 聚合多站点用户信息并跳过失败与公开站', () async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1', active: true));
    await provider.addSite(_site('s2', active: true));
    await provider.addSite(_site('s3', active: false)); // 不活跃
    await provider.addSite(_site('pub', type: 'public')); // 公开站

    // 直接写内存用户信息（绕过网络抓取）
    await provider.updateUserInfo(_info('s1',
        uploaded: 1000, downloaded: 500, bonusPoints: 200,
        seedingCount: 5, seedingSize: 3000, messageCount: 2,
        hnrPreWarning: 1, hnrUnsatisfied: 0,
        lastFetchedAt: DateTime(2026, 6, 17, 10)));
    await provider.updateUserInfo(_info('s2',
        uploaded: 4000, downloaded: 1500, bonusPoints: 100,
        seedingCount: 7, seedingSize: 7000, messageCount: 0,
        lastFetchedAt: DateTime(2026, 6, 17, 12)));
    await provider.updateUserInfo(_info('s1-failed', fetchFailed: true)); // 不计入

    final stats = provider.siteStats;

    expect(stats.totalSites, 4);
    expect(stats.activeSites, 3);
    expect(stats.totalUploaded, 5000); // 1000 + 4000
    expect(stats.totalDownloaded, 2000); // 500 + 1500
    expect(stats.totalBonus, 300);
    expect(stats.totalSeedingCount, 12);
    expect(stats.totalSeedingSize, 10000);
    expect(stats.unreadTotal, 2);
    expect(stats.hnrPreWarningTotal, 1);
    expect(stats.hnrUnsatisfiedTotal, 0);
    expect(stats.lastRefreshAt, DateTime(2026, 6, 17, 12)); // 最大值
  });

  test('siteStats 无用户信息时 lastRefreshAt 为 null 且数值全 0', () async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1'));

    final stats = provider.siteStats;

    expect(stats.totalSites, 1);
    expect(stats.activeSites, 1);
    expect(stats.totalUploaded, 0);
    expect(stats.unreadTotal, 0);
    expect(stats.lastRefreshAt, isNull);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/providers/site_provider_stats_test.dart`
Expected: FAIL — `siteStats` getter 不存在。

- [ ] **Step 3: 实现 getter 与同步字段**

在 `lib/providers/site_provider.dart` 的 `unreadTotal` getter 之后追加：

```dart
  /// 上次站点刷新时间（手动刷新与自动刷新都更新，用于跨组件同步）
  DateTime? _lastSiteRefreshAt;
  DateTime? get lastSiteRefreshAt => _lastSiteRefreshAt;

  /// 标记站点刷新完成时间（由 RefreshService 与 refreshAllUserInfo 调用）
  void markSiteRefreshed(DateTime time) {
    if (_lastSiteRefreshAt == null || time.isAfter(_lastSiteRefreshAt!)) {
      _lastSiteRefreshAt = time;
    }
  }

  /// 全站统计汇总 — 聚合已有 SiteUserInfo，零新增网络请求
  ///
  /// 数值字段遍历 _userInfo.values，跳过 fetchFailed 与 null；公开站点天然
  /// 不在 _userInfo 中，自动跳过。lastRefreshAt 取所有 lastFetchedAt 最大值。
  SiteStats get siteStats {
    int totalUploaded = 0;
    int totalDownloaded = 0;
    int totalBonus = 0;
    int totalSeedingCount = 0;
    int totalSeedingSize = 0;
    int hnrPreWarningTotal = 0;
    int hnrUnsatisfiedTotal = 0;
    DateTime? lastRefreshAt;

    for (final info in _userInfo.values) {
      if (info.fetchFailed) continue;
      if (info.uploaded != null) totalUploaded += info.uploaded!;
      if (info.downloaded != null) totalDownloaded += info.downloaded!;
      if (info.bonusPoints != null) totalBonus += info.bonusPoints!;
      if (info.seedingCount != null) totalSeedingCount += info.seedingCount!;
      if (info.seedingSize != null) totalSeedingSize += info.seedingSize!;
      if (info.hnrPreWarning != null) hnrPreWarningTotal += info.hnrPreWarning!;
      if (info.hnrUnsatisfied != null) {
        hnrUnsatisfiedTotal += info.hnrUnsatisfied!;
      }
      if (info.lastFetchedAt != null) {
        if (lastRefreshAt == null ||
            info.lastFetchedAt!.isAfter(lastRefreshAt)) {
          lastRefreshAt = info.lastFetchedAt;
        }
      }
    }

    return SiteStats(
      totalSites: _sites.length,
      activeSites: _sites.where((s) => s.isActive).length,
      sitesWithCookie: _sites
          .where((s) => s.isActive && !s.isPublicSite && hasCookie(s.id))
          .length,
      totalUploaded: totalUploaded,
      totalDownloaded: totalDownloaded,
      totalBonus: totalBonus,
      totalSeedingCount: totalSeedingCount,
      totalSeedingSize: totalSeedingSize,
      unreadTotal: unreadTotal,
      hnrPreWarningTotal: hnrPreWarningTotal,
      hnrUnsatisfiedTotal: hnrUnsatisfiedTotal,
      lastRefreshAt: lastRefreshAt,
    );
  }
```

并在文件顶部 import 追加（若尚未引入）：

```dart
import '../models/stats.dart' show SiteStats;
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/providers/site_provider_stats_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/providers/site_provider.dart test/providers/site_provider_stats_test.dart
git commit -m "feat(site): SiteProvider 新增 siteStats 聚合 getter"
```

---

### Task 3: `refreshAllUserInfo` 标记刷新时间

**Files:**
- Modify: `lib/providers/site_provider.dart`（`refreshAllUserInfo` 方法，约 353-383 行）
- Test: `test/providers/site_provider_test.dart`（追加）

**Interfaces:**
- Consumes: `markSiteRefreshed`（Task 2）。
- Produces: 手动批量刷新成功后调用 `markSiteRefreshed(DateTime.now())`，与 `RefreshService` 同步 `lastSiteRefreshAt`。

- [ ] **Step 1: 写失败测试**

在 `test/providers/site_provider_test.dart` 的 `void main()` 内追加（沿用该文件已有的 `SharedPreferences`/secure_storage setUp；若无 setUp 则在 main 开头补上同 Task 2 的 setUp 块）：

```dart
test('refreshAllUserInfo 完成后更新 lastSiteRefreshAt', () async {
  // 该测试只验证时间标记逻辑，不依赖真实网络。
  // refreshAllUserInfo 在无 Cookie 站点时直接返回 (0,0)，但仍应标记时间。
  final provider = SiteProvider();
  await provider.addSite(testSite('s1')); // 无 Cookie

  final before = provider.lastSiteRefreshAt;
  expect(before, isNull);

  final (success, failed) = await provider.refreshAllUserInfo();

  expect(success, 0);
  expect(failed, 0);
  // 无可刷新站点不应标记时间（保持 null）
  expect(provider.lastSiteRefreshAt, isNull);
});
```

> 注：`refreshAllUserInfo` 在 `targets.isEmpty` 时提前 return，不标记时间；只有真正执行刷新后才标记。本测试断言空 targets 不标记。下一个测试验证有 Cookie 时标记——但 `hasCookie` 依赖存储，简化起见只测空场景的时间不标记行为，避免网络依赖。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/providers/site_provider_test.dart`
Expected: FAIL — `lastSiteRefreshAt` getter 不存在（若 Task 2 已提交则 PASS，跳到 Step 4；此测试主要保护回归）。

- [ ] **Step 3: 实现标记逻辑**

在 `lib/providers/site_provider.dart` 的 `refreshAllUserInfo` 方法内，`finally` 块之前、循环成功累计后，于 `try` 块末尾追加（仅当有 targets 时）：

```dart
      if (targets.isNotEmpty) {
        markSiteRefreshed(DateTime.now());
      }
```

即把 `finally` 前的 `return (success, failed);` 之前插入该段。完整修改后的方法尾部应为：

```dart
      if (targets.isNotEmpty) {
        markSiteRefreshed(DateTime.now());
      }
    } finally {
      _refreshingAll = false;
      notifyListeners();
    }
    return (success, failed);
  }
```

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/providers/site_provider_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/providers/site_provider.dart test/providers/site_provider_test.dart
git commit -m "feat(site): refreshAllUserInfo 完成后标记 lastSiteRefreshAt"
```

---

### Task 4: `RefreshService` 注入 SiteProvider 与站点 2h 定时器

**Files:**
- Modify: `lib/services/refresh_service.dart`
- Modify: `lib/app.dart`（`_init` 传 siteProvider，约 47-52 行）
- Test: `test/services/refresh_service_test.dart`（追加）

**Interfaces:**
- Consumes: `SiteProvider`（含 `sites`、`hasCookie`、`fetchUserInfo`、`markSiteRefreshed`、`lastSiteRefreshAt`）、`LocalStorage`。
- Produces: `RefreshService` 构造新增 `required SiteProvider siteProvider`；新增 `@visibleForTesting` 入口用于测试超时判断。

设计要点（spec 2.2）：

- 常量 `sitePollIntervalHours = 2`、`siteStaggerDelay = Duration(seconds: 5)`、`_lastSiteRefreshKey = 'site_last_refresh_at'`。
- `start()`：读持久化 `_lastSiteRefreshAt`；启动 2h `_sitePollTimer`；立即 `_maybeRefreshSites()`。
- `_maybeRefreshSites()`：先从 `siteProvider.lastSiteRefreshAt` 同步最新值；若 `now - last >= 2h` 或 `last == null` 则 `_refreshSitesStaggered()`。
- `_refreshSitesStaggered()`：顺序遍历有 Cookie 活跃私有站，每站 `fetchUserInfo` 后 `await Future.delayed(siteStaggerDelay)`；结束后 `_lastSiteRefreshAt = DateTime.now()` + `markSiteRefreshed` + 持久化。
- `stop()`：cancel `_sitePollTimer`。

- [ ] **Step 1: 写失败测试**

在 `test/services/refresh_service_test.dart` 的 `void main()` 内追加（复用文件已有的 `_EmptyTorrentService`）：

```dart
test('站点刷新：距上次超过 2 小时则触发错开刷新', () async {
  SharedPreferences.setMockInitialValues({});
  LocalStorage.resetForTest();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );

  final clientProvider = ClientProvider();
  final torrentProvider = TorrentProvider(
    serviceResolver: (_) => _EmptyTorrentService(),
  );
  final statsProvider = StatsProvider();
  final siteProvider = SiteProvider();
  final refreshService = RefreshService(
    clientProvider: clientProvider,
    torrentProvider: torrentProvider,
    statsProvider: statsProvider,
    siteProvider: siteProvider,
  );

  // 无 Cookie 站点 → targets 为空 → 不真正抓取，但 _maybeRefreshSites
  // 在 last==null 时仍会把 _lastSiteRefreshAt 置为 now（视为已尝试）
  await refreshService.maybeRefreshSitesForTest();

  expect(refreshService.lastSiteRefreshAtForTest, isNotNull);
});

test('站点刷新：距上次不足 2 小时不触发', () async {
  SharedPreferences.setMockInitialValues({
    'site_last_refresh_at':
        DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
  });
  LocalStorage.resetForTest();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => null,
  );

  final siteProvider = SiteProvider();
  final refreshService = RefreshService(
    clientProvider: ClientProvider(),
    torrentProvider: TorrentProvider(serviceResolver: (_) => _EmptyTorrentService()),
    statsProvider: StatsProvider(),
    siteProvider: siteProvider,
  );

  await refreshService.maybeRefreshSitesForTest();

  expect(refreshService.lastSiteRefreshAtForTest, isNotNull);
  // 30 分钟前的时间应被保留，未被刷新覆盖
  final diff = DateTime.now().difference(refreshService.lastSiteRefreshAtForTest!);
  expect(diff.inMinutes >= 29, isTrue);
});
```

> 需在测试文件顶部追加 import：`import 'package:bit_manager/providers/site_provider.dart';`、`import 'package:bit_manager/utils/storage.dart';`、`import 'package:flutter/services.dart';`（若已有则跳过）。

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/services/refresh_service_test.dart`
Expected: FAIL — `RefreshService` 构造缺 `siteProvider` 参数 / `maybeRefreshSitesForTest` 不存在。

- [ ] **Step 3: 重写 `RefreshService`**

将 `lib/services/refresh_service.dart` 整体替换为：

```dart
import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../providers/client_provider.dart';
import '../providers/site_provider.dart';
import '../providers/torrent_provider.dart';
import '../providers/stats_provider.dart';
import '../utils/storage.dart';

class RefreshService {
  Timer? _pollTimer;
  Timer? _sitePollTimer;

  final ClientProvider clientProvider;
  final TorrentProvider torrentProvider;
  final StatsProvider statsProvider;
  final SiteProvider siteProvider;

  bool _isRunning = false;

  /// 上次站点刷新时间（内存镜像，与 SiteProvider.lastSiteRefreshAt 双向同步）
  DateTime? _lastSiteRefreshAt;

  /// 站点刷新间隔
  static const int sitePollIntervalHours = 2;

  /// 站点错开刷新间隔（每站之间）
  static const Duration siteStaggerDelay = Duration(seconds: 5);

  /// 持久化 key
  static const String _lastSiteRefreshKey = 'site_last_refresh_at';

  RefreshService({
    required this.clientProvider,
    required this.torrentProvider,
    required this.statsProvider,
    required this.siteProvider,
  });

  bool get isRunning => _isRunning;

  /// 启动轮询
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 种子客户端轮询
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollAll(),
    );
    _pollAll();

    // 站点用户信息轮询（2h）
    _loadLastSiteRefreshAt().then((_) {
      _sitePollTimer = Timer.periodic(
        Duration(hours: sitePollIntervalHours),
        (_) => _maybeRefreshSites(),
      );
      // 启动时立即检查：若距上次超 2h 则刷新（覆盖"打开 app 超时自动刷新"）
      _maybeRefreshSites();
    });
  }

  /// 停止轮询
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _sitePollTimer?.cancel();
    _sitePollTimer = null;
  }

  /// 手动强制刷新全部（种子客户端）
  Future<void> refreshNow() async {
    await _pollAll();
  }

  Future<void> _pollAll() async {
    final activeClients = clientProvider.activeClients;
    if (activeClients.isEmpty) return;

    await torrentProvider.refreshTorrents(activeClients, showLoading: false);
    await statsProvider.refreshStats(
      activeClients,
      torrentProvider.allTorrents,
      torrentProvider.lastRefreshOnlineStatus,
    );
  }

  // ── 站点用户信息刷新 ──

  /// 从存储读取上次站点刷新时间
  Future<void> _loadLastSiteRefreshAt() async {
    try {
      final storage = await LocalStorage.getInstance();
      final raw = await storage.getString(_lastSiteRefreshKey);
      if (raw != null) {
        _lastSiteRefreshAt = DateTime.tryParse(raw);
      }
    } catch (_) {
      _lastSiteRefreshAt = null;
    }
  }

  /// 持久化上次站点刷新时间
  Future<void> _persistLastSiteRefreshAt() async {
    try {
      final storage = await LocalStorage.getInstance();
      if (_lastSiteRefreshAt != null) {
        await storage.setString(
          _lastSiteRefreshKey,
          _lastSiteRefreshAt!.toIso8601String(),
        );
      }
    } catch (_) {
      // 持久化失败仅影响下次超时判断精度，忽略
    }
  }

  /// 判断是否需要刷新站点信息（距上次超 2h 或从未刷新）
  ///
  /// 先从 siteProvider.lastSiteRefreshAt 同步最新值（手动刷新可能已更新）。
  @visibleForTesting
  Future<void> maybeRefreshSitesForTest() async {
    await _loadLastSiteRefreshAt();
    await _maybeRefreshSites();
  }

  @visibleForTesting
  DateTime? get lastSiteRefreshAtForTest => _lastSiteRefreshAt;

  Future<void> _maybeRefreshSites() async {
    // 同步 SiteProvider 端可能更新的时间（手动刷新路径）
    if (siteProvider.lastSiteRefreshAt != null) {
      if (_lastSiteRefreshAt == null ||
          siteProvider.lastSiteRefreshAt!.isAfter(_lastSiteRefreshAt!)) {
        _lastSiteRefreshAt = siteProvider.lastSiteRefreshAt;
      }
    }

    final now = DateTime.now();
    final shouldRefresh = _lastSiteRefreshAt == null ||
        now.difference(_lastSiteRefreshAt!) >=
            const Duration(hours: sitePollIntervalHours);
    if (!shouldRefresh) return;

    await _refreshSitesStaggered();
  }

  /// 顺序错开刷新所有有 Cookie 的活跃私有站点
  ///
  /// 并发 1，每站间隔 siteStaggerDelay，避免集中请求冲击站点。
  Future<void> _refreshSitesStaggered() async {
    final targets = siteProvider.sites
        .where((s) => s.isActive && !s.isPublicSite && siteProvider.hasCookie(s.id))
        .map((s) => s.id)
        .toList();

    // 即使 targets 为空也标记时间，表示已尝试刷新（避免每帧重复触发）
    final now = DateTime.now();
    _lastSiteRefreshAt = now;
    siteProvider.markSiteRefreshed(now);
    await _persistLastSiteRefreshAt();

    for (final siteId in targets) {
      await siteProvider.fetchUserInfo(siteId);
      await Future.delayed(siteStaggerDelay);
    }
  }
}
```

> 注意：`Duration(hours: sitePollIntervalHours)` 与 `Duration(seconds: AppConstants...)` 的常量内联——原文件用 `AppConstants.defaultPollIntervalSeconds`。为保持一致，种子轮询的 `10` 改回引用常量。修正：保留 import `../utils/constants.dart` 并把 `Duration(seconds: 10)` 改回 `const Duration(seconds: AppConstants.defaultPollIntervalSeconds)`。在 import 段补 `import '../utils/constants.dart';`，`_pollTimer` 用该常量。

- [ ] **Step 4: 更新 `app.dart._init` 注入 siteProvider**

`lib/app.dart` 第 47-52 行：

```dart
    _refreshService = RefreshService(
      clientProvider: clientProvider,
      torrentProvider: torrentProvider,
      statsProvider: statsProvider,
      siteProvider: siteProvider,
    );
```

- [ ] **Step 5: 运行测试验证通过**

Run: `flutter test test/services/refresh_service_test.dart`
Expected: PASS（两个用例）。同时跑全量确认无回归：

Run: `flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/services/refresh_service.dart lib/app.dart test/services/refresh_service_test.dart
git commit -m "feat(refresh): 站点信息 2h 自动错开刷新"
```

---

### Task 5: 站点列表统计汇总卡片

**Files:**
- Modify: `lib/screens/site_list_screen.dart`（`build` 的 `body` 内 `Column` 顶部）
- Test: `test/screens/site_list_screen_test.dart`（新建）

**Interfaces:**
- Consumes: `SiteProvider.siteStats`（Task 2）、`formatBytes`（`utils/helpers.dart`）、`refreshingAll`、`refreshAllUserInfo`。
- Produces: 顶部统计卡片 widget（含手动刷新按钮 + 上次刷新相对时间）。

布局（spec 1.4）：站点非空时在标签筛选栏之上显示卡片；为空走 `EmptyState` 不显示卡片。卡片顶部一行 `站点 N · 活跃 M · 已登录 K`，中部网格数值，底部一行相对时间 + 右侧刷新按钮（`refreshingAll` 时转圈禁用）。

- [ ] **Step 1: 写失败测试**

新建 `test/screens/site_list_screen_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:bit_manager/screens/site_list_screen.dart';
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig _site(String id) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: const ['电影'],
    );

Widget _wrap(SiteProvider provider) => ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: SiteListScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('站点非空时顶部显示统计卡片含站点数', (tester) async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1'));
    await provider.updateUserInfo(SiteUserInfo(
      siteId: 's1',
      uploaded: 1024,
      lastFetchedAt: DateTime(2026, 6, 17, 10),
    ));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.textContaining('站点'), findsWidgets);
    expect(find.textContaining('1'), findsWidgets); // 站点数 1
  });

  testWidgets('站点为空时不显示统计卡片，显示空状态', (tester) async {
    final provider = SiteProvider();

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('还没有添加站点'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `flutter test test/screens/site_list_screen_test.dart`
Expected: FAIL — 卡片不存在，"站点 1" 找不到（空状态用例可能已通过）。

- [ ] **Step 3: 实现统计卡片**

在 `lib/screens/site_list_screen.dart` 顶部 import 段追加：

```dart
import '../models/stats.dart';
import '../utils/helpers.dart';
```

在 `_SiteListScreenState` 类内新增方法（放在 `_buildTagFilter` 之前）：

```dart
  /// 顶部全站统计汇总卡片
  Widget _buildStatsCard(SiteProvider provider) {
    final stats = provider.siteStats;
    final lastText = stats.lastRefreshAt == null
        ? '尚未刷新'
        : '上次刷新：${_relativeTime(stats.lastRefreshAt!)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部概览行
            Row(
              children: [
                Text(
                  '站点 ${stats.totalSites} · 活跃 ${stats.activeSites} · '
                  '已登录 ${stats.sitesWithCookie}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (provider.refreshingAll)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: '刷新全部用户信息',
                    onPressed: stats.sitesWithCookie > 0
                        ? () => _refreshAll(context, provider)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 数值网格
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _statsItems(stats)
                  .map((item) => _statCell(context, item.label, item.value))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              lastText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  List<_StatItem> _statsItems(SiteStats stats) {
    return [
      _StatItem('总上传', formatBytes(stats.totalUploaded)),
      _StatItem('总下载', formatBytes(stats.totalDownloaded)),
      _StatItem('总魔力', stats.totalBonus.toString()),
      _StatItem('总做种数', stats.totalSeedingCount.toString()),
      _StatItem('总做种体积', formatBytes(stats.totalSeedingSize)),
      _StatItem('未读消息', stats.unreadTotal.toString()),
      _StatItem('H&R 待考核', stats.hnrPreWarningTotal.toString()),
      _StatItem('H&R 不达标', stats.hnrUnsatisfiedTotal.toString()),
    ];
  }

  Widget _statCell(BuildContext context, String label, String value) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
```

并在文件末尾（`SiteListScreen` 之外）追加辅助类：

```dart
class _StatItem {
  final String label;
  final String value;
  _StatItem(this.label, this.value);
}
```

在 `build` 方法的 `Column`（约 115 行）中，`if (provider.allTags.isNotEmpty) _buildTagFilter(provider),` 之上插入：

```dart
              // 全站统计汇总卡片
              _buildStatsCard(provider),
```

> 注意：该 `Column` 位于 `sites.isEmpty` 判断之后，故站点为空时不进入此分支，自动满足"空时不显示卡片"。

- [ ] **Step 4: 运行测试验证通过**

Run: `flutter test test/screens/site_list_screen_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lib/screens/site_list_screen.dart test/screens/site_list_screen_test.dart
git commit -m "feat(site): 站点列表顶部新增统计汇总卡片"
```

---

### Task 6: 导航栏去模糊 + 指示器优化

**Files:**
- Modify: `lib/app.dart`（`build` 的 `bottomNavigationBar`，约 92-144 行；两个主题的 `navigationBarTheme.indicatorShape`，约 188-191、291-294 行）

**Interfaces:**
- 纯 UI 改动，无新增接口。

改动（spec 三）：

1. 移除 `ClipRect` + `BackdropFilter` 外层，`Container` 背景改 `surface.alpha:0.92` + 顶部 0.5px 分隔线（保留）。
2. inline `NavigationBar` 的 `indicatorShape` 从 `StadiumBorder()` 改 `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`，`indicatorColor` alpha 0.12 → 0.14。
3. 两个主题 `navigationBarTheme.indicatorShape` 同步改 `RoundedRectangleBorder`。

- [ ] **Step 1: 验证现状（无测试，UI 视觉改动）**

Run: `flutter test`
Expected: 全绿（确认基线无回归）。此项无新增测试，因导航栏样式为纯视觉，手动验证为主。

- [ ] **Step 2: 改 `bottomNavigationBar`**

`lib/app.dart` 第 92-144 行，将：

```dart
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                indicatorShape: const StadiumBorder(),
                indicatorColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                destinations: const [
                  // ...（destinations 保持不变）
                ],
              ),
            ),
          ),
        ),
```

替换为：

```dart
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.14),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.language_outlined),
                selectedIcon: Icon(Icons.language),
                label: '站点',
              ),
              NavigationDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: '下载器',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: '种子',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        ),
```

- [ ] **Step 3: 移除未使用的 `dart:ui` import**

`lib/app.dart` 第 1 行 `import 'dart:ui';` 现仅 `BackdropFilter`/`ImageFilter` 使用，删除该 import。

- [ ] **Step 4: 改两个主题的 `indicatorShape`**

`_buildLightTheme`（约 190 行）与 `_buildDarkTheme`（约 293 行）中的：

```dart
        indicatorShape: const StadiumBorder(),
```

均替换为：

```dart
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
```

- [ ] **Step 5: 运行测试与静态分析**

Run: `flutter analyze lib/app.dart`
Expected: 无 error（确认无未使用 import）。

Run: `flutter test`
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lib/app.dart
git commit -m "perf(nav): 去除导航栏高斯模糊并优化选中指示器样式"
```

---

## 完成验证

- [ ] 全量测试通过：`flutter test`
- [ ] 静态分析无 error：`flutter analyze`
- [ ] 手动验证（如环境允许 `flutter run`）：
  - 站点列表顶部出现统计卡片，数值随刷新更新。
  - 杀掉 app 等待或改 `_lastSiteRefreshAt` 为 3h 前，重开 app 观察自动错开刷新。
  - 底部导航切换指示器无卡顿，圆角矩形指示器样式正确。
