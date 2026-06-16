# PT 站点多架构解析规则实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `SiteService` 的「单一 NexusPHP 默认规则」重构为「按 manifest 多 schema 加载」，让 NexusPHP 与 Gazelle 站点分别走自己的默认规则集；同时把 `name` / `seeding` / `leeching` 三个核心字段补进 NexusPHP 默认规则。

**Architecture:** 资源层 `assets/sites/schemas/{manifest.json, nexusphp.json, gazelle.json}`；模型层 `SitePreset` 加 `schema` 字段 + `SiteParseSchema.copyWith({schema})`；服务层 `SiteService` 维护 `Map<String, Map<String, FieldRule>> _defaultFieldsBySchema`，按 `parseSchema.schema` 选默认；UI 层站点表单加「架构」下拉框。保留旧版 rowhead 标签词兜底路径。

**Tech Stack:** Flutter 3.12+, Dart, JSON 序列化, flutter_test, flutter assets

**Spec:** `docs/superpowers/specs/2026-06-16-pt-site-multi-schema-parsing-design.md`

---

## File Structure

| 路径 | 角色 | 改动类型 |
|------|------|---------|
| `assets/sites/schemas/manifest.json` | 列出要加载的 schema 文件清单 | 新建 |
| `assets/sites/schemas/nexusphp.json` | NexusPHP 默认规则（原 default_schema.json 迁移 + 补 3 条） | 新建 |
| `assets/sites/schemas/gazelle.json` | Gazelle 默认规则（What.CD 通用模板） | 新建 |
| `assets/sites/default_schema.json` | 旧版 NexusPHP 规则 | 删除 |
| `pubspec.yaml` | 注册新 assets 路径 | 修改 |
| `lib/models/site_config.dart` | `SitePreset` 加 `schema` 字段 + `SiteParseSchema.copyWith` | 修改 |
| `lib/services/site_service.dart` | 多 schema 加载 + 按 schema 选择默认规则 | 修改 |
| `lib/providers/site_provider.dart` | `importPresets` 复制 `schema` 到 `SiteConfig` | 修改 |
| `lib/screens/site_form_screen.dart` | 加「架构」下拉框 | 修改 |
| `assets/sites/presets.json` | 给已知 Gazelle 站点加 `"schema": "Gazelle"` | 修改 |
| `test/services/site_service_test.dart` | 多 schema 加载与选择测试 | 修改 |
| `test/models/site_config_test.dart` | `SitePreset` schema 字段、`SiteParseSchema.copyWith` 测试 | 修改 |

---

### Task 1: 创建 `assets/sites/schemas/` 目录及 3 个 JSON 文件

**Files:**
- Create: `assets/sites/schemas/manifest.json`
- Create: `assets/sites/schemas/nexusphp.json`
- Create: `assets/sites/schemas/gazelle.json`

- [ ] **Step 1: 创建 manifest.json**

写入 `assets/sites/schemas/manifest.json`：

```json
{
  "_comment": "列出要加载的默认规则文件。key 是 SiteParseSchema.schema 的值，path 是相对 assets 路径。",
  "_version": 1,
  "schemas": [
    { "key": "NexusPHP", "path": "assets/sites/schemas/nexusphp.json" },
    { "key": "Gazelle",  "path": "assets/sites/schemas/gazelle.json" }
  ]
}
```

- [ ] **Step 2: 迁移并扩充 nexusphp.json**

将 `assets/sites/default_schema.json` 的全部 12 条规则复制到 `assets/sites/schemas/nexusphp.json`，在 `fields` 对象末尾追加 3 条：

```json
,
"name": {
  "_label": "用户名",
  "selector": [
    "td.rowhead:contains('用户名') + td",
    "td.rowhead:contains('用戶名') + td",
    "td.rowhead:contains('會員名稱') + td",
    "td.rowhead:contains('Username') + td"
  ],
  "filter": "trim"
},
"seeding": {
  "_label": "当前做种",
  "selector": [
    "td.rowhead:contains('当前做种') + td",
    "td.rowhead:contains('當前做種') + td",
    "td.rowhead:contains('Seeding') + td"
  ],
  "filter": "parseNumber"
},
"leeching": {
  "_label": "当前下载",
  "selector": [
    "td.rowhead:contains('当前下载') + td",
    "td.rowhead:contains('當前下載') + td",
    "td.rowhead:contains('Leeching') + td"
  ],
  "filter": "parseNumber"
}
```

> 注意：原 `default_schema.json` 顶部有 `"_comment"` 和 `"_version"` 元字段，保留它们。

- [ ] **Step 3: 创建 gazelle.json**

写入 `assets/sites/schemas/gazelle.json`：

```json
{
  "_comment": "Gazelle 架构默认规则（What.CD 风格：user.php?id=N + li#stats_*）。可作为 Gazelle 类站点的初始模板，差异由用户在规则编辑器调整。",
  "_version": 1,
  "fields": {
    "id": {
      "_label": "用户 ID",
      "selector": ["a[href*='user.php?id=']"],
      "filter": { "name": "querystring", "args": ["id"] }
    },
    "name": {
      "_label": "用户名",
      "selector": ["a[href*='user.php?id=']"]
    },
    "uploaded": {
      "_label": "上传量",
      "selector": ["li#stats_uploaded"],
      "filter": "parseSize"
    },
    "downloaded": {
      "_label": "下载量",
      "selector": ["li#stats_downloaded"],
      "filter": "parseSize"
    },
    "ratio": {
      "_label": "分享率",
      "selector": ["li#stats_ratio"],
      "filter": "parseRatio"
    },
    "levelName": {
      "_label": "等级",
      "selector": ["#userclass"]
    },
    "joinTime": {
      "_label": "加入日期",
      "selector": ["li#stats_join_date"],
      "filter": "trim"
    },
    "leeching": {
      "_label": "当前下载",
      "selector": [
        "td:contains('Currently leeching') + td",
        "#leeching_count",
        "li#stats_leeching"
      ],
      "filter": "parseNumber"
    },
    "seeding": {
      "_label": "当前做种",
      "selector": [
        "td:contains('Currently seeding') + td",
        "#seeding_count",
        "li#stats_seeding"
      ],
      "filter": "parseNumber"
    },
    "messageCount": {
      "_label": "未读消息",
      "selector": [
        "#inbox_new",
        "a[href*='inbox.php'][class*='new']"
      ],
      "filter": "parseNumber"
    }
  }
}
```

- [ ] **Step 4: 验证 JSON 格式正确**

```bash
cd "D:/code/flutter/bit-manager"
node -e "JSON.parse(require('fs').readFileSync('assets/sites/schemas/manifest.json','utf8'))" && echo "manifest ok"
node -e "JSON.parse(require('fs').readFileSync('assets/sites/schemas/nexusphp.json','utf8'))" && echo "nexusphp ok"
node -e "JSON.parse(require('fs').readFileSync('assets/sites/schemas/gazelle.json','utf8'))" && echo "gazelle ok"
```

Expected: 3 行 `xxx ok` 输出，退出码 0。

- [ ] **Step 5: Commit**

```bash
git add assets/sites/schemas/
git commit -m "feat: 添加 schemas 目录及 manifest/nexusphp/gazelle 默认规则 JSON"
```

---

### Task 2: 更新 pubspec.yaml 注册新 assets 路径

**Files:**
- Modify: `pubspec.yaml` (assets 段)

- [ ] **Step 1: 替换 assets 段**

把 `pubspec.yaml` 中：

```yaml
  assets:
    - assets/sites/presets.json
    - assets/sites/default_schema.json
    - assets/sites/icons/
```

改为：

```yaml
  assets:
    - assets/sites/presets.json
    - assets/sites/icons/
    - assets/sites/schemas/
```

> `assets/sites/schemas/` 整目录注册后，`schemas/manifest.json` 和 `schemas/*.json` 都能用 `rootBundle.loadString('assets/sites/schemas/xxx.json')` 加载。`default_schema.json` 路径不再需要。

- [ ] **Step 2: 验证 pub get 通过**

```bash
cd "D:/code/flutter/bit-manager"
flutter pub get
```

Expected: `Resolving dependencies...` 成功，无错误。

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml
git commit -m "chore: pubspec 注册 schemas 目录、移除 default_schema.json 路径"
```

---

### Task 3: 删除旧版 `default_schema.json`

**Files:**
- Delete: `assets/sites/default_schema.json`

- [ ] **Step 1: 删除文件**

```bash
cd "D:/code/flutter/bit-manager"
rm assets/sites/default_schema.json
```

- [ ] **Step 2: 确认旧文件不在工作区**

```bash
ls assets/sites/
```

Expected: 输出包含 `presets.json`、`icons/`、`schemas/`，**不**包含 `default_schema.json`。

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: 删除旧版 default_schema.json（已迁移到 schemas/nexusphp.json）"
```

---

### Task 4: `SitePreset` 加 `schema` 字段（TDD）

**Files:**
- Modify: `lib/models/site_config.dart`
- Modify: `test/models/site_config_test.dart`（如不存在则新建）

- [ ] **Step 1: 写测试**

在 `test/models/site_config_test.dart` 的 `main()` 内 `group('SitePreset', ...)` 中新增（若文件无此 group 则新建 group）：

```dart
test('SitePreset 序列化/反序列化包含 schema 字段', () {
  final preset = SitePreset(
    id: 'gazelle-test',
    name: 'Gazelle Test',
    baseUrl: 'https://example.com',
    schema: 'Gazelle',
  );
  final json = preset.toJson();
  expect(json['schema'], equals('Gazelle'));

  final restored = SitePreset.fromJson(Map<String, dynamic>.from(json));
  expect(restored.schema, equals('Gazelle'));
});

test('SitePreset schema 为 null 时不写入 json', () {
  final preset = SitePreset(
    id: 'default',
    name: 'Default',
  );
  final json = preset.toJson();
  expect(json.containsKey('schema'), isFalse);
});

test('SitePreset.fromJson 缺失 schema 时返回 null', () {
  final restored = SitePreset.fromJson(<String, dynamic>{
    'id': 'x',
    'name': 'X',
  });
  expect(restored.schema, isNull);
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/models/site_config_test.dart
```

Expected: 编译错误（`schema` 字段不存在）或断言失败。**`schema` 相关 3 个测试都应失败。**

- [ ] **Step 3: 在 `SitePreset` 加 `schema` 字段**

修改 `lib/models/site_config.dart`：

在 `class SitePreset { ... }` 中添加字段：

```dart
  /// 站点架构：'NexusPHP' | 'Gazelle' | null
  /// null 表示未声明，解析时回落到 NexusPHP
  final String? schema;
```

在 `const SitePreset({ ... })` 构造器参数列表末尾加：

```dart
    this.schema,
```

在 `factory SitePreset.fromJson(...)` 的返回前加：

```dart
        schema: json['schema'] as String?,
```

在 `toJson()` 末尾的 `};` 前加：

```dart
        if (schema != null) 'schema': schema,
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/models/site_config_test.dart
```

Expected: 全部测试通过。

- [ ] **Step 5: Commit**

```bash
git add lib/models/site_config.dart test/models/site_config_test.dart
git commit -m "feat: SitePreset 加可选 schema 字段"
```

---

### Task 5: `SiteParseSchema.copyWith` 加 `schema` 参数（TDD）

**Files:**
- Modify: `lib/models/site_config.dart`
- Modify: `test/models/site_config_test.dart`

- [ ] **Step 1: 写测试**

在 `test/models/site_config_test.dart` 的 `group('SiteParseSchema', ...)` 中新增（若无则新建）：

```dart
test('SiteParseSchema.copyWith({schema}) 保留其它字段', () {
  final orig = SiteParseSchema(
    schema: 'NexusPHP',
    userDetailsPath: '/userdetails.php',
    fields: {
      'uploaded': const FieldRule(selector: ['td.x + td']),
    },
    bonusLabels: ['啤酒瓶'],
    seedingLabels: ['当前做种'],
  );
  final copied = orig.copyWith(schema: 'Gazelle');
  expect(copied.schema, equals('Gazelle'));
  expect(copied.userDetailsPath, equals('/userdetails.php'));
  expect(copied.fields, isNotNull);
  expect(copied.fields!['uploaded']!.selector, equals(['td.x + td']));
  expect(copied.bonusLabels, equals(['啤酒瓶']));
  expect(copied.seedingLabels, equals(['当前做种']));
});

test('SiteParseSchema.copyWith() 不传参数时返回等价副本', () {
  final orig = SiteParseSchema(
    schema: 'NexusPHP',
    userDetailsPath: '/x',
  );
  final copied = orig.copyWith();
  expect(copied.schema, equals('NexusPHP'));
  expect(copied.userDetailsPath, equals('/x'));
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/models/site_config_test.dart
```

Expected: 编译错误（`copyWith` 方法不存在）。

- [ ] **Step 3: 在 `SiteParseSchema` 加 `copyWith`**

修改 `lib/models/site_config.dart`，在 `class SiteParseSchema` 内部（构造器之后、`fromJson` 之前）加：

```dart
  SiteParseSchema copyWith({
    String? schema,
    String? userDetailsPath,
    Map<String, FieldRule>? fields,
    List<String>? usernameLabels,
    List<String>? levelLabels,
    List<String>? transferLabels,
    List<String>? bonusLabels,
    List<String>? joinTimeLabels,
    List<String>? seedingLabels,
    List<String>? leechingLabels,
  }) {
    return SiteParseSchema(
      schema: schema ?? this.schema,
      userDetailsPath: userDetailsPath ?? this.userDetailsPath,
      fields: fields ?? this.fields,
      usernameLabels: usernameLabels ?? this.usernameLabels,
      levelLabels: levelLabels ?? this.levelLabels,
      transferLabels: transferLabels ?? this.transferLabels,
      bonusLabels: bonusLabels ?? this.bonusLabels,
      joinTimeLabels: joinTimeLabels ?? this.joinTimeLabels,
      seedingLabels: seedingLabels ?? this.seedingLabels,
      leechingLabels: leechingLabels ?? this.leechingLabels,
    );
  }
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/models/site_config_test.dart
```

Expected: 全部测试通过。

- [ ] **Step 5: Commit**

```bash
git add lib/models/site_config.dart test/models/site_config_test.dart
git commit -m "feat: SiteParseSchema 加 copyWith 方法（包含 schema 字段）"
```

---

### Task 6: `SiteService` 重构为多 schema 加载（TDD）

**Files:**
- Modify: `lib/services/site_service.dart`
- Modify: `test/services/site_service_test.dart`

- [ ] **Step 1: 写测试 — 多 schema 加载到内存**

在 `test/services/site_service_test.dart` 顶部加 import：

```dart
import 'package:flutter/services.dart' show rootBundle;
```

在 `setUpAll` 中先加载默认 schema；然后新增 `group('多 schema 加载', ...)`：

```dart
group('多 schema 加载', () {
  test('ensureDefaultSchemaLoaded 后 NexusPHP 与 Gazelle 都在内存', () async {
    // 重置以便能再加载
    SiteService.resetDefaultFieldsForTest();
    await SiteService.ensureDefaultSchemaLoaded();
    final nexus = SiteService.defaultFieldsForTest('NexusPHP');
    final gazelle = SiteService.defaultFieldsForTest('Gazelle');
    expect(nexus, isNotNull);
    expect(gazelle, isNotNull);
    expect(nexus!.containsKey('uploaded'), isTrue);
    expect(gazelle!.containsKey('uploaded'), isTrue);
  });

  test('NexusPHP 默认规则包含 name / seeding / leeching', () async {
    SiteService.resetDefaultFieldsForTest();
    await SiteService.ensureDefaultSchemaLoaded();
    final nexus = SiteService.defaultFieldsForTest('NexusPHP')!;
    expect(nexus.containsKey('name'), isTrue);
    expect(nexus.containsKey('seeding'), isTrue);
    expect(nexus.containsKey('leeching'), isTrue);
    expect(nexus['seeding']!.filter, equals('parseNumber'));
    expect(nexus['leeching']!.filter, equals('parseNumber'));
  });

  test('schema 为 null 时回落到 NexusPHP', () async {
    SiteService.resetDefaultFieldsForTest();
    await SiteService.ensureDefaultSchemaLoaded();
    // parseHtml 使用 schema=null
    final svc = SiteService();
    final html = '<html><body>'
        "<tr><td class='rowhead'>传输</td><td>上传量: 1.00 TB 下载量: 2.00 TB 分享率: 0.50</td></tr>"
        '</body></html>';
    final info = svc.parseHtml('test', html, schema: null);
    expect(info.uploaded, isNotNull);
  });

  test('schema 为 Gazelle 时使用 Gazelle 默认规则', () async {
    SiteService.resetDefaultFieldsForTest();
    await SiteService.ensureDefaultSchemaLoaded();
    final svc = SiteService();
    // Gazelle 风格 HTML：li#stats_uploaded 内有纯文本"2.5 TiB"
    final html = '<html><body>'
        '<li id="stats_uploaded">2.5 TiB</li>'
        '<li id="stats_downloaded">1.0 TiB</li>'
        '<li id="stats_ratio">2.5</li>'
        '</body></html>';
    final info = svc.parseHtml('test', html,
        schema: const SiteParseSchema(schema: 'Gazelle'));
    expect(info.uploaded, equals(2748779069440)); // 2.5 TiB
    expect(info.downloaded, equals(1099511627776)); // 1.0 TiB
    expect(info.ratio, closeTo(2.5, 0.01));
  });

  test('站点自定义 fields 优先于默认规则', () async {
    SiteService.resetDefaultFieldsForTest();
    await SiteService.ensureDefaultSchemaLoaded();
    final svc = SiteService();
    // NexusPHP 默认会从 td.rowhead:contains('传输') + td 拿上传量
    // 站点自定义 fields 用 td.custom 覆盖之
    final html = '<html><body>'
        "<tr><td class='rowhead'>传输</td><td>上传量: 999 TB 下载量: 1.00 TB</td></tr>"
        "<tr><td class='custom'>42 GB</td></tr>"
        '</body></html>';
    final customRule = const FieldRule(
      selector: ["td.custom"],
      filter: 'parseSize',
    );
    final schema = SiteParseSchema(
      schema: 'NexusPHP',
      fields: {'uploaded': customRule},
    );
    final info = svc.parseHtml('test', html, schema: schema);
    // 自定义规则拿到的 42 GB（45097156608）优先于默认拿到的 999 TB
    expect(info.uploaded, equals(45097156608));
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/services/site_service_test.dart
```

Expected: 编译错误（`defaultFieldsForTest` 不存在），或运行时断言失败。

- [ ] **Step 3: 重构 `SiteService` 状态**

修改 `lib/services/site_service.dart`：

把：

```dart
  static Map<String, FieldRule> _defaultNexusPhpFields = _builtinFallback;

  /// 是否已加载过 default_schema.json（首次 fetch 时触发）
  static bool _defaultLoaded = false;
```

改为：

```dart
  /// key = SiteParseSchema.schema 的值；缺失 schema 时使用 'NexusPHP'
  static Map<String, Map<String, FieldRule>> _defaultFieldsBySchema = {
    'NexusPHP': _builtinFallback,
  };

  /// 是否已加载过 schemas/manifest.json（首次 fetch 时触发）
  static bool _manifestLoaded = false;
```

- [ ] **Step 4: 重构 `ensureDefaultSchemaLoaded`**

把 `ensureDefaultSchemaLoaded()` 整段方法体替换为：

```dart
  static Future<void> ensureDefaultSchemaLoaded() async {
    if (_manifestLoaded) return;
    _manifestLoaded = true;
    try {
      final raw = await rootBundle.loadString(
          'assets/sites/schemas/manifest.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['schemas'] as List?;
      if (list == null) return;
      for (final entry in list) {
        if (entry is! Map) continue;
        final key = entry['key'] as String?;
        final path = entry['path'] as String?;
        if (key == null || path == null) continue;
        try {
          final rawSchema = await rootBundle.loadString(path);
          final schemaJson = jsonDecode(rawSchema) as Map<String, dynamic>;
          final fieldsJson = schemaJson['fields'] as Map<String, dynamic>?;
          if (fieldsJson == null) continue;
          final fields = <String, FieldRule>{};
          fieldsJson.forEach((k, v) {
            if (v is! Map) return;
            if (k.startsWith('_')) return;
            try {
              fields[k.toString()] =
                  FieldRule.fromJson(Map<String, dynamic>.from(v));
            } catch (_) {
              // 单个字段失败不影响其它字段
            }
          });
          if (fields.isNotEmpty) {
            _defaultFieldsBySchema[key] = fields;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[SiteService] $path 加载失败: $e');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SiteService] manifest.json 加载失败: $e — 使用内置 NexusPHP 兜底');
      }
    }
  }
```

- [ ] **Step 5: 重构 `_mergeDetailHtml` 阶段 2**

把 `_mergeDetailHtml` 中的：

```dart
    // ── 阶段 2：跑默认 NexusPHP schema（PT-depiler schemas/NexusPHP.ts 等价）──
    _applyFieldRules(info, doc, _defaultNexusPhpFields);
```

改为：

```dart
    // ── 阶段 2：按 schema 选默认规则（null 回落 NexusPHP）──
    final schemaKey = schema?.schema ?? 'NexusPHP';
    final defaults = _defaultFieldsBySchema[schemaKey]
        ?? _defaultFieldsBySchema['NexusPHP']!;
    _applyFieldRules(info, doc, defaults);
```

- [ ] **Step 6: 重构测试钩子**

把 `setDefaultFieldsForTest`：

```dart
  @visibleForTesting
  static void setDefaultFieldsForTest(Map<String, FieldRule> fields) {
    _defaultNexusPhpFields = fields;
    _defaultLoaded = true;
  }
```

改为：

```dart
  @visibleForTesting
  static void setDefaultFieldsForTest(
      Map<String, Map<String, FieldRule>> fields) {
    _defaultFieldsBySchema = fields;
    _manifestLoaded = true;
  }
```

把 `resetDefaultFieldsForTest`：

```dart
  @visibleForTesting
  static void resetDefaultFieldsForTest() {
    _defaultNexusPhpFields = _builtinFallback;
    _defaultLoaded = false;
  }
```

改为：

```dart
  @visibleForTesting
  static void resetDefaultFieldsForTest() {
    _defaultFieldsBySchema = {
      'NexusPHP': _builtinFallback,
    };
    _manifestLoaded = false;
  }
```

新增 `defaultFieldsForTest` 供测试使用（紧跟 `resetDefaultFieldsForTest` 后）：

```dart
  @visibleForTesting
  static Map<String, FieldRule>? defaultFieldsForTest(String schema) =>
      _defaultFieldsBySchema[schema];
```

- [ ] **Step 7: 跑测试确认通过**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/services/site_service_test.dart
```

Expected: 全部测试通过。

- [ ] **Step 8: 跑全量测试**

```bash
cd "D:/code/flutter/bit-manager"
flutter test
```

Expected: 全部测试通过（site_service_test 之外的测试不应受影响）。

- [ ] **Step 9: Commit**

```bash
git add lib/services/site_service.dart test/services/site_service_test.dart
git commit -m "refactor: SiteService 改为按 manifest 多 schema 加载"
```

---

### Task 7: 给已知 Gazelle 站点加 `"schema": "Gazelle"`

**Files:**
- Modify: `assets/sites/presets.json`

- [ ] **Step 1: 找到需要标记的预设**

```bash
cd "D:/code/flutter/bit-manager"
grep -n "Gazelle" assets/sites/presets.json | head -20
```

Expected: 输出 description 字段含「Gazelle」字样的预设条目，记录它们的 `id`（至少包括 `dicmusic`、`gazellegames` 等）。

- [ ] **Step 2: 在每个匹配预设的 JSON 对象中加 `"schema": "Gazelle"`**

例如对 dicmusic 预设，定位其对象闭合的 `}` 前一行，加：

```json
        "schema": "Gazelle",
```

> 关键：必须缩进对齐该对象内的其它字段（通常是 8 空格）。修改后用 jq 验证 JSON 仍合法。

- [ ] **Step 3: 验证 JSON 格式**

```bash
cd "D:/code/flutter/bit-manager"
node -e "JSON.parse(require('fs').readFileSync('assets/sites/presets.json','utf8'))" && echo "presets ok"
```

Expected: `presets ok` 输出。

- [ ] **Step 4: 验证修改后的预设带 schema 字段**

```bash
cd "D:/code/flutter/bit-manager"
node -e "
const p = JSON.parse(require('fs').readFileSync('assets/sites/presets.json','utf8'));
const gazelle = p.filter(x => x.schema === 'Gazelle');
console.log('Gazelle 预设数:', gazelle.length);
gazelle.forEach(x => console.log(' -', x.id, x.name));
"
```

Expected: 至少打印 1-2 行（dicmusic / gazellegames 等）。

- [ ] **Step 5: Commit**

```bash
git add assets/sites/presets.json
git commit -m "data: 给已知 Gazelle 站点 preset 加 schema 字段"
```

---

### Task 8: `SiteProvider.importPresets` 复制 `schema` 字段

**Files:**
- Modify: `lib/providers/site_provider.dart`

- [ ] **Step 1: 写测试**

在 `test/providers/site_provider_test.dart`（如不存在则新建）：

```dart
import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('importPresets 把 preset.schema 复制到 site.parseSchema.schema', () async {
    final provider = SiteProvider();
    final presets = [
      const SitePreset(
        id: 'gazelle-x',
        name: 'Gazelle X',
        schema: 'Gazelle',
      ),
    ];
    await provider.importPresets(presets);
    final imported = provider.sites.firstWhere((s) => s.id == 'gazelle-x');
    expect(imported.parseSchema, isNotNull);
    expect(imported.parseSchema!.schema, equals('Gazelle'));
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/providers/site_provider_test.dart
```

Expected: 断言失败（`imported.parseSchema!.schema` 为 null）。

- [ ] **Step 3: 修复 `importPresets`**

修改 `lib/providers/site_provider.dart` 中 `importPresets`：

把：

```dart
      final config = SiteConfig(
        id: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        tags: List.from(preset.tags),
        sortOrder: _sites.isEmpty ? 1 : _sites.last.sortOrder + 1,
        parseSchema: preset.parseSchema,
      );
```

改为：

```dart
      SiteParseSchema? schema = preset.parseSchema;
      if (preset.schema != null) {
        schema = (schema ?? const SiteParseSchema()).copyWith(schema: preset.schema);
      }
      final config = SiteConfig(
        id: preset.id,
        name: preset.name,
        baseUrl: preset.baseUrl,
        tags: List.from(preset.tags),
        sortOrder: _sites.isEmpty ? 1 : _sites.last.sortOrder + 1,
        parseSchema: schema,
      );
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd "D:/code/flutter/bit-manager"
flutter test test/providers/site_provider_test.dart
```

Expected: 通过。

- [ ] **Step 5: Commit**

```bash
git add lib/providers/site_provider.dart test/providers/site_provider_test.dart
git commit -m "feat: importPresets 复制 preset.schema 到 SiteConfig"
```

---

### Task 9: 站点表单加「架构」下拉框

**Files:**
- Modify: `lib/screens/site_form_screen.dart`

- [ ] **Step 1: 读现有 form screen 找到「解析配置」卡片**

在 `lib/screens/site_form_screen.dart` 中定位包含 `parseSchema` 关键字的 Card 组件（约 110-230 行）。

- [ ] **Step 2: 在「详情页路径」字段下方加「架构」下拉框**

在 `userDetailsPath` 字段之后、`bonusLabels` 等字段之前，插入一个 `DropdownButtonFormField<String?>`：

```dart
            DropdownButtonFormField<String?>(
              initialValue: schema?.schema,
              decoration: const InputDecoration(
                labelText: '站点架构',
                helperText: '默认 NexusPHP。Gazelle 站点选 Gazelle。',
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('自动（NexusPHP）')),
                DropdownMenuItem<String?>(value: 'NexusPHP', child: Text('NexusPHP')),
                DropdownMenuItem<String?>(value: 'Gazelle', child: Text('Gazelle')),
              ],
              onChanged: (v) {
                setState(() {
                  _parseSchema = (_parseSchema ?? const SiteParseSchema())
                      .copyWith(schema: v);
                });
              },
            ),
```

> `_parseSchema` 是当前 form 内部维护的 `SiteParseSchema?` 工作副本。如果原代码用的是别的局部变量名，请按实际名称调整。

- [ ] **Step 3: 跑 analyze**

```bash
cd "D:/code/flutter/bit-manager"
flutter analyze lib/screens/site_form_screen.dart
```

Expected: 无错误（warning 允许存在）。

- [ ] **Step 4: Commit**

```bash
git add lib/screens/site_form_screen.dart
git commit -m "feat: 站点表单加站点架构下拉框"
```

---

### Task 10: 端到端验证

**Files:** 无

- [ ] **Step 1: 跑 flutter analyze 全量**

```bash
cd "D:/code/flutter/bit-manager"
flutter analyze
```

Expected: 无 error；warning 数与改动前相比不显著增加。

- [ ] **Step 2: 跑全量测试**

```bash
cd "D:/code/flutter/bit-manager"
flutter test
```

Expected: 全部测试通过。

- [ ] **Step 3: 跑 dart format 验证代码风格**

```bash
cd "D:/code/flutter/bit-manager"
dart format --set-exit-if-changed lib/ test/
```

Expected: 退出码 0（无格式问题）。如有差异，运行 `dart format lib/ test/` 自动修复。

- [ ] **Step 4: 提交所有未暂存修改（如有）**

```bash
cd "D:/code/flutter/bit-manager"
git status
git add -A
git diff --cached --quiet || git commit -m "style: dart format"
```

Expected: `git status` 输出 clean。

---

## 风险与回滚

| 风险 | 应对 |
|------|------|
| Gazelle 默认规则不准确 | 用户在规则编辑器微调，不影响功能 |
| manifest.json 加载失败 | NexusPHP 走内置 `_builtinFallback`，其它 schema 不进 map |
| 旧版 `setDefaultFieldsForTest` 调用方未更新 | Task 6 同步更新签名；如有遗漏需补 |

回滚步骤：还原 `git log` 中 Task 1-9 任一提交即可单点回退；最坏情况 `git revert HEAD~9..HEAD` 一次性还原本次所有改动。
