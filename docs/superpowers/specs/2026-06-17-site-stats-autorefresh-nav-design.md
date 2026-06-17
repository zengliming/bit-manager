# 站点统计汇总卡片、自动刷新与导航栏优化设计

日期：2026-06-17
状态：已确认，待实现规划

## 背景与目标

当前站点页（`SiteListScreen`）只有逐站列表，缺少全站汇总视图；站点用户信息只能手动刷新，无法定时自动更新；底部导航栏因 `BackdropFilter` 高斯模糊导致切换指示器时卡顿。

本设计解决三个问题：

1. **站点统计汇总卡片**：在站点列表顶部展示全站汇总数据。
2. **站点信息自动刷新**：每 2 小时自动错开刷新一次；打开 app 时若距上次刷新超过 2 小时则立即刷新。
3. **导航栏动画与样式优化**：去除高斯模糊层消除卡顿，优化选中指示器样式。

## 一、站点统计汇总卡片

### 1.1 数据来源

直接聚合 `SiteProvider._userInfo` 中已有数据，**零新增网络请求**。聚合逻辑放在 `SiteProvider` 的 getter 中，UI 通过 `Consumer<SiteProvider>` 监听。

### 1.2 新增值对象 `SiteStats`

新增到 `lib/models/stats.dart`（与 `GlobalStats` 同文件）：

```dart
class SiteStats {
  final int totalSites;          // 站点总数
  final int activeSites;         // isActive 站点数
  final int sitesWithCookie;     // 已配置 Cookie 的私有站点数
  final int totalUploaded;       // 各站 info.uploaded 求和（null 跳过）
  final int totalDownloaded;     // 各站 info.downloaded 求和（null 跳过）
  final int totalBonus;          // 各站 info.bonusPoints 求和
  final int totalSeedingCount;   // 各站 info.seedingCount 求和
  final int totalSeedingSize;    // 各站 info.seedingSize 求和
  final int unreadTotal;         // 复用现有 SiteProvider.unreadTotal
  final int hnrPreWarningTotal;  // 各站 info.hnrPreWarning 求和
  final int hnrUnsatisfiedTotal; // 各站 info.hnrUnsatisfied 求和
  final DateTime? lastRefreshAt; // 所有站点 lastFetchedAt 的最大值

  // 全部字段必填的构造函数，省略...
}
```

### 1.3 `SiteProvider` 新增 getter

```dart
SiteStats get siteStats { ... }
```

聚合规则：

- `totalSites` / `activeSites`：遍历 `_sites`。
- `sitesWithCookie`：`_sites` 中 `!isPublicSite && isActive && hasCookie(id)` 计数。
- 数值类字段（uploaded/downloaded/bonus/seedingCount/seedingSize/hnrPreWarning/hnrUnsatisfied）：遍历 `_userInfo.values`，跳过 `fetchFailed == true` 与字段 `null` 的条目后求和。
- `lastRefreshAt`：取所有 `info.lastFetchedAt` 的最大值；全空则 `null`。
- `unreadTotal`：直接返回现有 `unreadTotal` getter 的结果。

公开站点（`isPublicSite`）天然没有这些字段，聚合时自动跳过（其 `_userInfo` 中本无对应条目）。

### 1.4 展示位置与样式

- 位置：`SiteListScreen` 的 `body` 中，`Column` 最顶部，标签筛选栏之上。**固定不随列表滚动**（即不在 `ListView.builder` 内，而是 `Column` 的一个子项）。
- 监听：`Consumer<SiteProvider>`。
- 卡片内容（用项目现有 `Card` + `Wrap` 风格）：
  - 顶部一行：`站点 12 · 活跃 10 · 已登录 9`。
  - 中部网格：总上传量、总下载量、总魔力、总做种数、总做种体积、未读消息、H&R 待考核、H&R 不达标（用 `formatBytes` / 数字格式化，与 `site_detail_screen._buildInfoGrid` 风格一致）。数值为 0 的项也显示。
  - 底部一行：`上次刷新：5 分钟前`（基于 `lastRefreshAt` 计算相对时间，`null` 时显示"尚未刷新"）+ 右侧手动刷新按钮（图标按钮，`refreshingAll` 时显示 18px 转圈，禁用点击）。
- 卡片始终显示（即使站点为空也显示"站点 0"，但空站点已有 `EmptyState`，此时统计卡片隐藏——见下）。

### 1.5 边界处理

- 站点列表为空（`provider.sites.isEmpty`）：仍走现有 `EmptyState`，**不显示统计卡片**。
- 所有数值聚合为 0 但有站点：正常显示卡片，各字段显示 0 / "0 B"。
- `lastRefreshAt` 为 `null`：底部显示"尚未刷新"。

## 二、站点信息自动刷新

### 2.1 设计决策

**扩展现有 `RefreshService`**，不新建独立 service。理由：

- `RefreshService` 已是 app 生命周期的单一所有者（`AppShell` 在 `init`/`resume`/`paused`/`dispose` 调用 start/refreshNow/stop）。
- 新增一个生命周期所有者会引入"谁在前台才刷新"的协调复杂度。
- 扩展后文件仍 <150 行，职责虽增加但内聚于"定时刷新"主题，可接受。

### 2.2 `RefreshService` 改动

构造函数新增 `required SiteProvider siteProvider` 字段。

新增常量（放 `RefreshService` 内或 `AppConstants`）：

```dart
static const int sitePollIntervalHours = 2;
static const Duration siteStaggerDelay = Duration(seconds: 5);
```

新增字段：

```dart
Timer? _sitePollTimer;
DateTime? _lastSiteRefreshAt;
static const String _lastSiteRefreshKey = 'site_last_refresh_at';
```

#### 触发逻辑

- **`start()`**：
  1. 启动种子轮询定时器（原有逻辑不变）。
  2. 从 `LocalStorage` 读取 `_lastSiteRefreshKey`，反序列化为 `_lastSiteRefreshAt`。
  3. 启动 2 小时周期定时器 `_sitePollTimer`，回调 `_maybeRefreshSites()`。
  4. 调用 `_maybeRefreshSites()` 立即检查一次（覆盖"打开 app 超过 2 小时自动刷新"）。

- **`_maybeRefreshSites()`**：
  - 若 `now - _lastSiteRefreshAt >= 2h`（或 `_lastSiteRefreshAt == null`），调用 `_refreshSitesStaggered()`。
  - 否则不操作。

- **`didChangeAppLifecycleState` resume**（在 `AppShell`）：`_refreshService?.start()` 后 `_refreshService?.refreshNow()` 保持不变；`start()` 内部的 `_maybeRefreshSites()` 已覆盖回前台超时检查。无需额外改动 `AppShell` 生命周期代码。

- **`stop()` / `paused`**：`_sitePollTimer?.cancel()`。

#### 错开刷新 `_refreshSitesStaggered()`

```dart
Future<void> _refreshSitesStaggered() async {
  final targets = siteProvider.sites
      .where((s) => s.isActive && !s.isPublicSite && siteProvider.hasCookie(s.id))
      .map((s) => s.id)
      .toList();
  if (targets.isEmpty) return;

  for (final siteId in targets) {
    await siteProvider.fetchUserInfo(siteId);
    await Future.delayed(siteStaggerDelay); // 每站间隔 5s，错开不集中
  }

  _lastSiteRefreshAt = DateTime.now();
  await _persistLastSiteRefreshAt();
}
```

特点：**顺序、并发 1、每站间隔 5s**。20 站约 100s 完成，请求在时间轴上完全分散，不集中冲击站点。复用现有 `fetchUserInfo`（已带单站 `_refreshing` 状态 + `notifyListeners`，UI 单站转圈仍可用）。

#### 持久化

```dart
Future<void> _persistLastSiteRefreshAt() async {
  final storage = await LocalStorage.getInstance();
  if (_lastSiteRefreshAt != null) {
    await storage.setString(_lastSiteRefreshKey, _lastSiteRefreshAt!.toIso8601String());
  }
}
```

读取在 `start()` 中完成。保证 app 重启后 `_maybeRefreshSites()` 能正确判断"距上次是否超 2h"——重启后立即触发一次（若超时）符合用户预期。

### 2.3 与手动刷新的关系

- 现有 `SiteListScreen._refreshAll` → `SiteProvider.refreshAllUserInfo()`（并发 3 快速批量）**保留不变**，用于用户主动点卡片刷新按钮。
- 自动刷新走 `_refreshSitesStaggered()`（顺序错开）。
- 两条路径都应更新 `_lastSiteRefreshAt`。但 `refreshAllUserInfo` 在 `SiteProvider` 内部，无法直接写 `RefreshService` 字段。

**解决方案**：`SiteProvider` 新增 `DateTime? lastSiteRefreshAt` 内存字段，`refreshAllUserInfo()` 成功结束后置为 `DateTime.now()`。`RefreshService._maybeRefreshSites()` 在判断前先 `if (siteProvider.lastSiteRefreshAt != null && siteProvider.lastSiteRefreshAt! > (_lastSiteRefreshAt ?? DateTime(0))) _lastSiteRefreshAt = siteProvider.lastSiteRefreshAt;` 同步最新值。同时 `RefreshService` 的错开刷新结束后，调用一个新增的 `SiteProvider.markSiteRefreshed(DateTime time)` setter 同步回去，保持两端一致。

> 注：`DateTime.now()` 在生产代码中可用，workflow 脚本里的限制不适用于 app 代码。

### 2.4 `app.dart._init` 改动

`RefreshService` 构造增加 `siteProvider: siteProvider`。

## 三、导航栏动画与样式优化

### 3.1 卡顿根因

`app.dart` 底部导航栏外层包裹 `BackdropFilter(sigmaX: 20, sigmaY: 20)` 高斯模糊。指示器切换动画期间，整个模糊层每帧重绘，是卡顿主因。

### 3.2 改动（`app.dart` `build` 中的 `bottomNavigationBar`）

1. **移除 `ClipRect` + `BackdropFilter`**，背景改用半透明纯色：

```dart
bottomNavigationBar: Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
    border: Border(
      top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
    ),
  ),
  child: NavigationBar( ... ),
)
```

2. **指示器样式**：

```dart
indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
```

（从 `StadiumBorder()` 改为圆角 12 矩形，视觉更现代；`alpha` 从 0.12 微调到 0.14 增强可见性。）

3. **去除模糊后**，M3 `NavigationBar` 默认指示器的 size+fade 动画已足够顺滑，无需自定义 `AnimationController`。

4. **样式微调（保持现有，仅确认）**：导航栏高度 64、选中 icon 24 / 未选 22、选中标签 600 字重 `primary` 色、未选 `onSurfaceVariant` 色。`labelBehavior: alwaysShow` 保持。

### 3.3 主题同步

`_buildLightTheme` / `_buildDarkTheme` 的 `navigationBarTheme` 中 `indicatorShape` 同步改为 `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`（当前是 `StadiumBorder()`），保持 inline `NavigationBar` 属性与主题一致。`BackdropFilter` 不在主题中，无需改主题。

## 四、文件改动清单

| 文件 | 改动 |
|------|------|
| `lib/models/stats.dart` | 新增 `SiteStats` 类 |
| `lib/providers/site_provider.dart` | 新增 `siteStats` getter；新增 `lastSiteRefreshAt` 字段 + `markSiteRefreshed` setter；`refreshAllUserInfo` 成功后标记时间 |
| `lib/services/refresh_service.dart` | 构造注入 `siteProvider`；新增 2h 定时器、`_lastSiteRefreshAt` 持久化、`_maybeRefreshSites`、`_refreshSitesStaggered` |
| `lib/screens/site_list_screen.dart` | 顶部新增统计汇总卡片（`Consumer<SiteProvider>`），含手动刷新按钮与上次刷新时间 |
| `lib/app.dart` | `_init` 传入 `siteProvider`；`bottomNavigationBar` 去模糊改纯色；指示器改圆角矩形；主题 `navigationBarTheme.indicatorShape` 同步 |

## 五、错误处理

- 单站抓取失败：`fetchUserInfo` 已有 try/catch 写入 `fetchFailed`，错开刷新不中断后续站点。
- `LocalStorage` 读写失败：`start()` 中读取用 try/catch 兜底为 `null`（视为首次，立即触发刷新）；持久化失败忽略（仅影响下次超时判断精度）。
- 定时器在 `paused` 时已 cancel，`resume` 时 `start()` 重建，无泄漏。

## 六、测试

现有测试框架：`test/` 下有 provider/service/widget 测试。

- `stats_provider_test.dart` 模式参考，新增 `SiteStats` 聚合的单元测试（构造若干 `SiteUserInfo`，断言求和与跳过逻辑）。
- `refresh_service_test.dart`：扩展用例覆盖 `_refreshSitesStaggered` 顺序错开 + 2h 超时判断（用可注入的 fake clock 或直接构造 `_lastSiteRefreshAt` 为 3h 前断言触发、1h 前断言不触发）。需将 `_lastSiteRefreshAt` 暴露为可测入口或通过 `@visibleForTesting`。
- `site_list_screen.dart` 统计卡片：widget 测试断言卡片在站点非空时显示、为空时隐藏、显示上次刷新文案。

## 七、非目标（YAGNI）

- 不新增独立统计 Tab / 页面。
- 不为自动刷新增加设置项开关（间隔固定 2h；如未来需要可再加，当前不做）。
- 不自绘整套底部导航栏，保留 M3 `NavigationBar`。
- 不改种子客户端 10s 轮询逻辑。
