# PT 站点解析规则 — 多架构支持与默认规则补齐

## 概述

把当前的「单一 NexusPHP 默认规则」重构为「按架构分文件加载」，让 NexusPHP 与 Gazelle 站点能分别走自己的默认规则集。同时把上一版 `default_schema.json` 缺失的 3 个核心字段（`name` / `seeding` / `leeching`）补齐。所有 7 个核心用户信息字段（上传、下载、做种数、下载数、用户名、用户等级、用户未读消息）都通过可配置规则系统暴露。

## 目标与范围

### 目标

1. 支持多个站点架构的默认规则并存（NexusPHP、Gazelle、…）
2. 7 个核心用户信息字段全部可在规则编辑器中配置
3. 每个站点有独立的规则适配能力（已支持，保持）
4. 现有用户数据零迁移

### 不在范围

- HTML 指纹自动检测架构
- 移除旧版 `usernameLabels` / `seedingLabels` / `leechingLabels` 兜底路径
- 新增 UNIT3D、Byr 等其他架构的默认规则（骨架就位即可，后续按需添加）
- 改变 `SiteUserInfo` 模型

## 数据流

```
SiteConfig
  └─ parseSchema
       ├─ schema: "NexusPHP" | "Gazelle" | null   ← 架构标识
       ├─ userDetailsPath
       └─ fields: { 上传/下载/... }              ← 站点自定义规则（最高优先）

SiteService.fetchUserInfo
  ├─ 阶段 1: schema.fields                         (站点自定义)
  ├─ 阶段 2: 按 schema 选默认规则
  │    ├─ "NexusPHP" → schemas/nexusphp.json
  │    ├─ "Gazelle"  → schemas/gazelle.json
  │    └─ null/其它  → NexusPHP
  └─ 阶段 3: rowhead 标签词兜底                    (旧版兼容)
```

## 文件改动

### 新增

- `assets/sites/schemas/manifest.json` — 列出要加载的默认规则文件
- `assets/sites/schemas/nexusphp.json` — 原 `default_schema.json` 内容迁移 + 补 3 条规则
- `assets/sites/schemas/gazelle.json` — Gazelle 默认规则（What.CD 通用版）
- `docs/superpowers/specs/2026-06-16-pt-site-multi-schema-parsing-design.md`（本文档）

### 删除

- `assets/sites/default_schema.json`（被 `schemas/nexusphp.json` 替代）

### 修改

- `assets/sites/presets.json` — 给已知的 Gazelle 站点（DICMusic 等）加 `"schema": "Gazelle"`
- `lib/models/site_config.dart` — `SitePreset` 新增可选 `schema` 字段
- `lib/services/site_service.dart` — 多 schema 加载与按 schema 选择默认规则
- `lib/providers/site_provider.dart` — 从 preset 复制 `schema` 到新站点配置
- `lib/screens/site_form_screen.dart` — 站点表单新增「架构」下拉框
- `test/services/site_service_test.dart` — 新增多架构加载与选择用例

## 数据模型

### `SitePreset`（扩展）

```dart
class SitePreset {
  // ... 现有字段

  /// 站点架构：'NexusPHP' | 'Gazelle' | null
  /// null 表示未声明，解析时回落到 NexusPHP
  final String? schema;
}
```

JSON 读写同步加 `schema` 字段。

### `SiteParseSchema`（保持）

`schema` 字段已存在，无需改动。`fields` 仍为最高优先级的站点自定义规则。

## 资源文件

### `assets/sites/schemas/manifest.json`

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

### `assets/sites/schemas/nexusphp.json`

包含原 `default_schema.json` 的全部字段（12 个），并新增以下 3 条：

```json
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

### `assets/sites/schemas/gazelle.json`

What.CD 通用版 Gazelle 规则。selector 真实可用性需在真实站点上验证；不准确时由用户在规则编辑器微调。

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

### `assets/sites/presets.json`

为已知 Gazelle 站点加 `"schema": "Gazelle"`：

```json
{
  "id": "dicmusic",
  "name": "DICMusic",
  ...
  "schema": "Gazelle"
}
```

具体清单：搜索 `description` 中含「Gazelle」字样的预设（至少 `dicmusic`），逐个加 `schema: "Gazelle"`。

## Dart 改动

### `lib/models/site_config.dart`

- `SitePreset` 加 `final String? schema;`
- 构造器加可选参数 `this.schema`
- `fromJson` 读 `json['schema'] as String?`
- `toJson` 写 `if (schema != null) 'schema': schema`

### `lib/services/site_service.dart`

#### 状态变化

```dart
// 旧：
static Map<String, FieldRule> _defaultNexusPhpFields = _builtinFallback;
static bool _defaultLoaded = false;

// 新：
static Map<String, Map<String, FieldRule>> _defaultFieldsBySchema = {
  'NexusPHP': _builtinFallback,
};
static bool _manifestLoaded = false;
```

#### 加载流程

- `ensureDefaultSchemaLoaded()` 改为：
  1. 读 `manifest.json`
  2. 并发 `loadString` 每个 schema 文件
  3. 解析为 `Map<String, FieldRule>`，按 key 写入 `_defaultFieldsBySchema`
  4. 任一文件失败 → 保持 `NexusPHP` 的内置 fallback，其它 schema 缺失则不进入 map
- 加 `ensureSchemaLoaded(String schema)` 供首次抓取某站时按需补加载（可选优化）

#### 解析流程

`_mergeDetailHtml()` 中阶段 2 改为：

```dart
final schemaKey = (schema?.schema ?? 'NexusPHP');
final defaults = _defaultFieldsBySchema[schemaKey]
    ?? _defaultFieldsBySchema['NexusPHP']!;
_applyFieldRules(info, doc, defaults);
```

#### 测试钩子

- `setDefaultFieldsForTest(Map<String, Map<String, FieldRule>> fields)` 替换 `setDefaultFieldsForTest(Map<String, FieldRule>)`
- `resetDefaultFieldsForTest()` 重置为单 NexusPHP 内置 fallback
- 新增 `defaultFieldsForTest(String schema)` 供断言使用

### `lib/providers/site_provider.dart`

创建/导入 preset 站点时：

```dart
final config = SiteConfig(
  id: preset.id,
  name: preset.name,
  // ...
  parseSchema: preset.parseSchema != null
      ? preset.parseSchema!.copyWith(schema: preset.schema)
      : (preset.schema != null
          ? SiteParseSchema(schema: preset.schema)
          : null),
);
```

新增 `SiteParseSchema.copyWith({String? schema, ...})` 方法 — 必须复制**全部**已有字段（`userDetailsPath` / `fields` / 各类 `*Labels`），不能只传 `schema` 一个。

### `lib/screens/site_form_screen.dart`

站点表单的「解析配置」卡片中加：

```
架构（schema）
  [ 自动 ▼ ]
  ├── 自动（默认 NexusPHP）
  ├── NexusPHP
  └── Gazelle
```

存到 `site.parseSchema?.schema`。无 schema 时保持 null（自动）。

## 兼容性

| 场景 | 行为 |
|------|------|
| 现有 34 个 preset 的 `parseSchema` | 不动；`fields` 仍优先于默认规则 |
| 用户已保存的站点配置 | `schema` 字段为 null → 回落 NexusPHP |
| 旧版 `usernameLabels` / `seedingLabels` / `leechingLabels` | 保留，作为阶段 3 兜底 |
| 规则编辑器 `_fieldLabels` | 已有 `name` / `seeding` / `leeching`，无需改 |
| `SiteUserInfo` 模型 | 不动 |
| `pubspec.yaml` | 不动（manifest 路径仍在 `assets/sites/` 目录下，已在 `flutter` 段的 `assets:` 列表覆盖） |

## 测试

`test/services/site_service_test.dart` 新增：

1. `manifest 加载后 NexusPHP 与 Gazelle 都在内存里`
2. `NexusPHP 默认规则包含 name / seeding / leeching`（验证本次新增 3 条）
3. `schema 为 null 的站点解析走 NexusPHP 默认`
4. `schema 为 Gazelle 的站点解析走 Gazelle 默认`（构造一个 Gazelle 风格 HTML 验证 uploaded/downloaded/ratio）
5. `站点自定义 fields 优先于默认`

每个测试用现有 `_builtinFallback` + `setDefaultFieldsForTest` 模式注入用例数据。

## 实施步骤（高层）

1. 创建 `schemas/` 目录及 3 个 JSON 文件
2. 删除根目录 `default_schema.json`
3. `SitePreset` 加 `schema` 字段（模型 + JSON `fromJson`/`toJson`）
4. `SiteService` 改造为多 schema 加载 + 按 schema 选择
5. `SiteParseSchema.copyWith` 加 `schema` 参数
6. `SiteProvider` 在创建 preset 站点时复制 `schema`
7. `site_form_screen.dart` 加架构下拉框
8. `presets.json` 给 Gazelle 站点加 `"schema": "Gazelle"`
9. 写测试用例
10. 跑 `flutter test` 验证
11. 跑 `flutter analyze` 验证

## 风险与回滚

- 风险：Gazelle 默认规则不准确 → 用户在规则编辑器微调
- 风险：manifest 加载失败 → NexusPHP 走内置 fallback，其它 schema 缺失
- 回滚：还原 `_defaultNexusPhpFields` 单变量、删除 `schemas/` 目录、把 `default_schema.json` 复原
