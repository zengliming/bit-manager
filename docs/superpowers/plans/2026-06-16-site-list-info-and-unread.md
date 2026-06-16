# 站点列表信息增强 & 站内未读消息实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 升级 `SiteTile` 紧凑 4 行布局并新增未读消息徽标；点击徽标在应用内 WebView 打开对应站点的站内消息页（NexusPHP `/messages.php`、Gazelle `/inbox.php`）；抽出可复用的 `SiteWebViewScreen`。

**Architecture:** 解析层 `SiteService.messagePathFor` 静态方法按 `parseSchema.schema` 选消息页路径；状态层 `SiteProvider.unreadTotal` 统计；展示层 `SiteTile` 重写为 4 行紧凑布局 + 红色未读徽标 + 橙色/红色 H&R 徽标；新屏 `SiteWebViewScreen` 用 `WebviewCookieManager` 注入 SecureStorage 里的 cookie 后 `loadRequest`。复用 `site_cookie_screen.dart` 已验证过的 cookie 注入路径。

**Tech Stack:** Flutter 3.12+, Dart, `webview_flutter` ^4.10, `webview_cookie_manager` (本地 fork), `flutter_secure_storage`, `flutter_test`, `provider`

**Spec:** `docs/superpowers/specs/2026-06-16-site-list-info-and-unread-design.md`

---

## File Structure

| 路径 | 角色 | 改动类型 |
|------|------|---------|
| `lib/services/site_service.dart` | 加 `static String messagePathFor(SiteParseSchema?)` | 修改 |
| `lib/providers/site_provider.dart` | 加 `int get unreadTotal` | 修改 |
| `lib/screens/site_webview_screen.dart` | 通用 WebView 屏（cookie 注入 + 加载 + 错误兜底） | 新建 |
| `lib/widgets/site_tile.dart` | 新增 `onOpenMessages` 回调 + 4 行紧凑布局 + 未读 / H&R 徽标 | 修改 |
| `lib/screens/site_list_screen.dart` | 绑定 `onOpenMessages` → `_openMessages` | 修改 |
| `test/services/site_service_message_path_test.dart` | `messagePathFor` 单测 | 新建 |
| `test/providers/site_provider_unread_total_test.dart` | `unreadTotal` 单测 | 新建 |
| `test/widgets/site_tile_test.dart` | SiteTile 渲染 + 徽标 widget 测试 | 新建 |
| `test/screens/site_webview_screen_test.dart` | WebView 屏注入 / 加载测试 | 新建 |

---

### Task 1: `SiteService.messagePathFor` 静态方法

**Files:**
- Modify: `lib/services/site_service.dart`（在 `_applyFieldRules` 之前插入新静态方法）
- Create: `test/services/site_service_message_path_test.dart`

- [ ] **Step 1: 写失败测试**

写入 `test/services/site_service_message_path_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteService.messagePathFor', () {
    test('null schema 返回 NexusPHP 消息页', () {
      expect(SiteService.messagePathFor(null), '/messages.php');
    });

    test('NexusPHP schema 返回 /messages.php', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'NexusPHP')),
        '/messages.php',
      );
    });

    test('Gazelle schema 返回 /inbox.php', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'Gazelle')),
        '/inbox.php',
      );
    });

    test('未知 schema 回落到 NexusPHP', () {
      expect(
        SiteService.messagePathFor(const SiteParseSchema(schema: 'MagicSite')),
        '/messages.php',
      );
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/services/site_service_message_path_test.dart
```

Expected: 编译失败，错误含 `Method not found: 'messagePathFor'`。

- [ ] **Step 3: 实现 `messagePathFor`**

在 `lib/services/site_service.dart` 的 `_applyFieldRules` 之前插入：

```dart
/// 根据站点架构返回站内消息页路径
static String messagePathFor(SiteParseSchema? schema) {
  switch (schema?.schema) {
    case 'Gazelle':
      return '/inbox.php';
    case 'NexusPHP':
    default:
      return '/messages.php';
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/services/site_service_message_path_test.dart
```

Expected: 4 个 test 全 PASS。

- [ ] **Step 5: Commit**

```bash
git add test/services/site_service_message_path_test.dart lib/services/site_service.dart
git commit -m "feat(site): SiteService.messagePathFor 按 schema 返回消息页路径"
```

---

### Task 2: `SiteProvider.unreadTotal` getter

**Files:**
- Modify: `lib/providers/site_provider.dart`（在 `// ── 用户信息 ──` 区块顶部添加）
- Create: `test/providers/site_provider_unread_total_test.dart`

- [ ] **Step 1: 写失败测试**

写入 `test/providers/site_provider_unread_total_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });

  SiteUserInfo infoWithCount(int? n) => SiteUserInfo(
    siteId: 'x',
    messageCount: n,
  );

  group('SiteProvider.unreadTotal', () {
    test('空 _userInfo 返回 0', () {
      final provider = SiteProvider();
      expect(provider.unreadTotal, 0);
    });

    test('含 null messageCount 返回 0', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.updateUserInfo(infoWithCount(null));
      expect(provider.unreadTotal, 0);
    });

    test('含 0 messageCount 返回 0', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.updateUserInfo(infoWithCount(0));
      expect(provider.unreadTotal, 0);
    });

    test('累加所有 > 0 的 messageCount', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));
      await provider.addSite(testSite('b'));
      await provider.addSite(testSite('c'));
      await provider.addSite(testSite('d'));
      await provider.updateUserInfo(infoWithCount(3));
      await provider.updateUserInfo(infoWithCount(5));
      await provider.updateUserInfo(infoWithCount(null));
      await provider.updateUserInfo(infoWithCount(0));
      expect(provider.unreadTotal, 8);
    });
  });
}

SiteConfig testSite(String id) => SiteConfig(id: id, name: 'Site $id');
```

> 注：`SiteUserInfo` 是 mutable class（`messageCount` 是 `int?`），可以构造后直接传入。
> 复用 `test/providers/site_provider_test.dart` 中的 `testSite` 风格，但本文件独立定义避免 cross-test 依赖。

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/providers/site_provider_unread_total_test.dart
```

Expected: 编译失败，错误含 `unreadTotal` 未定义。

- [ ] **Step 3: 实现 `unreadTotal`**

在 `lib/providers/site_provider.dart` 的 `// ── 用户信息 ──` 区块顶部（在 `getUserInfo` 之前）插入：

```dart
/// 所有站点未读消息总数（仅统计 messageCount > 0 的）
int get unreadTotal {
  var sum = 0;
  for (final info in _userInfo.values) {
    final n = info.messageCount;
    if (n != null && n > 0) sum += n;
  }
  return sum;
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/providers/site_provider_unread_total_test.dart
```

Expected: 4 个 test 全 PASS。

- [ ] **Step 5: 跑全量测试确保无回归**

```bash
flutter test
```

Expected: 全部测试通过；如有 SiteProvider 现有测试因本改动回归，回到本任务排查。

- [ ] **Step 6: Commit**

```bash
git add test/providers/site_provider_unread_total_test.dart lib/providers/site_provider.dart
git commit -m "feat(site): SiteProvider.unreadTotal 汇总未读消息"
```

---

### Task 3: `SiteWebViewScreen` 骨架 + 错误兜底（无 cookie / 无 URL）

**Files:**
- Create: `lib/screens/site_webview_screen.dart`
- Create: `test/screens/site_webview_screen_test.dart`

- [ ] **Step 1: 写失败测试**

写入 `test/screens/site_webview_screen_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/screens/site_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('site.baseUrl 为空时显示提示', (tester) async {
    final site = SiteConfig(id: 'a', name: 'A', baseUrl: null);

    await tester.pumpWidget(
      MaterialApp(
        home: SiteWebViewScreen(site: site, path: '/messages.php'),
      ),
    );

    expect(find.text('该站点未配置 URL'), findsOneWidget);
    expect(find.byType(WebView), findsNothing);
  });

  testWidgets('site 存在 baseUrl 时渲染 AppBar 标题', (tester) async {
    final site = SiteConfig(
      id: 'a',
      name: 'Example',
      baseUrl: 'https://example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiteWebViewScreen(site: site, path: '/messages.php'),
      ),
    );

    expect(find.text('Example · 消息'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/screens/site_webview_screen_test.dart
```

Expected: 编译失败，`SiteWebViewScreen` 不存在。

- [ ] **Step 3: 实现骨架**

写入 `lib/screens/site_webview_screen.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
import '../models/site_config.dart';
import '../utils/helpers.dart';

/// 通用站内 WebView 屏
///
/// 启动时把 SecureStorage 里的 `cookie_{site.id}` 拆成单条 cookie 注入到原生
/// WebView 的 cookie jar，然后 `loadRequest(baseUrl + path)`。复用
/// `site_cookie_screen.dart` 已验证过的 cookie 注入路径。
class SiteWebViewScreen extends StatefulWidget {
  final SiteConfig site;

  /// 站内相对路径，如 '/messages.php' 或 '/inbox.php'
  final String path;

  const SiteWebViewScreen({
    super.key,
    required this.site,
    required this.path,
  });

  @override
  State<SiteWebViewScreen> createState() => _SiteWebViewScreenState();
}

class _SiteWebViewScreenState extends State<SiteWebViewScreen> {
  final WebviewCookieManager _cookieManager = WebviewCookieManager();
  WebViewController? _controller;
  bool _loading = true;
  String? _error;
  String? _cookieString;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  String? get _baseUrl => widget.site.baseUrl;
  String? get _cookieStorageKey => 'cookie_${widget.site.id}';

  Future<void> _bootstrap() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = '该站点未配置 URL';
      });
      return;
    }
    try {
      // SecureStorage 读取依赖外部传入：本屏通过 SiteProvider 之外的层提供
      // （site_list_screen 注入前应已校验 cookie 存在）
      final cookie = await _readCookie(_cookieStorageKey!);
      if (cookie == null || cookie.isEmpty) {
        setState(() {
          _loading = false;
          _error = '该站点未配置 Cookie';
        });
        return;
      }
      _cookieString = cookie;
      final uri = Uri.parse(_joinUrl(baseUrl, widget.path));
      await _injectCookies(uri, cookie);
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _error = '加载失败：${e.description}';
                });
              }
            },
          ),
        )
        ..loadRequest(uri);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '启动失败：$e';
        });
      }
    }
  }

  Future<String?> _readCookie(String key) async {
    // 复用 site_provider 通过 LocalStorage 暴露的读取路径。
    // 这里直接走 flutter_secure_storage，跟 site_provider saveCookie 一致。
    // 通过显式 import + 包装避免在本文件重复解码逻辑。
    final storage = await LocalStorage.getInstance();
    return storage.getString(key);
  }

  Future<void> _injectCookies(Uri uri, String cookie) async {
    final parts = cookie.split(';');
    for (final p in parts) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      await _cookieManager.setCookie(
        uri,
        Cookie(name, value)
          ..domain = uri.host
          ..path = '/',
      );
    }
  }

  String _joinUrl(String baseUrl, String path) {
    final base = Uri.parse(baseUrl);
    return base.resolveUri(Uri.parse(path)).toString();
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _controller = null;
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final title = '${site.name} · ${_pageTitle(widget.path)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _error != null
          ? _buildError(_error!)
          : (_controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: _controller!)),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  String _pageTitle(String path) {
    if (path.contains('inbox')) return '消息';
    if (path.contains('messages')) return '消息';
    return '站内';
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/screens/site_webview_screen_test.dart
```

Expected: 2 个 test 全 PASS（用 baseUrl=null 和 baseUrl=valid 两路）。

- [ ] **Step 5: Commit**

```bash
git add lib/screens/site_webview_screen.dart test/screens/site_webview_screen_test.dart
git commit -m "feat(site): SiteWebViewScreen 通用 WebView 屏（cookie 注入 + 错误兜底）"
```

---

### Task 4: `SiteWebViewScreen` 注入成功 / 失败行为测试

**Files:**
- Modify: `test/screens/site_webview_screen_test.dart`

- [ ] **Step 1: 写失败测试（追加 2 个用例）**

在 `test/screens/site_webview_screen_test.dart` 顶部 import 区域加入：

```dart
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

在 `void main()` 顶部 `setUp` 中加入：

```dart
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
  });
```

在文件末尾追加新 group：

```dart
  group('cookie 注入与加载', () {
    setUp(() async {
      LocalStorage.resetForTest();
    });

    testWidgets('cookie 存在时调用 loadRequest 并隐藏 progress',
        (tester) async {
      final storage = await LocalStorage.getInstance();
      await storage.setString(
        'cookie_a',
        'uid=1; pass=abc',
      );
      final site = SiteConfig(
        id: 'a',
        name: 'Example',
        baseUrl: 'https://example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SiteWebViewScreen(site: site, path: '/messages.php'),
        ),
      );
      // 让 async _bootstrap 跑完
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('cookie 不存在时显示错误占位', (tester) async {
      final site = SiteConfig(
        id: 'a',
        name: 'Example',
        baseUrl: 'https://example.com',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SiteWebViewScreen(site: site, path: '/messages.php'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('该站点未配置 Cookie'), findsOneWidget);
      expect(find.byType(WebViewWidget), findsNothing);
    });
  });
```

> 实现要求：若 `LocalStorage` 没有 `resetForTest()` 静态方法，则在 `lib/utils/storage.dart` 加一个清空单例的方法（参考现有 `getInstance()`），并在 Task 3 的 import 中已经存在。
>
> 实际查看 `lib/utils/storage.dart`，若没有则本步额外加一个 `static void resetForTest() { _instance = null; }`。

- [ ] **Step 2: 跑测试确认通过**

```bash
flutter test test/screens/site_webview_screen_test.dart
```

Expected: 4 个 test 全 PASS。

> 若 `LocalStorage.resetForTest` 不存在导致编译失败，先在 `lib/utils/storage.dart` 加：
> ```dart
> static void resetForTest() { _instance = null; }
> ```
> 然后再跑测试。

- [ ] **Step 3: Commit**

```bash
git add test/screens/site_webview_screen_test.dart lib/utils/storage.dart lib/screens/site_webview_screen.dart
git commit -m "test(site): SiteWebViewScreen cookie 注入与缺失场景测试"
```

---

### Task 5: `SiteTile` 新签名 + 未读徽标 widget

**Files:**
- Modify: `lib/widgets/site_tile.dart`（重写整文件）
- Create: `test/widgets/site_tile_test.dart`

- [ ] **Step 1: 写失败测试**

写入 `test/widgets/site_tile_test.dart`：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/widgets/site_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SiteConfig makeSite({String id = 'a', String name = 'Site A'}) =>
    SiteConfig(id: id, name: name, baseUrl: 'https://$id.example.com');

SiteUserInfo makeInfo({
  String siteId = 'a',
  int? messageCount,
  int? hnrPreWarning,
  int? hnrUnsatisfied,
  int? seedingCount,
  int? leechingCount,
  int? bonusPoints,
  int? uploaded,
  int? downloaded,
  String? username,
  String? level,
  double? ratio,
}) {
  return SiteUserInfo(
    siteId: siteId,
    messageCount: messageCount,
    hnrPreWarning: hnrPreWarning,
    hnrUnsatisfied: hnrUnsatisfied,
    seedingCount: seedingCount,
    leechingCount: leechingCount,
    bonusPoints: bonusPoints,
    uploaded: uploaded,
    downloaded: downloaded,
    username: username,
    level: level,
    ratio: ratio,
  );
}

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('SiteTile', () {
    testWidgets('仅 username 时只渲染身份行', (tester) async {
      final site = makeSite();
      final info = makeInfo(username: 'alice');

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.textContaining('alice'), findsOneWidget);
      // 没有任何状态指标
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      expect(find.byIcon(Icons.mail_outline), findsNothing);
    });

    testWidgets('messageCount=3 时显示红色未读徽标且可点击',
        (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 3);
      var tapped = 0;

      await pump(
        tester,
        SiteTile(
          site: site,
          userInfo: info,
          hasCookie: true,
          onOpenMessages: () => tapped++,
        ),
      );

      final badge = find.text('3');
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      expect(tapped, 1);
    });

    testWidgets('messageCount=null 时不显示未读徽标', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: null);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      // 找不到任何数字徽标
      expect(find.byIcon(Icons.mail_outline), findsNothing);
    });

    testWidgets('messageCount=150 时显示 99+', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 150);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('H&R pre=2 unsat=1 时显示 ⚠3 强调色', (tester) async {
      final site = makeSite();
      final info = makeInfo(hnrPreWarning: 2, hnrUnsatisfied: 1);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.text('⚠3'), findsOneWidget);
    });

    testWidgets('H&R 全 0 时不显示徽标', (tester) async {
      final site = makeSite();
      final info = makeInfo(hnrPreWarning: 0, hnrUnsatisfied: 0);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.textContaining('⚠'), findsNothing);
    });

    testWidgets('refreshing=true 时显示 spinner 替代 ratio', (tester) async {
      final site = makeSite();
      final info = makeInfo(ratio: 2.5);

      await pump(
        tester,
        SiteTile(
          site: site,
          userInfo: info,
          hasCookie: true,
          refreshing: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('2.50'), findsNothing);
    });

    testWidgets('hasCookie=false 时不渲染 userInfo 行', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 5, username: 'alice');

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: false));

      // 状态行不渲染
      expect(find.byIcon(Icons.mail_outline), findsNothing);
      // 占位文案出现
      expect(find.text('未配置 Cookie'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
flutter test test/widgets/site_tile_test.dart
```

Expected: 编译失败，`onOpenMessages` 未在 SiteTile 中定义。

- [ ] **Step 3: 实现新版 SiteTile**

完全重写 `lib/widgets/site_tile.dart`：

```dart
import 'package:flutter/material.dart';
import '../models/site_config.dart';
import 'site_favicon.dart';
import '../utils/helpers.dart';

/// 站点列表项 — 紧凑 4 行布局
///
/// 行 1：图标 + 名称 + cookie + 未读徽标 + ratio
/// 行 2：标签 chips
/// 行 3：用户名 · 等级 · ↑上传 · ↓下载
/// 行 4：✦魔力 · ⇧做种 · ⇩下载 · ⚠H&R
class SiteTile extends StatelessWidget {
  final SiteConfig site;
  final SiteUserInfo? userInfo;
  final bool hasCookie;
  final bool refreshing;
  final String? iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onOpenMessages;

  const SiteTile({
    super.key,
    required this.site,
    this.userInfo,
    this.hasCookie = false,
    this.refreshing = false,
    this.iconAsset,
    this.onTap,
    this.onRefresh,
    this.onToggleActive,
    this.onOpenMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: site.isActive ? 1.0 : 0.5,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 图标
                SiteFavicon(
                  iconAsset: iconAsset,
                  siteName: site.name,
                  size: 44,
                  radius: 10,
                ),
                const SizedBox(width: 12),

                // 中间信息区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow1(context),
                      if (site.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildTagChips(theme),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildIdentityLine(theme),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildStatusLine(theme),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 右侧：ratio + 开关
                _buildTrailing(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 行 1：图标、名称、cookie、unread、ratio ──
  Widget _buildRow1(BuildContext context) {
    final theme = Theme.of(context);
    final info = userInfo;
    final showUnread = hasCookie && (info?.messageCount ?? 0) > 0;
    final unreadCount = info?.messageCount ?? 0;

    return Row(
      children: [
        Flexible(
          child: Text(
            site.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasCookie) ...[
          const SizedBox(width: 6),
          Icon(Icons.cookie, size: 14, color: theme.colorScheme.primary),
        ],
        if (showUnread) ...[
          const SizedBox(width: 8),
          _UnreadBadge(count: unreadCount, onTap: onOpenMessages),
        ],
      ],
    );
  }

  Widget _buildTagChips(ThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: site.tags
          .take(3)
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ── 行 3：身份 + 传输 ──
  Widget _buildIdentityLine(ThemeData theme) {
    final mutedStyle = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (!hasCookie) {
      return Text('未配置 Cookie', style: mutedStyle);
    }
    final info = userInfo;
    if (info == null) {
      return Text('点击右侧 ⟳ 获取用户信息', style: mutedStyle);
    }
    if (info.fetchFailed) {
      return Text(
        '抓取失败 · 检查 Cookie 是否有效',
        style: mutedStyle.copyWith(color: const Color(0xFFFF3B30)),
      );
    }

    final parts = <String>[];
    if (info.username != null) parts.add(info.username!);
    if (info.level != null) parts.add(info.level!);
    if (info.uploaded != null) parts.add('↑${formatBytes(info.uploaded!)}');
    if (info.downloaded != null) parts.add('↓${formatBytes(info.downloaded!)}');

    if (parts.isEmpty) {
      return Text('解析未命中字段 · 站点模板可能不兼容', style: mutedStyle);
    }
    return Text(parts.join(' · '), style: mutedStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  // ── 行 4：状态指标 ──
  Widget _buildStatusLine(ThemeData theme) {
    final info = userInfo;
    if (info == null) return const SizedBox.shrink();

    final mutedStyle = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    final children = <Widget>[];

    if (info.bonusPoints != null) {
      children.add(Text('✦${formatNumber(info.bonusPoints!)}', style: mutedStyle));
    }
    if (info.seedingCount != null) {
      children.add(Text('⇧${info.seedingCount}', style: mutedStyle));
    }
    if (info.leechingCount != null) {
      children.add(Text('⇩${info.leechingCount}', style: mutedStyle));
    }

    final pre = info.hnrPreWarning ?? 0;
    final unsat = info.hnrUnsatisfied ?? 0;
    if (pre + unsat > 0) {
      final hnrColor = unsat > 0
          ? const Color(0xFFFF3B30)
          : const Color(0xFFFF9500);
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: hnrColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '⚠${pre + unsat}',
            style: TextStyle(
              fontSize: 11,
              color: hnrColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: children);
  }

  // ── 右侧：ratio / 刷新 + 启用开关 ──
  Widget _buildTrailing(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24, child: _buildTrailingTop(context)),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Switch(
            value: site.isActive,
            onChanged: onToggleActive,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingTop(BuildContext context) {
    if (refreshing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final ratio = userInfo?.ratio;
    if (ratio != null && !(userInfo?.fetchFailed ?? false)) {
      return Text(
        _formatRatio(ratio),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _ratioColor(ratio),
        ),
      );
    }
    if (hasCookie && onRefresh != null) {
      return InkWell(
        onTap: onRefresh,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.refresh, size: 20),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _formatRatio(double ratio) {
    if (ratio == double.infinity) return '∞';
    return ratio.toStringAsFixed(2);
  }

  Color _ratioColor(double ratio) {
    if (ratio == double.infinity || ratio >= 2.0) return const Color(0xFF34C759);
    if (ratio >= 1.0) return const Color(0xFF007AFF);
    return const Color(0xFFFF3B30);
  }

  String formatNumber(num n) {
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }
}

/// 红色未读徽标
class _UnreadBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _UnreadBadge({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Semantics(
      label: '$count 条未读消息',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
```

> 确认 `lib/utils/helpers.dart` 暴露 `formatBytes(num)`，已有则直接用；如签名不同（接受 `int`）则改 `formatBytes(info.uploaded!)`。
> 若没有此方法则在 helpers.dart 加：
> ```dart
> String formatBytes(num bytes) {
>   const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
>   var size = bytes.toDouble();
>   var i = 0;
>   while (size >= 1024 && i < units.length - 1) {
>     size /= 1024; i++;
>   }
>   return '${size.toStringAsFixed(size >= 100 ? 0 : (size >= 10 ? 1 : 2))} ${units[i]}';
> }
> ```

- [ ] **Step 4: 跑测试确认通过**

```bash
flutter test test/widgets/site_tile_test.dart
```

Expected: 8 个 test 全 PASS。

- [ ] **Step 5: 跑全量测试**

```bash
flutter test
```

Expected: 全部测试通过。

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/site_tile.dart test/widgets/site_tile_test.dart lib/utils/helpers.dart
git commit -m "feat(site): SiteTile 4 行紧凑布局 + 未读 / H&R 徽标"
```

---

### Task 6: `site_list_screen.dart` 绑定 onOpenMessages

**Files:**
- Modify: `lib/screens/site_list_screen.dart`

- [ ] **Step 1: 在 SiteTile 构造里追加 onOpenMessages**

找到 `SiteTile(...)` 调用处，在 `onToggleActive` 后追加一行：

```dart
                        onOpenMessages: () => _openMessages(
                          context,
                          site,
                          provider,
                        ),
```

- [ ] **Step 2: 加 `_openMessages` 私有方法**

在 `_refreshAll` 方法之前插入：

```dart
  void _openMessages(
    BuildContext context,
    SiteConfig site,
    SiteProvider provider,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    if (!provider.hasCookie(site.id)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先配置 Cookie')),
      );
      return;
    }
    if (site.baseUrl == null || site.baseUrl!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('该站点未配置 URL')),
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

- [ ] **Step 3: 顶部 import 区域追加**

```dart
import '../services/site_service.dart';
import '../screens/site_webview_screen.dart';
```

- [ ] **Step 4: 跑分析 + 全部测试**

```bash
flutter analyze lib/screens/site_list_screen.dart
flutter test
```

Expected: `flutter analyze` 0 错误；`flutter test` 全部通过。

- [ ] **Step 5: 手动验收（开发机）**

```bash
flutter run -d <device>
```

操作：
1. 站点列表页应显示紧凑 4 行卡片
2. 任意一个有 cookie 的 NexusPHP 站应显示未读徽标（数字或 99+）
3. 任意一个有 H&R 警告的站应显示 ⚠N 徽标
4. 点击未读徽标 → 跳转 WebView 屏加载 `/messages.php`
5. 关闭启用开关 → 整行 opacity 0.5
6. Gazelle 站点的消息页路径应解析为 `/inbox.php`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/site_list_screen.dart
git commit -m "feat(site): 站点列表点击未读徽标跳消息页 WebView"
```

---

### Task 7: 静态检查与文档同步

**Files:**
- (no file changes; verification only)

- [ ] **Step 1: dart format**

```bash
dart format lib/ test/
```

Expected: 无变更或仅空格修正。

- [ ] **Step 2: flutter analyze**

```bash
flutter analyze
```

Expected: 0 error / 0 warning（info 可忽略）。

- [ ] **Step 3: 全量测试**

```bash
flutter test
```

Expected: 全部 PASS（包含新加的 4 个测试文件）。

- [ ] **Step 4: 全量 commit（若 format/analyze 修了东西）**

```bash
git status
git add -A
git diff --cached --quiet || git commit -m "style: dart format / analyze 收尾"
```

- [ ] **Step 5: 在 `docs/superpowers/specs/2026-06-16-site-list-info-and-unread-design.md` 末尾追加「实施状态」**

> 实施完成于 <date>。涉及改动：
> - `lib/services/site_service.dart`（`messagePathFor`）
> - `lib/providers/site_provider.dart`（`unreadTotal`）
> - `lib/screens/site_webview_screen.dart`（新建）
> - `lib/widgets/site_tile.dart`（4 行布局 + 徽标）
> - `lib/screens/site_list_screen.dart`（绑定 `onOpenMessages`）

- [ ] **Step 6: Commit 文档更新**

```bash
git add docs/superpowers/specs/2026-06-16-site-list-info-and-unread-design.md
git commit -m "docs: 站点列表未读消息设计标注实施完成"
```
