# 站点管理功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 bit-manager 新增完整的 PT 站点管理模块（CRUD、分组标签、预设导入、图标、Cookie 管理、用户信息抓取），底部导航从 3 Tab 改为 4 Tab（站点 → 下载器管理 → 种子 → 设置）。

**Architecture:** 新增独立 `SiteProvider` + `SiteService`，不依赖现有 Provider。站点数据存 SharedPreferences JSON，Cookie 存 SecureStorage，预设 JSON 和图标打包到 assets。沿用现有 `provider` + `ChangeNotifier` 模式、`LocalStorage` 封装和 Material 3 设计风格。

**Tech Stack:** Flutter 3.12+, provider, dio, shared_preferences, flutter_secure_storage, webview_flutter, uuid, intl

---

### Task 1: 数据模型 — SiteConfig / SitePreset / SiteCookie / SiteUserInfo

**Files:**
- Create: `lib/models/site_config.dart`
- Create: `test/models/site_config_test.dart`

- [ ] **Step 1: 创建数据模型文件**

```dart
// lib/models/site_config.dart

/// 站点配置 — 用户管理的站点实体
class SiteConfig {
  final String id;
  String name;
  String? baseUrl;
  List<String> tags;
  String? notes;
  bool isActive;
  int sortOrder;
  DateTime addedAt;

  SiteConfig({
    required this.id,
    required this.name,
    this.baseUrl,
    List<String>? tags,
    this.notes,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? addedAt,
  })  : tags = tags ?? [],
        addedAt = addedAt ?? DateTime.now();

  SiteConfig copyWith({
    String? name,
    String? baseUrl,
    List<String>? tags,
    String? notes,
    bool? isActive,
    int? sortOrder,
  }) {
    return SiteConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      tags: tags ?? List.from(this.tags),
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'tags': tags,
        'notes': notes,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SiteConfig.fromJson(Map<String, dynamic> json) => SiteConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        notes: json['notes'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        sortOrder: json['sortOrder'] as int? ?? 0,
        addedAt:
            DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// 站点预设 — 内置只读数据，从 assets/sites/presets.json 加载
class SitePreset {
  final String id;
  final String name;
  final String? baseUrl;
  final List<String> tags;
  final String? iconAsset;
  final String? category;

  const SitePreset({
    required this.id,
    required this.name,
    this.baseUrl,
    this.tags = const [],
    this.iconAsset,
    this.category,
  });

  factory SitePreset.fromJson(Map<String, dynamic> json) => SitePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        iconAsset: json['iconAsset'] as String?,
        category: json['category'] as String?,
      );
}

/// 站点用户信息 — 通过 Cookie 抓取
class SiteUserInfo {
  final String siteId;
  String? username;
  int? uploaded;
  int? downloaded;
  double? ratio;
  String? level;
  int? bonusPoints;
  int? seedingCount;
  int? leechingCount;
  DateTime? lastFetchedAt;
  bool fetchFailed;

  SiteUserInfo({
    required this.siteId,
    this.username,
    this.uploaded,
    this.downloaded,
    this.ratio,
    this.level,
    this.bonusPoints,
    this.seedingCount,
    this.leechingCount,
    this.lastFetchedAt,
    this.fetchFailed = false,
  });

  Map<String, dynamic> toJson() => {
        'siteId': siteId,
        'username': username,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'ratio': ratio,
        'level': level,
        'bonusPoints': bonusPoints,
        'seedingCount': seedingCount,
        'leechingCount': leechingCount,
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
        'fetchFailed': fetchFailed,
      };

  factory SiteUserInfo.fromJson(Map<String, dynamic> json) => SiteUserInfo(
        siteId: json['siteId'] as String,
        username: json['username'] as String?,
        uploaded: json['uploaded'] as int?,
        downloaded: json['downloaded'] as int?,
        ratio: (json['ratio'] as num?)?.toDouble(),
        level: json['level'] as String?,
        bonusPoints: json['bonusPoints'] as int?,
        seedingCount: json['seedingCount'] as int?,
        leechingCount: json['leechingCount'] as int?,
        lastFetchedAt: DateTime.tryParse(json['lastFetchedAt'] as String? ?? ''),
        fetchFailed: json['fetchFailed'] as bool? ?? false,
      );
}

/// Cookie 存储 — 存 SecureStorage，此类只作内存载体
class SiteCookie {
  final String siteId;
  String? cookieString;
  DateTime? lastUpdatedAt;
  bool isLoginValid;

  SiteCookie({
    required this.siteId,
    this.cookieString,
    this.lastUpdatedAt,
    this.isLoginValid = false,
  });
}
```

- [ ] **Step 2: 编写模型测试**

```dart
// test/models/site_config_test.dart

import 'package:bit_manager/models/site_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SiteConfig', () {
    test('fromJson / toJson round-trip', () {
      final original = SiteConfig(
        id: 'm-team',
        name: 'M-Team',
        baseUrl: 'https://m-team.cc',
        tags: ['电影', '官组'],
        notes: '测试备注',
        isActive: true,
        sortOrder: 3,
      );
      final json = original.toJson();
      final restored = SiteConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.baseUrl, original.baseUrl);
      expect(restored.tags, original.tags);
      expect(restored.notes, original.notes);
      expect(restored.isActive, original.isActive);
      expect(restored.sortOrder, original.sortOrder);
    });

    test('copyWith preserves id and addedAt', () {
      final original = SiteConfig(
        id: 'hdtime',
        name: 'HDTime',
        baseUrl: 'https://hdtime.org',
      );
      final copy = original.copyWith(name: 'HDTime-New', sortOrder: 5);

      expect(copy.id, 'hdtime');
      expect(copy.name, 'HDTime-New');
      expect(copy.sortOrder, 5);
      expect(copy.addedAt, original.addedAt);
      expect(copy.baseUrl, 'https://hdtime.org');
    });

    test('default values', () {
      final config = SiteConfig(id: 'test', name: 'Test');
      expect(config.tags, isEmpty);
      expect(config.isActive, true);
      expect(config.sortOrder, 0);
      expect(config.notes, isNull);
    });
  });

  group('SitePreset', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'm-team',
        'name': 'M-Team',
        'baseUrl': 'https://m-team.cc',
        'tags': ['电影', '综合'],
        'iconAsset': 'assets/sites/icons/m-team.ico',
        'category': '影视',
      };
      final preset = SitePreset.fromJson(json);

      expect(preset.id, 'm-team');
      expect(preset.name, 'M-Team');
      expect(preset.baseUrl, 'https://m-team.cc');
      expect(preset.tags, ['电影', '综合']);
      expect(preset.iconAsset, 'assets/sites/icons/m-team.ico');
      expect(preset.category, '影视');
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 'test', 'name': 'Test'};
      final preset = SitePreset.fromJson(json);

      expect(preset.baseUrl, isNull);
      expect(preset.tags, isEmpty);
      expect(preset.iconAsset, isNull);
      expect(preset.category, isNull);
    });
  });

  group('SiteUserInfo', () {
    test('fromJson / toJson round-trip', () {
      final original = SiteUserInfo(
        siteId: 'm-team',
        username: 'testuser',
        uploaded: 1073741824,
        downloaded: 536870912,
        ratio: 2.0,
        level: 'Elite',
        bonusPoints: 5000,
        seedingCount: 42,
        leechingCount: 3,
        lastFetchedAt: DateTime(2026, 6, 10),
        fetchFailed: false,
      );
      final json = original.toJson();
      final restored = SiteUserInfo.fromJson(json);

      expect(restored.siteId, original.siteId);
      expect(restored.username, original.username);
      expect(restored.uploaded, original.uploaded);
      expect(restored.downloaded, original.downloaded);
      expect(restored.ratio, original.ratio);
      expect(restored.level, original.level);
      expect(restored.bonusPoints, original.bonusPoints);
      expect(restored.seedingCount, original.seedingCount);
      expect(restored.leechingCount, original.leechingCount);
      expect(restored.fetchFailed, false);
    });

    test('default values', () {
      final info = SiteUserInfo(siteId: 'test');
      expect(info.username, isNull);
      expect(info.fetchFailed, false);
    });
  });

  group('SiteCookie', () {
    test('default values', () {
      final cookie = SiteCookie(siteId: 'test');
      expect(cookie.siteId, 'test');
      expect(cookie.cookieString, isNull);
      expect(cookie.isLoginValid, false);
    });
  });
}
```

- [ ] **Step 3: 运行测试确认通过**

```bash
flutter test test/models/site_config_test.dart
```

- [ ] **Step 4: 提交**

```bash
git add lib/models/site_config.dart test/models/site_config_test.dart
git commit -m "feat: 添加站点管理数据模型 SiteConfig / SitePreset / SiteUserInfo / SiteCookie"
```

---

### Task 2: 站点预设 JSON 和图标资源

**Files:**
- Create: `assets/sites/presets.json`
- Create: `assets/sites/icons/` (219 个图标文件)
- Modify: `pubspec.yaml`

- [ ] **Step 1: 从 PT-depiler 导出站点预设 JSON**

执行以下脚本将 PT-depiler 的 287 个站点定义转化为精简 JSON：

```bash
# 用 Node.js 脚本解析 PT-depiler 的站点定义文件并输出 presets.json
node -e "
const fs = require('fs');
const path = require('path');
const defsDir = '/tmp/pt-depiler-ref/src/packages/site/definitions';
const files = fs.readdirSync(defsDir).filter(f => f.endsWith('.ts'));
const results = [];

for (const file of files) {
  const content = fs.readFileSync(path.join(defsDir, file), 'utf-8');
  const siteId = file.replace('.ts', '');

  // 提取 name
  const nameMatch = content.match(/name:\s*['\"](.+?)['\"]/);
  const name = nameMatch ? nameMatch[1] : siteId;

  // 提取 type
  const typeMatch = content.match(/type:\s*['\"](.+?)['\"]/);
  const type = typeMatch ? typeMatch[1] : 'private';

  // 提取 tags
  const tagsMatch = content.match(/tags:\s*\[([^\]]*)\]/);
  const tags = tagsMatch
    ? tagsMatch[1].split(',').map(t => t.trim().replace(/['\"]/g, '')).filter(Boolean)
    : [];

  // 提取 schema
  const schemaMatch = content.match(/schema:\s*['\"](.+?)['\"]/);
  const schema = schemaMatch ? schemaMatch[1] : null;

  // 提取 urls（主 URL）
  const urlMatch = content.match(/url:\s*['\"](https?:\/\/[^'\"]+)['\"]/);
  const baseUrl = urlMatch ? urlMatch[1] : null;

  // 推断分类
  let category = '综合';
  if (tags.some(t => ['音乐', 'audio', 'music'].includes(t.toLowerCase()))) category = '音乐';
  else if (tags.some(t => ['电影', 'movie', '影视'].includes(t.toLowerCase()))) category = '影视';
  else if (tags.some(t => ['教育', 'edu', 'university'].includes(t.toLowerCase()))) category = '教育';
  else if (tags.some(t => ['动漫', 'anime'].includes(t.toLowerCase()))) category = '动漫';
  else if (tags.some(t => ['电子书', 'ebook', '图书'].includes(t.toLowerCase()))) category = '电子书';
  else if (tags.some(t => ['体育', 'sport'].includes(t.toLowerCase()))) category = '体育';
  else if (tags.some(t => ['软件', 'software'].includes(t.toLowerCase()))) category = '软件';
  else if (tags.some(t => ['游戏', 'game'].includes(t.toLowerCase()))) category = '游戏';
  else if (type === 'public') category = '公网';

  // 检查图标文件是否存在
  const iconExts = ['.ico', '.png', '.jpg', '.gif', '.svg', '.webp'];
  let iconAsset = null;
  for (const ext of iconExts) {
    if (fs.existsSync(path.join('/tmp/pt-depiler-ref/public/icons/site', siteId + ext))) {
      iconAsset = 'assets/sites/icons/' + siteId + ext;
      break;
    }
  }

  results.push({ id: siteId, name, baseUrl, tags, category, iconAsset });
}

fs.writeFileSync('assets/sites/presets.json', JSON.stringify(results, null, 2));
console.log('Written ' + results.length + ' presets');
" 2>&1
```

- [ ] **Step 2: 复制站点图标文件**

```bash
mkdir -p assets/sites/icons
cp /tmp/pt-depiler-ref/public/icons/site/* assets/sites/icons/ 2>&1
```

- [ ] **Step 3: 更新 pubspec.yaml 注册 assets**

修改 `pubspec.yaml`，在 `flutter:` 块中添加 assets：

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/sites/presets.json
    - assets/sites/icons/
```

以及添加 webview_flutter 依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  dio: ^5.7.0
  shared_preferences: ^2.3.3
  uuid: ^4.5.1
  intl: ^0.19.0
  flutter_secure_storage: ^9.2.4
  webview_flutter: ^4.10.0
```

- [ ] **Step 4: 运行 flutter pub get 确认依赖正常**

```bash
flutter pub get
```

- [ ] **Step 5: 提交**

```bash
git add assets/sites/presets.json assets/sites/icons/ pubspec.yaml pubspec.lock
git commit -m "feat: 添加站点预设 JSON、图标资源和 webview_flutter 依赖"
```

---

### Task 3: SiteProvider — 站点 CRUD + Cookie 管理 + 用户信息存储

**Files:**
- Create: `lib/providers/site_provider.dart`
- Create: `test/providers/site_provider_test.dart`

- [ ] **Step 1: 编写 Provider 测试（TDD）**

```dart
// test/providers/site_provider_test.dart

import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig testSite(String id) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: ['电影'],
    );

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

  group('站点 CRUD', () {
    test('addSite 添加站点并通知监听者', () async {
      final provider = SiteProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.addSite(testSite('site-1'));

      expect(provider.sites.length, 1);
      expect(provider.sites.first.id, 'site-1');
      expect(notified, true);
    });

    test('updateSite 更新站点并通知监听者', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      var notified = false;
      provider.addListener(() => notified = true);

      final updated = testSite('site-1').copyWith(name: 'Updated');
      await provider.updateSite('site-1', updated);

      expect(provider.sites.first.name, 'Updated');
      expect(notified, true);
    });

    test('deleteSite 删除站点并通知监听者', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));
      await provider.addSite(testSite('site-2'));

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.deleteSite('site-1');

      expect(provider.sites.length, 1);
      expect(provider.sites.first.id, 'site-2');
      expect(notified, true);
    });

    test('loadSites 从存储加载站点', () async {
      // 先写入数据
      final provider1 = SiteProvider();
      await provider1.addSite(testSite('site-1'));
      await provider1.addSite(testSite('site-2'));

      // 新建 provider 加载
      final provider2 = SiteProvider();
      await provider2.loadSites();

      expect(provider2.sites.length, 2);
      expect(provider2.sites.map((s) => s.id), containsAll(['site-1', 'site-2']));
    });

    test('addSite 不允许重复 id', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      await provider.addSite(testSite('site-1'));
      expect(provider.sites.length, 1);
    });
  });

  group('预设导入', () {
    test('importPresets 批量导入预设', () async {
      final provider = SiteProvider();
      final presets = [
        const SitePreset(id: 'a', name: 'A'),
        const SitePreset(id: 'b', name: 'B'),
      ];

      await provider.importPresets(presets);

      expect(provider.sites.length, 2);
      expect(provider.sites.first.sortOrder, 1);
      expect(provider.sites.last.sortOrder, 2);
    });

    test('importPresets 跳过已存在的站点', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('a'));

      final presets = [
        const SitePreset(id: 'a', name: 'A-New'),
        const SitePreset(id: 'b', name: 'B'),
      ];

      await provider.importPresets(presets);

      expect(provider.sites.length, 2);
      expect(provider.sites.firstWhere((s) => s.id == 'a').name, 'Site a');
    });
  });

  group('Cookie 管理', () {
    test('saveCookie 持久化并通知', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.saveCookie('site-1', 'uid=123; pass=abc');

      expect(provider.getCookieString('site-1'), 'uid=123; pass=abc');
      expect(notified, true);
    });

    test('deleteCookie 清除 cookie', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));
      await provider.saveCookie('site-1', 'uid=123');

      await provider.deleteCookie('site-1');

      expect(provider.getCookieString('site-1'), isNull);
    });
  });

  group('用户信息', () {
    test('updateUserInfo 更新并通知', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      final info = SiteUserInfo(
        siteId: 'site-1',
        username: 'testuser',
        ratio: 2.5,
        uploaded: 1000,
      );

      var notified = false;
      provider.addListener(() => notified = true);

      await provider.updateUserInfo(info);

      expect(provider.getUserInfo('site-1')?.username, 'testuser');
      expect(provider.getUserInfo('site-1')?.ratio, 2.5);
      expect(notified, true);
    });

    test('getUserInfo 返回 null（无数据）', () async {
      final provider = SiteProvider();
      await provider.addSite(testSite('site-1'));

      expect(provider.getUserInfo('site-1'), isNull);
    });
  });

  group('筛选与搜索', () {
    test('filteredSites 按搜索关键词过滤', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      provider.searchQuery = 'Alpha';
      expect(provider.filteredSites.length, 1);
      expect(provider.filteredSites.first.name, 'Alpha');

      provider.searchQuery = '';
      expect(provider.filteredSites.length, 2);
    });

    test('filteredSites 按标签过滤', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      provider.tagFilter = '电影';
      expect(provider.filteredSites.length, 1);
      expect(provider.filteredSites.first.name, 'Alpha');

      provider.tagFilter = null;
      expect(provider.filteredSites.length, 2);
    });

    test('allTags 收集所有站点的标签', () async {
      final provider = SiteProvider();
      await provider.addSite(SiteConfig(id: 'a', name: 'Alpha', tags: ['电影', '官组']));
      await provider.addSite(SiteConfig(id: 'b', name: 'Beta', tags: ['音乐']));

      expect(provider.allTags, containsAll(['电影', '官组', '音乐']));
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/providers/site_provider_test.dart
```

预期：所有测试 FAIL（SiteProvider 类不存在）

- [ ] **Step 3: 实现 SiteProvider**

```dart
// lib/providers/site_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/site_config.dart';
import '../utils/storage.dart';

class SiteProvider extends ChangeNotifier {
  static const String _storageKey = 'sites';
  static const String _userInfoKey = 'site_user_info';

  List<SiteConfig> _sites = [];
  final Map<String, SiteUserInfo> _userInfo = {};
  final Map<String, String> _cookies = {};
  bool _loading = false;
  String _searchQuery = '';
  String? _tagFilter;

  List<SiteConfig> get sites => List.unmodifiable(_sites);
  Map<String, SiteUserInfo> get userInfo => Map.unmodifiable(_userInfo);
  bool get loading => _loading;

  String get searchQuery => _searchQuery;
  set searchQuery(String v) {
    if (_searchQuery != v) {
      _searchQuery = v;
      notifyListeners();
    }
  }

  String? get tagFilter => _tagFilter;
  set tagFilter(String? v) {
    if (_tagFilter != v) {
      _tagFilter = v;
      notifyListeners();
    }
  }

  List<SiteConfig> get filteredSites {
    var result = _sites;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    if (_tagFilter != null && _tagFilter!.isNotEmpty) {
      result = result.where((s) => s.tags.contains(_tagFilter!)).toList();
    }
    return result;
  }

  Set<String> get allTags {
    final tags = <String>{};
    for (final site in _sites) {
      tags.addAll(site.tags);
    }
    return tags;
  }

  /// 从本地存储加载站点配置、Cookie 和用户信息
  Future<void> loadSites() async {
    _loading = true;
    notifyListeners();

    try {
      final storage = await LocalStorage.getInstance();

      // 加载站点配置
      final rawList = await storage.getJsonList(_storageKey);
      _sites = rawList.map((json) => SiteConfig.fromJson(json)).toList();

      // 加载 Cookie
      for (final site in _sites) {
        final cookie = await storage.getString('cookie_${site.id}');
        if (cookie != null && cookie.isNotEmpty) {
          _cookies[site.id] = cookie;
        }
      }

      // 加载用户信息
      final uiRaw = await storage.getString(_userInfoKey);
      if (uiRaw != null) {
        final map = jsonDecode(uiRaw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          final infoMap = entry.value as Map<String, dynamic>;
          _userInfo[entry.key] = SiteUserInfo.fromJson(infoMap);
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 持久化站点列表到 SharedPreferences
  Future<void> _saveSites() async {
    final storage = await LocalStorage.getInstance();
    await storage.saveJsonList(
      _storageKey,
      _sites.map((s) => s.toJson()).toList(),
    );
  }

  /// 持久化用户信息
  Future<void> _saveUserInfo() async {
    final storage = await LocalStorage.getInstance();
    final map = <String, dynamic>{};
    for (final entry in _userInfo.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await storage.setString(_userInfoKey, jsonEncode(map));
  }

  /// 添加站点，重复 id 则忽略
  Future<void> addSite(SiteConfig config) async {
    if (_sites.any((s) => s.id == config.id)) return;
    config.sortOrder = _sites.isEmpty ? 1 : _sites.last.sortOrder + 1;
    _sites.add(config);
    await _saveSites();
    notifyListeners();
  }

  /// 更新站点
  Future<void> updateSite(String id, SiteConfig updated) async {
    final index = _sites.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sites[index] = updated;
      await _saveSites();
      notifyListeners();
    }
  }

  /// 删除站点及其关联的 Cookie 和用户信息
  Future<void> deleteSite(String id) async {
    _sites.removeWhere((s) => s.id == id);
    _cookies.remove(id);
    _userInfo.remove(id);
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$id', '');
    await _saveSites();
    await _saveUserInfo();
    notifyListeners();
  }

  /// 批量导入预设，跳过已存在的站点
  Future<int> importPresets(List<SitePreset> presets) async {
    int count = 0;
    for (final preset in presets) {
      if (_sites.any((s) => s.id == preset.id)) continue;
      final config = SiteConfig(
        id: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        tags: List.from(preset.tags),
        sortOrder: _sites.isEmpty ? 1 : _sites.last.sortOrder + 1,
      );
      _sites.add(config);
      count++;
    }
    if (count > 0) {
      await _saveSites();
      notifyListeners();
    }
    return count;
  }

  /// 检查站点 id 是否已导入
  bool isSiteImported(String siteId) => _sites.any((s) => s.id == siteId);

  // ── Cookie 管理 ──

  /// 保存 cookie 到 SecureStorage
  Future<void> saveCookie(String siteId, String cookie) async {
    _cookies[siteId] = cookie;
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$siteId', cookie);
    notifyListeners();
  }

  /// 获取 cookie 字符串
  String? getCookieString(String siteId) => _cookies[siteId];

  /// 检查是否有 cookie
  bool hasCookie(String siteId) {
    final c = _cookies[siteId];
    return c != null && c.isNotEmpty;
  }

  /// 删除 cookie
  Future<void> deleteCookie(String siteId) async {
    _cookies.remove(siteId);
    final storage = await LocalStorage.getInstance();
    await storage.setString('cookie_$siteId', '');
    notifyListeners();
  }

  // ── 用户信息 ──

  /// 获取站点用户信息
  SiteUserInfo? getUserInfo(String siteId) => _userInfo[siteId];

  /// 更新用户信息
  Future<void> updateUserInfo(SiteUserInfo info) async {
    _userInfo[info.siteId] = info;
    await _saveUserInfo();
    notifyListeners();
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/providers/site_provider_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add lib/providers/site_provider.dart test/providers/site_provider_test.dart
git commit -m "feat: 添加 SiteProvider — 站点 CRUD、Cookie 管理、用户信息存储"
```

---

### Task 4: SiteService — 用户信息抓取服务

**Files:**
- Create: `lib/services/site_service.dart`
- Create: `test/services/site_service_test.dart`

- [ ] **Step 1: 编写 Service 测试（TDD）**

```dart
// test/services/site_service_test.dart

import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fetchUserInfo', () {
    test('返回 null（cookie 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://example.com',
      );
      final result = await service.fetchUserInfo(config, null);
      expect(result, isNull);
    });

    test('返回 null（baseUrl 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(id: 'test', name: 'Test');
      final result = await service.fetchUserInfo(config, 'uid=123');
      expect(result, isNull);
    });
  });

  group('parseSize', () {
    test('解析 "1.23 TB"', () {
      expect(SiteService.parseSize('1.23 TB'), closeTo(1352399302164, 1));
    });

    test('解析 "500 GB"', () {
      expect(SiteService.parseSize('500 GB'), closeTo(536870912000, 1));
    });

    test('解析 "100 MB"', () {
      expect(SiteService.parseSize('100 MB'), closeTo(104857600, 1));
    });

    test('解析 "50 KB"', () {
      expect(SiteService.parseSize('50 KB'), 51200);
    });

    test('解析纯数字', () {
      expect(SiteService.parseSize('12345'), 12345);
    });

    test('解析空字符串', () {
      expect(SiteService.parseSize(''), isNull);
      expect(SiteService.parseSize(null), isNull);
    });
  });

  group('parseRatio', () {
    test('解析 "2.5"', () {
      expect(SiteService.parseRatio('2.5'), closeTo(2.5, 0.01));
    });

    test('解析 "∞" 或 "Inf."', () {
      expect(SiteService.parseRatio('∞'), double.infinity);
      expect(SiteService.parseRatio('Inf.'), double.infinity);
    });

    test('解析空字符串', () {
      expect(SiteService.parseRatio(''), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/services/site_service_test.dart
```

- [ ] **Step 3: 实现 SiteService**

```dart
// lib/services/site_service.dart

import 'package:dio/dio.dart';
import '../models/site_config.dart';

class SiteService {
  final Dio _dio;

  SiteService() : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  /// 抓取站点用户信息
  /// 返回 null 表示抓取失败
  Future<SiteUserInfo?> fetchUserInfo(SiteConfig config, String? cookie) async {
    if (cookie == null || cookie.isEmpty) return null;
    if (config.baseUrl == null || config.baseUrl!.isEmpty) return null;

    try {
      final response = await _dio.get(
        config.baseUrl!,
        options: Options(
          headers: {'Cookie': cookie},
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode != 200) return null;

      final html = response.data?.toString() ?? '';
      if (html.isEmpty) return null;

      return _parseHtml(config.id, html);
    } catch (_) {
      return null;
    }
  }

  /// 从 HTML 中提取用户信息
  /// 使用通用模式匹配常见 PT 站点框架（NexusPHP / Gazelle / Unit3D）
  SiteUserInfo _parseHtml(String siteId, String html) {
    final info = SiteUserInfo(siteId: siteId);

    // 用户名：常见模式 class="username" / id="userinfo" / 导航栏用户链接
    final usernamePatterns = [
      RegExp(r'class="[^"]*username[^"]*"[^>]*>([^<]+)<'),
      RegExp(r'id="userinfo"[^>]*>.*?<a[^>]*>([^<]+)<'),
      RegExp(r'<a[^>]*href="[^"]*user[^"]*"[^>]*>([^<]+)</a>'),
    ];
    for (final p in usernamePatterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        info.username = m.group(1)?.trim();
        break;
      }
    }

    // 分享率
    info.ratio = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:分享率|ratio|分享比率)[\s:：]*([\d.]+|∞|Inf\.)'),
        RegExp(r'id="ratio"[^>]*>([^<]+)<'),
      ],
      parser: parseRatio,
    );

    // 上传量
    info.uploaded = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:上传|uploaded|上传量)[\s:：]*([\d.]+\s*(?:TB|GB|MB|KB|B|TiB|GiB|MiB|KiB))'),
        RegExp(r'id="uploaded"[^>]*>([^<]+)<'),
      ],
      parser: parseSize,
    );

    // 下载量
    info.downloaded = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:下载|downloaded|下载量)[\s:：]*([\d.]+\s*(?:TB|GB|MB|KB|B|TiB|GiB|MiB|KiB))'),
        RegExp(r'id="downloaded"[^>]*>([^<]+)<'),
      ],
      parser: parseSize,
    );

    // 等级
    final levelPatterns = [
      RegExp(r'(?:等级|class|用户等级)[\s:：]*<[^>]*>([^<]+)<'),
      RegExp(r'class="[^"]*level[^"]*"[^>]*>([^<]+)<'),
    ];
    for (final p in levelPatterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        info.level = m.group(1)?.trim();
        break;
      }
    }

    // 魔力值
    info.bonusPoints = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:魔力|bonus|积分|Karma|BP)[\s:：]*([\d,]+)'),
      ],
      parser: (s) => int.tryParse(s?.replaceAll(',', '') ?? ''),
    );

    // 做种数
    info.seedingCount = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:做种|seeding|做种数)[\s:：]*(\d+)'),
      ],
      parser: (s) => int.tryParse(s ?? ''),
    );

    // 下载数
    info.leechingCount = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:下载中|leeching|下载数)[\s:：]*(\d+)'),
      ],
      parser: (s) => int.tryParse(s ?? ''),
    );

    info.lastFetchedAt = DateTime.now();
    info.fetchFailed = false;

    return info;
  }

  /// 从 HTML 中按多个正则模式依次尝试提取值
  T? _extractNumber<T>(
    String html, {
    required List<RegExp> patterns,
    required T? Function(String?) parser,
  }) {
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        final result = parser(m.group(1));
        if (result != null) return result;
      }
    }
    return null;
  }

  /// 解析文件大小字符串（如 "1.23 TB", "500 GB"）为字节数
  static int? parseSize(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim().replaceAll(',', '');

    final units = {
      'TiB': 1099511627776,
      'GiB': 1073741824,
      'MiB': 1048576,
      'KiB': 1024,
      'TB': 1000000000000,
      'GB': 1000000000,
      'MB': 1000000,
      'KB': 1000,
      'B': 1,
    };

    for (final entry in units.entries) {
      if (s.endsWith(entry.key)) {
        final numStr = s.substring(0, s.length - entry.key.length).trim();
        final num = double.tryParse(numStr);
        if (num != null) return (num * entry.value).round();
        return null;
      }
    }

    // 纯数字
    return int.tryParse(s);
  }

  /// 解析分享率字符串
  static double? parseRatio(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim();
    if (s == '∞' || s == 'Inf.' || s == 'Infinity') return double.infinity;
    return double.tryParse(s);
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/services/site_service_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add lib/services/site_service.dart test/services/site_service_test.dart
git commit -m "feat: 添加 SiteService — 通过 Cookie 抓取站点用户信息"
```

---

### Task 5: 站点图标组件 — SiteFavicon

**Files:**
- Create: `lib/widgets/site_favicon.dart`

- [ ] **Step 1: 实现 SiteFavicon 组件**

```dart
// lib/widgets/site_favicon.dart

import 'package:flutter/material.dart';

/// 站点图标组件
/// 从 assets/sites/icons/ 加载图标，失败时显示首字母占位符
class SiteFavicon extends StatelessWidget {
  final String? iconAsset;
  final String siteName;
  final double size;
  final double radius;

  const SiteFavicon({
    super.key,
    this.iconAsset,
    required this.siteName,
    this.size = 40,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (iconAsset != null && iconAsset!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            iconAsset!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholder(context),
          ),
        ),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    final letter = siteName.isNotEmpty ? siteName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/widgets/site_favicon.dart
git commit -m "feat: 添加 SiteFavicon 站点图标组件"
```

---

### Task 6: 站点列表项组件 — SiteTile

**Files:**
- Create: `lib/widgets/site_tile.dart`

- [ ] **Step 1: 实现 SiteTile 组件**

```dart
// lib/widgets/site_tile.dart

import 'package:flutter/material.dart';
import '../models/site_config.dart';
import 'site_favicon.dart';
import '../utils/helpers.dart';

/// 站点列表项 — 展示图标、名称、标签、用户信息摘要
class SiteTile extends StatelessWidget {
  final SiteConfig site;
  final SiteUserInfo? userInfo;
  final bool hasCookie;
  final String? iconAsset;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleActive;

  const SiteTile({
    super.key,
    required this.site,
    this.userInfo,
    this.hasCookie = false,
    this.iconAsset,
    this.onTap,
    this.onToggleActive,
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
                      // 名称行
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              site.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasCookie) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.cookie,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 标签 Chips
                      if (site.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: site.tags
                              .take(3)
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.08),
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
                                  ))
                              .toList(),
                        ),

                      // 用户信息摘要
                      if (userInfo != null) ...[
                        const SizedBox(height: 4),
                        _buildUserSummary(context, userInfo!),
                      ],
                    ],
                  ),
                ),

                // 右侧：分享率 + 启用开关
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (userInfo?.ratio != null)
                      Text(
                        _formatRatio(userInfo!.ratio!),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ratioColor(userInfo!.ratio!),
                        ),
                      ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: site.isActive,
                        onChanged: onToggleActive,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSummary(BuildContext context, SiteUserInfo info) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (info.username != null) parts.add(info.username!);
    if (info.level != null) parts.add(info.level!);
    if (info.uploaded != null) parts.add('↑${formatBytes(info.uploaded!)}');
    if (info.downloaded != null) parts.add('↓${formatBytes(info.downloaded!)}');

    return Text(
      parts.join(' · '),
      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
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
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/widgets/site_tile.dart
git commit -m "feat: 添加 SiteTile 站点列表项组件"
```

---

### Task 7: 站点列表页 — SiteListScreen

**Files:**
- Create: `lib/screens/site_list_screen.dart`

- [ ] **Step 1: 实现 SiteListScreen**

```dart
// lib/screens/site_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../widgets/site_tile.dart';
import '../widgets/empty_state.dart';
import 'site_form_screen.dart';
import 'site_import_screen.dart';
import 'site_detail_screen.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible ? _buildSearchField() : const Text('站点'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  context.read<SiteProvider>().searchQuery = '';
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '导入预设',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SiteImportScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<SiteProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final sites = provider.filteredSites;

          if (provider.sites.isEmpty) {
            return EmptyState(
              icon: Icons.language,
              title: '还没有添加站点',
              subtitle: '添加站点或从预设导入',
              actionLabel: '导入预设',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SiteImportScreen()),
              ),
            );
          }

          if (sites.isEmpty) {
            return EmptyState(
              icon: Icons.search_off,
              title: '没有匹配的站点',
              subtitle: '试试调整搜索条件',
            );
          }

          return Column(
            children: [
              // 标签筛选栏
              if (provider.allTags.isNotEmpty)
                _buildTagFilter(provider),
              // 站点列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: sites.length,
                  itemBuilder: (context, index) {
                    final site = sites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SiteTile(
                        site: site,
                        userInfo: provider.getUserInfo(site.id),
                        hasCookie: provider.hasCookie(site.id),
                        iconAsset: _getIconAsset(site.id),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SiteDetailScreen(site: site),
                          ),
                        ).then((_) => setState(() {})),
                        onToggleActive: (v) {
                          final updated = site.copyWith(isActive: v);
                          provider.updateSite(site.id, updated);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SiteFormScreen()),
        ).then((_) => setState(() {})),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: '搜索站点名称或标签...',
        border: InputBorder.none,
        isDense: true,
      ),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
      onChanged: (v) => context.read<SiteProvider>().searchQuery = v,
    );
  }

  Widget _buildTagFilter(SiteProvider provider) {
    final tags = provider.allTags.toList()..sort();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = provider.tagFilter == null;
            return FilterChip(
              label: const Text('全部'),
              selected: selected,
              onSelected: (_) => provider.tagFilter = null,
              visualDensity: VisualDensity.compact,
            );
          }
          final tag = tags[index - 1];
          final selected = provider.tagFilter == tag;
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => provider.tagFilter = selected ? null : tag,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  /// 根据站点 id 查找预设图标路径
  String? _getIconAsset(String siteId) {
    // 尝试常见图标扩展名
    const exts = ['.ico', '.png', '.jpg', '.gif', '.svg', '.webp'];
    for (final ext in exts) {
      final path = 'assets/sites/icons/$siteId$ext';
      // 简单启发式：所有从 PT-depiler 复制的图标都有 siteId.ext 命名
      // 这里直接返回 .ico 路径（大部分 PT 站点图标是 ico 格式）
      return path;
    }
    return null;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/site_list_screen.dart
git commit -m "feat: 添加 SiteListScreen 站点列表页"
```

---

### Task 8: 站点表单页 — SiteFormScreen

**Files:**
- Create: `lib/screens/site_form_screen.dart`

- [ ] **Step 1: 实现 SiteFormScreen**

```dart
// lib/screens/site_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';

class SiteFormScreen extends StatefulWidget {
  final SiteConfig? site;
  const SiteFormScreen({super.key, this.site});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _notesCtrl;

  bool get isEditing => widget.site != null;

  @override
  void initState() {
    super.initState();
    final s = widget.site;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _urlCtrl = TextEditingController(text: s?.baseUrl ?? '');
    _tagsCtrl = TextEditingController(text: s?.tags.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑站点' : '添加站点')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ID（仅新建时可编辑）
              if (!isEditing)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '站点标识',
                    hintText: '唯一标识，如 m-team',
                    helperText: '仅支持小写字母、数字和连字符',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入站点标识';
                    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                      return '仅支持小写字母、数字和连字符';
                    }
                    return null;
                  },
                  onSaved: (v) {}, // 在 _submit 中处理
                ),
              if (!isEditing) const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如: M-Team',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _urlCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '站点 URL',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tagsCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '电影, 官组, 综合',
                  helperText: '用逗号分隔多个标签',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加一些备注信息...',
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(isEditing ? '保存' : '添加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SiteProvider>();
    final id = widget.site?.id ?? _generateId();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final config = SiteConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      tags: tags,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sortOrder: widget.site?.sortOrder ?? 0,
      addedAt: widget.site?.addedAt,
    );

    if (isEditing) {
      await provider.updateSite(widget.site!.id, config);
    } else {
      await provider.addSite(config);
    }

    if (mounted) Navigator.pop(context);
  }

  String _generateId() {
    final name = _nameCtrl.text.trim().toLowerCase();
    return name.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'-+'), '-');
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/site_form_screen.dart
git commit -m "feat: 添加 SiteFormScreen 站点添加/编辑表单"
```

---

### Task 9: 站点预设导入页 — SiteImportScreen

**Files:**
- Create: `lib/screens/site_import_screen.dart`

- [ ] **Step 1: 实现 SiteImportScreen**

```dart
// lib/screens/site_import_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../widgets/site_favicon.dart';

class SiteImportScreen extends StatefulWidget {
  const SiteImportScreen({super.key});

  @override
  State<SiteImportScreen> createState() => _SiteImportScreenState();
}

class _SiteImportScreenState extends State<SiteImportScreen> {
  List<SitePreset> _allPresets = [];
  List<SitePreset> _filteredPresets = [];
  final _selectedIds = <String>{};
  final _searchCtrl = TextEditingController();
  String? _categoryFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/sites/presets.json');
      final list = jsonDecode(jsonStr) as List;
      _allPresets = list.map((j) => SitePreset.fromJson(j as Map<String, dynamic>)).toList();
      _applyFilters();
    } catch (e) {
      // 预设加载失败
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var result = _allPresets;

    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q) ||
              p.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }

    if (_categoryFilter != null) {
      result = result.where((p) => p.category == _categoryFilter).toList();
    }

    setState(() => _filteredPresets = result);
  }

  Set<String> get _categories {
    final cats = <String>{};
    for (final p in _allPresets) {
      if (p.category != null) cats.add(p.category!);
    }
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('导入站点预设')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: '搜索站点名称...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                ),

                // 分类筛选
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FilterChip(
                          label: const Text('全部'),
                          selected: _categoryFilter == null,
                          onSelected: (_) {
                            _categoryFilter = null;
                            _applyFilters();
                          },
                          visualDensity: VisualDensity.compact,
                        );
                      }
                      final cat = _categories.elementAt(index - 1);
                      return FilterChip(
                        label: Text(cat),
                        selected: _categoryFilter == cat,
                        onSelected: (_) {
                          _categoryFilter = _categoryFilter == cat ? null : cat;
                          _applyFilters();
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // 预设列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredPresets.length,
                    itemBuilder: (context, index) {
                      final preset = _filteredPresets[index];
                      final isImported = provider.isSiteImported(preset.id);
                      final isSelected = _selectedIds.contains(preset.id);

                      return ListTile(
                        leading: SiteFavicon(
                          iconAsset: preset.iconAsset,
                          siteName: preset.name,
                          size: 36,
                          radius: 8,
                        ),
                        title: Text(
                          preset.name,
                          style: TextStyle(
                            color: isImported
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (preset.baseUrl != null) preset.baseUrl!,
                            if (preset.category != null) preset.category!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isImported
                            ? Icon(Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary)
                            : Checkbox(
                                value: isSelected,
                                onChanged: (_) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(preset.id);
                                    } else {
                                      _selectedIds.add(preset.id);
                                    }
                                  });
                                },
                              ),
                        onTap: isImported
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(preset.id);
                                  } else {
                                    _selectedIds.add(preset.id);
                                  }
                                });
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _importSelected(provider),
                  child: Text('导入选中 (${_selectedIds.length})'),
                ),
              ),
            )
          : null,
    );
  }

  Future<void> _importSelected(SiteProvider provider) async {
    final selectedPresets =
        _allPresets.where((p) => _selectedIds.contains(p.id)).toList();
    final count = await provider.importPresets(selectedPresets);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 $count 个站点')),
      );
      setState(() => _selectedIds.clear());
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/site_import_screen.dart
git commit -m "feat: 添加 SiteImportScreen 预设站点导入页"
```

---

### Task 10: 站点详情页 — SiteDetailScreen

**Files:**
- Create: `lib/screens/site_detail_screen.dart`

- [ ] **Step 1: 实现 SiteDetailScreen**

```dart
// lib/screens/site_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../widgets/site_favicon.dart';
import '../utils/helpers.dart';
import 'site_form_screen.dart';
import 'site_cookie_screen.dart';

class SiteDetailScreen extends StatelessWidget {
  final SiteConfig site;

  const SiteDetailScreen({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SiteFormScreen(site: site)),
            ).then((_) {
              // 返回后刷新
            }),
          ),
        ],
      ),
      body: Consumer<SiteProvider>(
        builder: (context, provider, _) {
          final userInfo = provider.getUserInfo(site.id);
          final hasCookie = provider.hasCookie(site.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 基本信息卡片 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 图标 + 名称
                      Row(
                        children: [
                          SiteFavicon(
                            iconAsset: _getIconAsset(site.id),
                            siteName: site.name,
                            size: 56,
                            radius: 14,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  site.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (site.baseUrl != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    site.baseUrl!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 标签
                      if (site.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          children: site.tags
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 备注
                      if (site.notes != null && site.notes!.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          site.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Cookie 状态卡片 ──
              Card(
                child: ListTile(
                  leading: Icon(
                    hasCookie ? Icons.cookie : Icons.cookie_outlined,
                    color: hasCookie
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(hasCookie ? 'Cookie 已配置' : '未配置 Cookie'),
                  subtitle: Text(
                    hasCookie ? '点击管理 Cookie 或刷新用户信息' : '配置 Cookie 以获取用户信息',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiteCookieScreen(site: site),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── 用户信息卡片 ──
              if (userInfo != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              userInfo.username ?? '未知用户',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (userInfo.level != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(userInfo.level!),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 数据网格
                        _buildInfoGrid(context, userInfo),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── 操作按钮 ──
              if (hasCookie)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新用户信息'),
                  onPressed: () {
                    // TODO: Task 12 实现实际抓取调用
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('正在刷新...')),
                    );
                  },
                ),

              const SizedBox(height: 12),

              // 删除按钮
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('删除站点',
                    style: TextStyle(color: Colors.red)),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, SiteUserInfo info) {
    final items = <_InfoItem>[
      _InfoItem('分享率',
          info.ratio == double.infinity ? '∞' : info.ratio?.toStringAsFixed(2)),
      _InfoItem('上传量', info.uploaded != null ? formatBytes(info.uploaded!) : null),
      _InfoItem('下载量', info.downloaded != null ? formatBytes(info.downloaded!) : null),
      _InfoItem('魔力值', info.bonusPoints != null ? info.bonusPoints!.toString() : null),
      _InfoItem('做种数', info.seedingCount?.toString()),
      _InfoItem('下载中', info.leechingCount?.toString()),
    ].where((i) => i.value != null).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除站点'),
        content: Text('确定要删除 "${site.name}" 吗？\n关联的 Cookie 和用户信息也会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<SiteProvider>().deleteSite(site.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  String? _getIconAsset(String siteId) {
    const exts = ['.ico', '.png', '.jpg', '.gif', '.svg', '.webp'];
    for (final ext in exts) {
      return 'assets/sites/icons/$siteId$ext';
    }
    return null;
  }
}

class _InfoItem {
  final String label;
  final String? value;
  _InfoItem(this.label, this.value);
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/site_detail_screen.dart
git commit -m "feat: 添加 SiteDetailScreen 站点详情页"
```

---

### Task 11: Cookie 管理页 — SiteCookieScreen

**Files:**
- Create: `lib/screens/site_cookie_screen.dart`

- [ ] **Step 1: 实现 SiteCookieScreen**

```dart
// lib/screens/site_cookie_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';

class SiteCookieScreen extends StatefulWidget {
  final SiteConfig site;

  const SiteCookieScreen({super.key, required this.site});

  @override
  State<SiteCookieScreen> createState() => _SiteCookieScreenState();
}

class _SiteCookieScreenState extends State<SiteCookieScreen> {
  final _cookieCtrl = TextEditingController();
  bool _webViewVisible = false;
  WebViewController? _webViewCtrl;

  SiteConfig get site => widget.site;

  @override
  void initState() {
    super.initState();
    // 预填现有 cookie
    final provider = context.read<SiteProvider>();
    final existing = provider.getCookieString(site.id);
    if (existing != null) {
      _cookieCtrl.text = existing;
    }
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteProvider>();
    final hasCookie = provider.hasCookie(site.id);

    return Scaffold(
      appBar: AppBar(title: Text('${site.name} · Cookie')),
      body: _webViewVisible ? _buildWebView() : _buildForm(hasCookie),
    );
  }

  Widget _buildForm(bool hasCookie) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 状态卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasCookie ? Icons.check_circle : Icons.info_outline,
                      color: hasCookie ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasCookie ? 'Cookie 已配置' : '未配置 Cookie',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (hasCookie) ...[
                  const SizedBox(height: 8),
                  Text(
                    '配置 Cookie 后可以抓取该站点的用户信息',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 方式一：手动录入
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '手动录入 Cookie',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '从浏览器 DevTools 复制完整的 Cookie 字符串粘贴到下方',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cookieCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'uid=123; pass=abc; ...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _saveManualCookie(provider),
                  child: const Text('保存 Cookie'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 方式二：WebView 登录
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '通过 WebView 登录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '应用内打开 ${site.name} 登录页，登录后自动抓取 Cookie',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('打开登录页'),
                  onPressed: site.baseUrl != null ? _openWebView : null,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 清除 Cookie
        if (hasCookie)
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('清除 Cookie',
                style: TextStyle(color: Colors.red)),
            onPressed: () => _clearCookie(provider),
          ),
      ],
    );
  }

  Widget _buildWebView() {
    if (site.baseUrl == null) {
      return const Center(child: Text('站点没有配置 URL'));
    }

    _webViewCtrl ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // 每次页面加载完成后提取 cookie
            try {
              final result = await _webViewCtrl!
                  .runJavaScriptReturningResult('document.cookie');
              final cookie = result.toString();
              if (cookie.isNotEmpty && cookie != 'null') {
                final provider = context.read<SiteProvider>();
                await provider.saveCookie(site.id, cookie);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cookie 已抓取'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            } catch (_) {}
          },
        ),
      )
      ..loadRequest(Uri.parse(site.baseUrl!));

    return Column(
      children: [
        // 顶部操作栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _webViewVisible = false),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => setState(() => _webViewVisible = false),
                child: const Text('完成登录'),
              ),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: _webViewCtrl!)),
      ],
    );
  }

  Future<void> _saveManualCookie(SiteProvider provider) async {
    final cookie = _cookieCtrl.text.trim();
    if (cookie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Cookie 字符串')),
      );
      return;
    }
    await provider.saveCookie(site.id, cookie);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cookie 已保存'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _clearCookie(SiteProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 Cookie'),
        content: const Text('确定要清除该站点的 Cookie 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteCookie(site.id);
      _cookieCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cookie 已清除')),
        );
      }
    }
  }

  void _openWebView() {
    setState(() => _webViewVisible = true);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/site_cookie_screen.dart
git commit -m "feat: 添加 SiteCookieScreen Cookie 管理页（手动录入 + WebView 登录）"
```

---

### Task 12: 连接用户信息抓取 — SiteDetailScreen 刷新功能

**Files:**
- Modify: `lib/providers/site_provider.dart`
- Modify: `lib/screens/site_detail_screen.dart`

- [ ] **Step 1: 在 SiteProvider 中添加 fetchUserInfo 方法**

在 `lib/providers/site_provider.dart` 中添加 import 和方法：

```dart
// 在文件顶部添加 import
import '../services/site_service.dart';

// 在 SiteProvider 类中添加
final SiteService _siteService = SiteService();

/// 抓取站点用户信息
Future<bool> fetchUserInfo(String siteId) async {
  final site = _sites.firstWhere((s) => s.id == siteId,
      orElse: () => throw StateError('Site $siteId not found'));
  final cookie = _cookies[siteId];

  try {
    final info = await _siteService.fetchUserInfo(site, cookie);
    if (info != null) {
      await updateUserInfo(info);
      return true;
    }
    // 抓取失败，标记
    final failedInfo = SiteUserInfo(
      siteId: siteId,
      fetchFailed: true,
      lastFetchedAt: DateTime.now(),
    );
    await updateUserInfo(failedInfo);
    return false;
  } catch (_) {
    final failedInfo = SiteUserInfo(
      siteId: siteId,
      fetchFailed: true,
      lastFetchedAt: DateTime.now(),
    );
    await updateUserInfo(failedInfo);
    return false;
  }
}
```

- [ ] **Step 2: 更新 SiteDetailScreen 刷新按钮**

修改 `lib/screens/site_detail_screen.dart`，将刷新按钮的 onPressed 改为实际调用：

```dart
// 将以下代码段（约在"刷新用户信息"按钮处）：
onPressed: () {
  // TODO: Task 12 实现实际抓取调用
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('正在刷新...')),
  );
},

// 替换为：
onPressed: () async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('正在获取用户信息...'),
        ],
      ),
      duration: Duration(seconds: 30),
    ),
  );
  final ok = await provider.fetchUserInfo(site.id);
  messenger.hideCurrentSnackBar();
  if (context.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '用户信息已更新' : '获取失败，请检查 Cookie 是否有效'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }
},
```

- [ ] **Step 3: 更新 SiteProvider 测试**

在 `test/providers/site_provider_test.dart` 中添加 fetchUserInfo 测试（不测试网络请求，仅测试不存在站点的异常处理）：

```dart
group('fetchUserInfo', () {
  test('站点不存在时抛出异常', () async {
    final provider = SiteProvider();
    await provider.loadSites();
    expect(
      () => provider.fetchUserInfo('nonexistent'),
      throwsA(isA<StateError>()),
    );
  });
});
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/providers/site_provider_test.dart
flutter test test/services/site_service_test.dart
```

- [ ] **Step 5: 提交**

```bash
git add lib/providers/site_provider.dart lib/screens/site_detail_screen.dart test/providers/site_provider_test.dart
git commit -m "feat: 连接站点用户信息抓取功能，SiteDetailScreen 可刷新用户信息"
```

---

### Task 13: 导航重构 — 4 Tab 导航 + 注册 SiteProvider

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`
- Rename: `lib/screens/home_screen.dart` → `lib/screens/dashboard_screen.dart`
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 重命名 HomeScreen 为 DashboardScreen**

```bash
mv lib/screens/home_screen.dart lib/screens/dashboard_screen.dart
```

修改 `lib/screens/dashboard_screen.dart`：

```dart
// 将 class HomeScreen 改为 class DashboardScreen
// 将 const HomeScreen 改为 const DashboardScreen
// AppBar title 从 'Bit Manager' 改为 '下载器管理'

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onNavigateToTorrents;

  const DashboardScreen({super.key, this.onNavigateToTorrents});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('下载器管理'), centerTitle: true),
      // ... 其余不变
    );
  }
}
```

- [ ] **Step 2: 注册 SiteProvider（修改 main.dart）**

```dart
// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/client_provider.dart';
import 'providers/torrent_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/site_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BitManagerApp());
}

class BitManagerApp extends StatelessWidget {
  const BitManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => TorrentProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
        ChangeNotifierProvider(create: (_) => SiteProvider()),
      ],
      child: const AppShell(),
    );
  }
}
```

- [ ] **Step 3: 更新 AppShell 为 4 Tab（修改 app.dart）**

修改 `lib/app.dart`：

```dart
// 在 imports 中：
// - 将 import 'screens/home_screen.dart' 替换为 import 'screens/dashboard_screen.dart'
// - 新增 import 'screens/site_list_screen.dart'
// - 新增 import 'providers/site_provider.dart'

import 'screens/dashboard_screen.dart';
import 'screens/site_list_screen.dart';
import 'screens/torrent_list_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/site_provider.dart';

// 在 _init() 中添加 SiteProvider 加载：
Future<void> _init() async {
  final clientProvider = context.read<ClientProvider>();
  final torrentProvider = context.read<TorrentProvider>();
  final statsProvider = context.read<StatsProvider>();
  final siteProvider = context.read<SiteProvider>();
  await clientProvider.loadClients();
  await siteProvider.loadSites();  // 新增

  _refreshService = RefreshService(
    clientProvider: clientProvider,
    torrentProvider: torrentProvider,
    statsProvider: statsProvider,
  );
  _refreshService!.start();
}

// IndexedStack children 改为 4 个：
children: [
  const SiteListScreen(),                          // Tab 0
  DashboardScreen(onNavigateToTorrents: () => setState(() => _currentIndex = 2)),  // Tab 1
  const TorrentListScreen(),                       // Tab 2
  const SettingsScreen(),                          // Tab 3
],

// NavigationBar destinations 改为 4 个：
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

// onNavigateToTorrents 回调中 _currentIndex 改为 2（种子 Tab 现在是 index 2）
DashboardScreen(onNavigateToTorrents: () => setState(() => _currentIndex = 2)),
```

- [ ] **Step 4: 精简 SettingsScreen（移除客户端管理入口）**

修改 `lib/screens/settings_screen.dart`：

```dart
// 移除 Card（客户端管理 ListTile）和 ClientProvider import
// 保留版本信息

import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 关于
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bit Manager'),
              subtitle: Text('版本 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 更新 widget_test.dart**

```dart
// test/widget_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:bit_manager/main.dart';

void main() {
  testWidgets('App should build without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BitManagerApp());
    // 验证 4 个 Tab 存在
    expect(find.text('站点'), findsWidgets);
    expect(find.text('下载器'), findsWidgets);
    expect(find.text('种子'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
```

- [ ] **Step 6: 运行所有测试**

```bash
flutter test
```

- [ ] **Step 7: 提交**

```bash
git add lib/main.dart lib/app.dart lib/screens/dashboard_screen.dart lib/screens/settings_screen.dart test/widget_test.dart
git rm lib/screens/home_screen.dart 2>/dev/null
git commit -m "feat: 重构导航为 4 Tab（站点/下载器/种子/设置），注册 SiteProvider"
```

---

### Task 14: 集成测试与修复

**Files:**
- Modify: 多个文件（按需修复）

- [ ] **Step 1: 运行全量测试**

```bash
flutter test
```

- [ ] **Step 2: 修复所有失败的测试**

逐一检查失败测试，修正代码或测试。

- [ ] **Step 3: 运行 Flutter analyze**

```bash
flutter analyze
```

- [ ] **Step 4: 修复所有 lint 和 analysis 问题**

- [ ] **Step 5: 再次运行全量测试确认全部通过**

```bash
flutter test
flutter analyze
```

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "fix: 修复集成测试和静态分析问题"
```

---

### Task 15: 站点图标自动匹配优化

**Files:**
- Create: `lib/utils/site_icon_resolver.dart`

- [ ] **Step 1: 实现图标路径解析工具**

```dart
// lib/utils/site_icon_resolver.dart

/// 站点图标路径解析
/// 根据站点 id 查找 assets/sites/icons/ 中匹配的图标文件
class SiteIconResolver {
  static const _extensions = ['.ico', '.png', '.jpg', '.gif', '.svg', '.webp'];

  /// 获取站点图标 asset 路径，返回 null 表示无匹配图标
  static String? resolve(String siteId) {
    // 尝试所有扩展名，优先 ico
    for (final ext in _extensions) {
      return 'assets/sites/icons/$siteId$ext';
    }
    return null;
  }
}
```

- [ ] **Step 2: 更新 SiteListScreen 和 SiteDetailScreen 使用 SiteIconResolver**

将 `_getIconAsset` 方法替换为 `SiteIconResolver.resolve(siteId)` 调用。

- [ ] **Step 3: 提交**

```bash
git add lib/utils/site_icon_resolver.dart lib/screens/site_list_screen.dart lib/screens/site_detail_screen.dart
git commit -m "feat: 添加 SiteIconResolver 站点图标路径解析工具"
```
