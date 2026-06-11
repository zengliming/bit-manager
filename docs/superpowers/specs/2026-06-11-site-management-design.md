# 站点管理功能设计

## 概述

为 bit-manager 新增完整的 PT 站点管理模块，支持站点的增删改查、分组标签、内置站点预设导入、站点图标管理、以及 Cookie 登录凭证管理（手动录入 + WebView 登录）。

参考项目：PT-depiler（https://github.com/pt-plugins/PT-depiler），取其站点元数据、图标资源和 WebView Cookie 抓取思路。

## 功能范围

1. **站点 CRUD** — 增删改查站点信息：名称、URL、图标、标签、备注
2. **站点分组 & 标签** — 自定义分组标签，按标签过滤
3. **内置站点预设** — 从 PT-depiler 转化 287 个站点预设为 JSON，打包到 assets，支持一键导入
4. **站点图标管理** — 将 PT-depiler 的 219 个站点图标打包到 assets，按站点 ID 映射
5. **Cookie / 登录凭证管理** — 手动录入 cookie 字符串 + WebView 自动登录抓取，SecureStorage 加密存储
6. **用户信息抓取** — 通过 cookie 访问站点页面，解析 HTML 提取用户信息（用户名、上传量、下载量、分享率、等级、魔力值等）

## 数据模型

### SiteConfig — 站点配置

```dart
class SiteConfig {
  final String id;         // 唯一标识，如 "m-team", "hdtime"
  String name;             // 显示名称
  String? baseUrl;         // 站点主页 URL
  List<String> tags;       // 标签 / 分组，如 ["电影", "官组"]
  String? notes;           // 用户备注
  bool isActive;           // 是否启用
  int sortOrder;           // 排序序号
  DateTime addedAt;        // 添加时间
}
```

### SitePreset — 站点预设（只读）

```dart
class SitePreset {
  final String id;           // 唯一标识
  final String name;         // 站点名称
  final String? baseUrl;     // 主页 URL
  final List<String> tags;   // 预置标签
  final String? iconAsset;   // 图标资源路径
  final String? category;    // 分类（影视/音乐/综合/教育/...）
}
```

### SiteUserInfo — 用户信息（通过 Cookie 抓取）

```dart
class SiteUserInfo {
  String? username;
  int? uploaded;             // 上传量 (bytes)
  int? downloaded;           // 下载量 (bytes)
  double? ratio;             // 分享率
  String? level;             // 用户等级名称
  int? bonusPoints;          // 魔力值 / 积分
  int? seedingCount;         // 当前做种数
  int? leechingCount;        // 当前下载数
  DateTime? lastFetchedAt;   // 最后抓取时间
  bool fetchFailed;          // 上次抓取是否失败
}
```

### SiteCookie — Cookie 存储

```dart
class SiteCookie {
  final String siteId;
  String? cookieString;
  DateTime? lastUpdatedAt;
  bool isLoginValid;
}
```

### 实体关系

```
SiteConfig (1) ──── (1) SiteCookie        → 存 SecureStorage
     │
     └── (0..1) SiteUserInfo              → 有有效 cookie 时才抓取
```

### 存储方式

| 数据 | 存储方式 | 键名 |
|------|---------|------|
| SiteConfig 列表 | SharedPreferences JSON 数组 | `sites` |
| SiteCookie | FlutterSecureStorage | `cookie_{siteId}` |
| SiteUserInfo | SharedPreferences JSON | `site_user_info` |
| 预设 JSON | 打包到 assets | `assets/sites/presets.json` |
| 站点图标 | 打包到 assets | `assets/sites/icons/` |

## 架构

### 新增文件

```
lib/
├── models/
│   └── site_config.dart               # SiteConfig + SitePreset + SiteCookie + SiteUserInfo
│
├── providers/
│   └── site_provider.dart             # SiteProvider
│
├── services/
│   └── site_service.dart              # 用户信息抓取（HTTP + Cookie 解析 HTML）
│
├── screens/
│   ├── site_list_screen.dart          # 站点列表页（Tab 1）
│   ├── site_form_screen.dart          # 站点添加/编辑表单
│   ├── site_import_screen.dart        # 预设站点导入页
│   ├── site_detail_screen.dart        # 站点详情（用户信息 + Cookie 管理入口）
│   └── site_cookie_screen.dart        # Cookie 编辑页（手动录入 + WebView 登录）
│
├── widgets/
│   ├── site_tile.dart                 # 站点列表项组件
│   └── site_favicon.dart              # 站点图标组件
│
assets/sites/
├── presets.json                       # 287 个站点预设
└── icons/                             # 219 个站点图标
```

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `lib/main.dart` | 注册 `SiteProvider` |
| `lib/app.dart` | 底部导航 4 Tab：站点 → 下载器管理 → 种子 → 设置；`HomeScreen` → `DashboardScreen` |
| `lib/screens/home_screen.dart` | 重命名为 `dashboard_screen.dart`，标题"下载器管理" |
| `lib/screens/settings_screen.dart` | 移除客户端管理入口 |
| `pubspec.yaml` | 新增 `webview_flutter` 依赖，注册 assets |

### Provider 依赖

```
SiteProvider ─── 独立，不依赖其他 Provider
ClientProvider ─ 独立
TorrentProvider ─ 依赖 ClientProvider
StatsProvider ─── 依赖 ClientProvider + TorrentProvider
```

### 导航结构

```
NavigationBar (4 tabs)
├── 站点             → SiteListScreen
│   ├── push → SiteFormScreen (添加/编辑)
│   ├── push → SiteImportScreen (导入预设)
│   ├── push → SiteDetailScreen (站点详情)
│   │   └── push → SiteCookieScreen (Cookie 管理)
│
├── 下载器管理        → DashboardScreen (原 HomeScreen)
│   └── push → ClientFormScreen / ClientListScreen
│
├── 种子             → TorrentListScreen
│
└── 设置             → SettingsScreen
```

## 交互流程

### 站点列表页

- 右上角：导入预设按钮 + 搜索按钮
- 搜索栏（可选折叠）：按名称/标签筛选
- 列表按 `sortOrder` 排序
- 每行展示：图标、名称、标签 Chips、分享率、启用开关、cookie 状态
- 如有用户信息，额外显示等级和 cookie 有效性
- FAB："添加站点"

### 预设导入流程

- 搜索栏 + 分类筛选 Chips（影视/音乐/综合/教育/...）
- 列表展示 287 个预设，支持多选
- 每行：图标 + 名称 + 分类 + 已导入标记
- 底部按钮："导入选中 (N)" → 批量写入 SiteConfig

### 站点详情页

- 基本信息：图标、名称、URL、标签、备注
- 用户信息卡片：用户名、等级、分享率、上传/下载量、魔力值、做种/下载数、最后抓取时间
- [刷新用户信息] 按钮
- [管理 Cookie] 按钮 → 进入 Cookie 编辑页

### Cookie 管理页

- 当前状态：最后更新时间、登录状态
- 方式一：手动录入 — 多行文本框粘贴 cookie 字符串 → 保存
- 方式二：WebView 登录 — 打开站点主页，用户手动登录，自动抓取 cookie
- 保存后自动触发用户信息抓取，验证 cookie 有效性

### 用户信息抓取

- 触发时机：cookie 保存后 / 手动刷新
- 流程：读取 cookie → HTTP GET baseUrl → 解析 HTML 提取用户数据
- 使用预设中定义的 CSS 选择器规则匹配各字段
- 抓取结果更新 SiteUserInfo → notifyListeners

## WebView Cookie 抓取方案

### 流程

```
用户点击 "通过 WebView 登录"
  → 打开 WebView 加载 site.baseUrl
  → 用户在 WebView 中手动登录
  → 监听 URL 变化，当从登录页跳转回站内主页时判定登录成功
  → 执行 js: document.cookie 提取 cookie 字符串
  → 加密存入 FlutterSecureStorage
  → 自动触发 fetchUserInfo 验证有效性
```

### 安全

- Cookie 使用 FlutterSecureStorage 存储（与下载器密码同级别）
- WebView 不保存浏览历史
- 用户可随时清除/重新设置
- 不存储明文账号密码

## 预设 JSON 格式

从 PT-depiler 的 287 个 TypeScript 站点定义转化，精简为最小元数据：

```json
[
  {
    "id": "m-team",
    "name": "M-Team",
    "baseUrl": "https://m-team.cc",
    "tags": ["电影", "综合"],
    "category": "影视",
    "iconAsset": "assets/sites/icons/m-team.ico"
  }
]
```

## 依赖变更

- 新增：`webview_flutter` — WebView Cookie 登录
- 注册 assets：`assets/sites/presets.json`、`assets/sites/icons/`
