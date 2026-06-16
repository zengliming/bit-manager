# 站点列表信息增强 & 站内未读消息设计

## 概述

升级 `SiteTile` 紧凑布局，新增未读消息徽标 + 完整状态指标；点击未读徽标
在应用内 WebView 打开该站点的站内消息页（NexusPHP `/messages.php`、
Gazelle `/inbox.php`）。同时抽出可复用的 `SiteWebViewScreen`。

参考已有 `site_cookie_screen.dart` 的 WebView + 原生 CookieManager 集成模式
（已经验证过 `webview_flutter` 插件路径走得通）。

## 功能范围

1. `SiteTile` 4 行紧凑布局：身份 + 传输 + 状态指标；新增未读消息徽标
2. 抽出 `SiteService.messagePathFor(SiteParseSchema?)` 静态方法
3. `SiteProvider.unreadTotal` getter（基础设施，本期不消费）
4. 新建 `SiteWebViewScreen` 通用 WebView 屏
5. `site_list_screen.dart` 绑定 `onOpenMessages` 回调

非目标：
- 不在底部导航 Tab 加未读汇总徽标
- 不实现跨站消息聚合中心
- 不修改默认 schema 解析（`messageCount` 已在 nexusphp/gazelle JSON 解析）
- 不做消息已读同步（用户在站内自行操作）

## 数据模型

`SiteUserInfo` 字段不动：`messageCount` / `hnrPreWarning` / `hnrUnsatisfied` /
`seedingCount` / `leechingCount` / `bonusPoints` / `seedingSize` /
`bonusPerHour` / `seedingBonus` / `level` / `username` / `uploaded` /
`downloaded` / `ratio` / `joinedAtText` / `lastFetchedAt` / `fetchFailed` 全部
已经存在并能由现有 schema 解析得到。

## 架构

### 新增文件

```
lib/screens/site_webview_screen.dart     # 通用 WebView 屏（cookie 注入 + load）
test/services/site_service_message_path_test.dart
test/providers/site_provider_unread_total_test.dart
test/widgets/site_tile_test.dart
test/screens/site_webview_screen_test.dart
```

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `lib/services/site_service.dart` | 加 `static String messagePathFor(SiteParseSchema?)` |
| `lib/providers/site_provider.dart` | 加 `int get unreadTotal` |
| `lib/widgets/site_tile.dart` | 新增 `onOpenMessages` 回调；重写为 4 行布局；新增未读 / H&R 徽标 |
| `lib/screens/site_list_screen.dart` | 绑定 `onOpenMessages` → `_openMessages` |

## 组件设计

### `SiteService.messagePathFor`

```dart
/// 根据站点架构返回站内消息页路径
static String messagePathFor(SiteParseSchema? schema) {
  switch (schema?.schema) {
    case 'Gazelle':  return '/inbox.php';
    case 'NexusPHP':
    default:         return '/messages.php';
  }
}
```

### `SiteProvider.unreadTotal`

```dart
/// 所有站点未读消息总数（仅统计有 cookie 的）
int get unreadTotal {
  var sum = 0;
  for (final info in _userInfo.values) {
    final n = info.messageCount;
    if (n != null && n > 0) sum += n;
  }
  return sum;
}
```

### `SiteTile` 新签名

```dart
class SiteTile extends StatelessWidget {
  final SiteConfig site;
  final SiteUserInfo? userInfo;
  final bool hasCookie;
  final bool refreshing;
  final String? iconAsset;
  final VoidCallback? onTap;              // 进详情
  final VoidCallback? onRefresh;           // 刷新用户信息
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onOpenMessages;      // ★ 新增
  // ...
}
```

4 行布局：

```
┌──────────────────────────────────────────────┐
│ [图] 站点名 [🍪]              [🔴 3]  2.45  │  ← 行 1：图标、名称、cookie、unread、ratio
│      电影·综合                                │  ← 行 2：标签 chips
│      用户名 · LV.5  ↑1.2TB ↓200GB            │  ← 行 3：身份+传输
│      ✦1.2k  ⇧30  ⇩5  ⚠2                     │  ← 行 4：状态指标
└──────────────────────────────────────────────┘
```

逐行规则：

- **行 1**
  - 左：图标 + 名称（`maxLines:1` ellipsis） + cookie 小图标
  - 中：未读徽标（`messageCount==null || 0` → 不渲染；`1..99` → 数字；`>=100` → "99+"；红底白字圆角）
  - 右：抓取中 spinner；否则 ratio；否则无 userInfo 时显示刷新按钮
- **行 2**：标签 chips（保留现有 `take(3)`）
- **行 3**：纯文本 11 号灰字
  - username / level / ↑down 至少一项存在才渲染整行
- **行 4**：状态指标 11 号灰字
  - ✦ 魔力值（`bonusPoints != null`）
  - ⇧ 做种数（`seedingCount != null`）
  - ⇩ 下载中（`leechingCount != null`）
  - ⚠ H&R（`pre+unsat` 都为 0/null → 不渲染；> 0 → 合并显示 `⚠{sum}`；不达标 > 0 时换强调色 `0xFFFF3B30`）
  - 一项都没有 → 整行不渲染

右侧（启用开关）：`Switch` 整体下移到列底，缩小 `materialTapTargetSize`。
无 cookie 的站行内全部 userInfo 相关行不渲染（保留"未配置 Cookie"提示）。

### `SiteWebViewScreen`

```dart
class SiteWebViewScreen extends StatefulWidget {
  final SiteConfig site;
  final String path;        // 例如 "/messages.php" 或 "/inbox.php"
  const SiteWebViewScreen({super.key, required this.site, required this.path});
}
```

行为：
- 启动：显示 `LinearProgressIndicator`（AppBar 底部）
- 注入 cookie：把 SecureStorage 中 `cookie_${site.id}` 拆成 `Cookie` 对象，逐条
  `WebviewCookieManager.setCookie(url, cookie)`
- 注入成功 → `WebViewController().loadRequest(Uri.parse(baseUrl + path))`
- 注入失败 → `SnackBar` 提示"cookie 注入失败，请确认 WebView 原生插件已加载" + 「重试」按钮
- 网页 `statusCode != 200` → 显示 `EmptyState`（"加载失败" + "重试"）
- AppBar 右侧关闭按钮 → `Navigator.pop`
- `dispose` 中 dispose controller

复用 `site_cookie_screen.dart` 的 `_cookieManager` 路径（已经验证）。

### `site_list_screen.dart` 绑定

```dart
SiteTile(
  site: site,
  userInfo: provider.getUserInfo(site.id),
  hasCookie: provider.hasCookie(site.id),
  refreshing: provider.isRefreshing(site.id),
  iconAsset: _getIconAsset(site.id),
  onTap: () => Navigator.push(... SiteDetailScreen ...),
  onRefresh: () => provider.fetchUserInfo(site.id),
  onToggleActive: (v) { ... },
  onOpenMessages: () => _openMessages(context, site, provider),  // ★ 新增
)

void _openMessages(BuildContext context, SiteConfig site, SiteProvider provider) {
  if (!provider.hasCookie(site.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请先配置 Cookie')),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SiteWebViewScreen(
        site: site,
        path: SiteService.messagePathFor(site.parseSchema),
      ),
    ),
  );
}
```

## 视觉规范

- 卡片：圆角 14，背景 `Theme.cardColor`（沿用现有）
- 字体：行 1 名称 15sp w600；ratio 15sp w700；行 2-4 11sp 灰 `onSurfaceVariant`
- 颜色：
  - 分享率绿 ≥2 / 蓝 1-2 / 红 <1（沿用 `_ratioColor`）
  - 未读徽标背景 `0xFFFF3B30`，白字
  - H&R 徽标背景 `0xFFFF9500`（橙），不达标 > 0 时换 `0xFFFF3B30`（红）
- 间距：列 12、列内 4、列间 6；行高固定
- 响应式：屏宽 < 360 时标签 chips 限 2 个
- 禁用（`isActive=false`）：整行 `Opacity(0.5)`（沿用现有）

## 可达性

- 未读徽标：`Semantics(label: '$count 条未读消息', button: true)`
- H&R 徽标：`Semantics(label: 'H&R 警告 $sum', button: false)`
- 刷新按钮：保留 tooltip "刷新用户信息"

## 错误处理

| 场景 | 行为 |
|------|------|
| 无 cookie | SiteTile 行只渲染基本字段；徽标不出现；详情页给"未配置 Cookie"提示 |
| 抓取失败 | `fetchFailed=true` 时**保留旧 messageCount**（默认值 A），整行无新指示；列表摘要改为红色"抓取失败" |
| WebView 注入失败 | SnackBar + 重试 |
| WebView 加载失败 | EmptyState + 重试 |
| `site.baseUrl == null` | 点击未读徽标 → SnackBar"该站点未配置 URL" |

## 测试

### 单元测试

`test/services/site_service_message_path_test.dart`：
- `null` schema → `/messages.php`
- `SiteParseSchema(schema: 'NexusPHP')` → `/messages.php`
- `SiteParseSchema(schema: 'Gazelle')` → `/inbox.php`

`test/providers/site_provider_unread_total_test.dart`：
- 空 `_userInfo` → 0
- 全 `null` → 0
- 含 `messageCount=3,5,null,0` → 8
- 跳过 `null` userInfo

### Widget 测试

`test/widgets/site_tile_test.dart`：
- 仅 username → 行 3 渲染，其他行不出现
- `messageCount=3` → 红色徽标显示数字 3，可点击
- `messageCount=null` → 徽标不渲染
- `messageCount=150` → 显示 "99+"
- `hnrPreWarning=2, hnrUnsatisfied=1` → 显示 "⚠3" 强调色
- `hnrPreWarning=0, hnrUnsatisfied=0` → 不显示
- `refreshing=true` → spinner 替代 ratio
- `hasCookie=false` → userInfo 相关行不渲染

`test/screens/site_webview_screen_test.dart`：
- 无 cookie → 提示且不导航（绑定在 `_openMessages` 处测）
- 注入成功 → 期望 `loadRequest` 调用
- 注入失败 → 显示重试按钮

### 手动验收

1. 添加 NexusPHP 站 + 配 cookie + 刷新 → 看到未读徽标
2. 缺 H&R 的站 H&R 徽标不显示
3. 关闭启用后行变灰
4. 点击未读徽标 → 站内消息页 WebView 打开
5. 故意改坏 cookie（删一字符）→ 列表抓取失败文案显示

## 依赖

- `webview_flutter` — 已存在，沿用
- `webview_flutter` 在 Android / Windows 的 cookie manager 插件已存在（site_cookie_screen 在用）
- `url_launcher` — 不需要（不做外部浏览器）

## 风险 & 缓解

| 风险 | 缓解 |
|------|------|
| WebView cookie 注入依赖原生插件 | 沿用 `site_cookie_screen.dart` 验证过的路径；失败时给明确错误提示 |
| `messageCount=null` 的站未读徽标不显示 | UI 文案 "未配置" 区分；schema 解析失败在 `SiteRulesScreen` 提供手动补 |
| `fetchFailed=true` 时旧值误导 | 默认保留旧值（A 决策）；如要切 B 改 1 行即可 |
| WebView 内存占用 | `dispose` 释放 controller；浏览器风格返回而非保留 |
