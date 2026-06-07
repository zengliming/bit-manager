# Bit Manager — Flutter 多客户端 BT 管理应用设计文档

> 版本: 1.0  
> 日期: 2026-06-07  
> 状态: Draft

---

## 1. 项目概述

### 1.1 目标

基于 Flutter 开发一款移动端（Android/iOS）应用，用于统一管理多个 qBittorrent 和 Transmission 客户端。

### 1.2 核心功能

- **多客户端管理**：添加/编辑/删除/启用/停用客户端连接
- **RSS 订阅下载**：RSS 订阅源管理，自动/手动筛选并推送到指定客户端
- **统一种子管理**：跨客户端查看所有种子，状态筛选、搜索、批量操作
- **全局统计面板**：聚合展示所有客户端的下载速度、上传速度、活动种子、磁盘占用等
- **种子操作**：暂停/恢复/删除（可带文件）、编辑 Tracker

### 1.3 目标平台

- Android
- iOS

### 1.4 UI 风格

Material Design 3（Material You），支持明/暗主题。

---

## 2. 技术架构

### 2.1 选型

| 层 | 技术 |
|----|------|
| UI 框架 | Flutter 3.44.1+ (Dart 3.12+) |
| 状态管理 | Provider |
| HTTP 客户端 | dio |
| 本地存储 | shared_preferences + 文件存储（配置持久化） |
| RSS 解析 | xml (Dart 内置) + http |
| 路由 | Navigator 2.0 / go_router |

### 2.2 分层架构

```
┌─────────────────────────────────────────┐
│  UI Layer (Material 3 Widgets)           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │ 首页统计  │ │ RSS订阅   │ │ 种子管理  │ │
│  │ /客户端管理│ │ /RSS条目  │ │ /种子详情 │ │
│  └─────┬────┘ └────┬─────┘ └────┬─────┘ │
├────────┼───────────┼────────────┼────────┤
│  ViewModel / Provider                  │
│  ┌──────────────────────────────────┐ │
│  │ ClientProvider ← 客户端配置+状态   │ │
│  │ RssProvider    ← RSS源+条目管理    │ │
│  │ TorrentProvider ← 种子列表+筛选    │ │
│  │ StatsProvider   ← 全局统计聚合     │ │
│  └──────┬───────────────────────────┘ │
├─────────┼──────────────────────────────┤
│  Service Layer                         │
│  ┌──────────────────────────────────┐ │
│  │ ITorrentClientService (抽象接口)   │ │
│  │  ├── QBittorrentService           │ │
│  │  └── TransmissionService          │ │
│  │ RssService (RSS 抓取+解析+缓存)    │ │
│  └──────┬───────────────────────────┘ │
├─────────┼──────────────────────────────┤
│  Utils / Infrastructure               │
│  ┌──────────────┐ ┌────────────────┐  │
│  │ HttpClient   │ │ Storage        │  │
│  │ (dio封装)     │ │ (配置持久化)    │  │
│  └──────────────┘ └────────────────┘  │
└─────────────────────────────────────────┘
```

### 2.3 目录结构

```
lib/
├── main.dart
├── app.dart
│
├── models/
│   ├── client_config.dart       # 客户端连接配置
│   ├── torrent.dart             # 统一种子模型
│   ├── stats.dart               # 统计数据模型
│   └── rss_source.dart          # RSS 订阅源模型
│
├── services/
│   ├── torrent_client.dart      # ITorrentClientService 抽象接口
│   ├── qbittorrent_service.dart # qBittorrent Web API 实现
│   ├── transmission_service.dart# Transmission RPC 实现
│   ├── rss_service.dart         # RSS 获取与解析
│   └── refresh_service.dart     # 定时轮询调度服务
│
├── providers/
│   ├── client_provider.dart     # 客户端配置 CRUD + 连接状态
│   ├── rss_provider.dart        # RSS 源管理 + 条目 + 自动下载
│   ├── torrent_provider.dart    # 种子列表 + 筛选 + 批量操作
│   └── stats_provider.dart      # 全局统计聚合
│
├── screens/
│   ├── home_screen.dart         # 首页/仪表盘
│   ├── client_list_screen.dart  # 客户端列表
│   ├── client_form_screen.dart  # 添加/编辑客户端
│   ├── rss_sources_screen.dart  # RSS 订阅源列表
│   ├── rss_source_form_screen.dart # 添加/编辑 RSS 源
│   ├── rss_items_screen.dart    # RSS 条目浏览 + 过滤下载
│   ├── torrent_list_screen.dart # 种子列表
│   ├── torrent_detail_screen.dart # 种子详情
│   └── settings_screen.dart     # 全局设置
│
├── widgets/
│   ├── stats_card.dart          # 统计数字卡片
│   ├── stats_overview.dart      # 全局概览面板
│   ├── client_tile.dart         # 客户端列表项
│   ├── torrent_tile.dart        # 种子列表项
│   ├── rss_source_tile.dart     # RSS 源列表项
│   ├── rss_item_tile.dart       # RSS 条目组件（含已存在标记）
│   ├── speed_indicator.dart     # 速度指示器
│   ├── speed_chart.dart         # 速度趋势图（可选）
│   ├── status_chip.dart         # 状态标签
│   └── empty_state.dart         # 空状态占位
│
└── utils/
    ├── http_client.dart         # dio 封装（Cookie 自动管理）
    ├── storage.dart             # 本地配置持久化
    ├── constants.dart           # 常量定义
    └── helpers.dart             # 格式化等通用函数
```

---

## 3. 数据模型

### 3.1 ClientConfig — 客户端配置

```dart
enum ClientType { qBittorrent, transmission }

class ClientConfig {
  final String id;              // UUID
  String name;                  // 自定义名称，如 "NAS-4T"
  ClientType type;              // 客户端类型
  String host;                  // IP 或域名
  int port;                     // 端口
  String? username;
  String? password;
  bool useSsl;                  // HTTPS 开关
  bool isActive;                // 启用/停用（停用时跳过轮询）
  int timeoutSeconds;           // 请求超时（默认 10s）
  String? defaultSavePath;      // 默认保存路径（可选）
  DateTime addedAt;
}
```

### 3.2 Torrent — 统一种子模型

```dart
enum TorrentState {
  downloading,  // 下载中
  seeding,      // 做种中
  paused,       // 已暂停
  checking,     // 校验中
  queued,       // 队列中
  error,        // 出错
  metaDL,       // 获取元数据（磁力链接）
  unknown,
}

class Torrent {
  final String id;              // 客户端内唯一标识
  final String hash;            // Info hash
  String name;
  final String clientId;        // 所属客户端 ID
  final ClientType clientType;
  double progress;              // 0.0 ~ 1.0
  TorrentState state;
  int downloadSpeed;            // bytes/s
  int uploadSpeed;
  int downloaded;               // 已下载字节
  int uploaded;                 // 已上传字节
  int totalSize;                // 总大小
  double ratio;                 // 分享率
  int peersConnected;
  int seedsConnected;
  int peersTotal;
  int seedsTotal;
  int eta;                      // 预计剩余秒数
  String? error;
  String? savePath;
  DateTime? addedAt;
  DateTime? completedAt;
  List<String> trackers;
}
```

### 3.3 RssSource — RSS 订阅源

```dart
class RssSource {
  final String id;
  String name;
  String url;
  String? filterRegex;             // 可选标题匹配正则
  bool autoDownload;               // 是否自动下载
  String? assignedClientId;        // 自动下载目标客户端 ID
  int refreshIntervalMinutes;      // 刷新间隔（默认15分钟）
  String? savePath;                // 保存路径（覆盖客户端默认）
  bool enableRegex;                // 是否启用正则过滤
  DateTime? lastFetchedAt;
  DateTime addedAt;
}
```

### 3.4 RssItem — RSS 条目

```dart
class RssItem {
  final String guid;               // RSS guid，去重依据
  String title;
  String? link;                    // magnet 或 torrent URL
  String? category;
  DateTime pubDate;
  bool isDuplicate;                // 跨客户端已存在标记
  bool isDownloaded;               // 已被当前 RSS 源下载过
}
```

### 3.5 GlobalStats / ClientStats — 统计数据

```dart
class GlobalStats {
  int totalTorrents;
  int activeTorrents;
  int downloadingCount;
  int seedingCount;
  int pausedCount;
  int errorCount;
  int downloadSpeed;
  int uploadSpeed;
  int totalDownloaded;
  int totalUploaded;
  int totalSizeOnDisk;
  List<ClientStats> clientStatsList;
}

class ClientStats {
  String clientId;
  String clientName;
  ClientType type;
  bool online;
  int torrentCount;
  int downloadSpeed;
  int uploadSpeed;
  int sizeOnDisk;
}
```

---

## 4. API 抽象层

### 4.1 统一接口定义

```dart
abstract class ITorrentClientService {
  /// 测试连接是否可用
  Future<bool> testConnection(ClientConfig config);

  /// 获取所有种子（返回统一 Torrent 模型）
  Future<List<Torrent>> getTorrents(ClientConfig config);

  /// 获取种子详情
  Future<TorrentDetail> getTorrentDetail(ClientConfig config, String hash);

  /// 获取种子文件列表
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash);

  /// 获取种子的 Tracker 列表
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash);

  /// 添加种子（本地文件路径）
  Future<void> addTorrentFile(ClientConfig config, {required String filePath, String? savePath});

  /// 通过链接添加种子（magnet / http url）
  Future<void> addTorrentFromUrl(ClientConfig config, {required String url, String? savePath});

  /// 暂停种子
  Future<void> pauseTorrent(ClientConfig config, String hash);

  /// 恢复种子
  Future<void> resumeTorrent(ClientConfig config, String hash);

  /// 删除种子
  Future<void> deleteTorrent(ClientConfig config, String hash, {bool deleteFiles = false});

  /// 替换 Tracker
  Future<void> replaceTracker(ClientConfig config, String hash, String oldUrl, String newUrl);

  /// 添加 Tracker
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl);

  /// 移除 Tracker
  Future<void> removeTracker(ClientConfig config, String hash, String trackerUrl);

  /// 检查种子是否已存在
  Future<bool> isTorrentExist(ClientConfig config, String hash);

  /// 获取客户端统计
  Future<ClientStats> getStats(ClientConfig config);
}
```

### 4.2 qBittorrent 实现要点

- **基础 URL**: `http(s)://host:port/api/v2/`
- **认证**: POST `/auth/login` → 获取 SID Cookie → 自动附带
- **种子列表**: GET `/torrents/info`
- **添加**: POST `/torrents/add`（支持 URL 和文件）
- **删除**: POST `/torrents/delete`（`deleteFiles=true/false`）
- **状态映射**: `downloading` / `seeding` / `paused` / `stalled` / `checking` / `error` → `TorrentState`
- **统计**: GET `/transfer/info` + `/torrents/info`

### 4.3 Transmission 实现要点

- **RPC URL**: `http(s)://host:port/transmission/rpc`
- **认证**: 基础认证或无认证
- **Session ID**: 首次请求获取 `X-Transmission-Session-Id`，后续请求携带
- **种子列表**: `{"method": "torrent-get", "arguments": {...}}`
- **添加**: `torrent-add`（支持 `filename` URL 和 `metainfo` base64）
- **删除**: `torrent-remove`（`delete-local-data=true/false`）
- **状态映射**: `0(停止)` / `1(校验等待)` / `2(校验中)` / `3(下载等待)` / `4(下载中)` / `5(做种等待)` / `6(做种中)` → `TorrentState`
- **统计**: `session-stats` RPC 调用

---

## 5. RSS 订阅与自动下载

### 5.1 整体流程

```
┌──────────────┐    ┌─────────────────────┐    ┌───────────────────┐
│ 添加 RSS 源   │───→│ 定时刷新 (15min)      │───→│ 解析 RSS XML       │
│ (name+url)   │    │ (或手动下拉刷新)       │    │ 提取条目列表        │
└──────────────┘    └─────────────────────┘    └────────┬──────────┘
                                                         │
                    ┌──────────────────────┐              │
                    │ 跨客户端已存在检查     │←──── 条目列表 ─┘
                    │ (对比所有客户端种子hash)│
                    └────────┬─────────────┘
                             │
                    ┌────────▼─────────────┐
                    │ 自动下载模式判断       │
                    │  ├─ 是 → 正则匹配标题  │
                    │  │     → 匹配成功      │
                    │  │     → 推送到目标客户端│
                    │  └─ 否 → 等待手动筛选  │
                    └──────────────────────┘
```

### 5.2 定时刷新机制

- 应用在前台时，`RefreshService` 管理一个 Timer
- 每个 RSS 源可独立配置刷新间隔（默认 15 分钟）
- 每次刷新：获取新条目 → 跨客户端查重 → 自动下载匹配 → 更新 UI
- 应用切到后台时暂停 Timer，回到前台时恢复
- 记录 `lastFetchedAt`，只获取该时间之后的新条目（减少重复处理）

### 5.3 自动下载条件

自动下载触发条件（全部满足）：
1. RSS 源开启了 `autoDownload == true`
2. 该条目 `isDuplicate == false`（跨客户端不存在）
3. 该条目 `isDownloaded == false`（未通过此 RSS 源下载过）
4. 如果设置了 `filterRegex`，标题匹配成功
5. 如果设置了 `assignedClientId`，该客户端在线

---

## 6. 状态管理与数据流

### 6.1 Provider 职责

| Provider | 职责 | 刷新时机 |
|----------|------|---------|
| `ClientProvider` | 客户端配置 CRUD，连接测试，在线状态管理 | 用户操作时 |
| `TorrentProvider` | 从所有在线客户端聚合种子列表，状态筛选，搜索，批量操作 | 3s 轮询 + 手动刷新 |
| `StatsProvider` | 聚合全局统计，各客户端明细统计 | 3s 轮询 + 手动刷新 |
| `RssProvider` | RSS 源管理，条目缓存，自动下载调度 | 定时器 + 手动刷新 |

### 6.2 数据刷新策略

| 场景 | 行为 |
|------|------|
| App 前台活跃 | 3 秒轮询所有在线客户端 |
| 特定客户端离线 | 标记为离线，跳过轮询，3 次失败后不再重试（需手动恢复） |
| 切换到后台 | 暂停所有轮询 |
| 回到前台 | 立即刷新一次，恢复轮询 |
| 手动下拉刷新 | 强制立即刷新全部 + 重置离线状态重试 |
| RSS 定时刷新 | 独立的间隔定时器（按源配置） |

---

## 7. UI 页面设计

### 7.1 页面结构

```
底部导航栏（4 个 Tab）:
┌──────────┬──────────┬──────────┬──────────┐
│  📊 概览  │  📡 RSS   │  🌱 种子   │  ⚙️ 设置  │
└──────────┴──────────┴──────────┴──────────┘
```

### 7.2 概览页 (HomeScreen)

- 顶部：全局速度卡片（下载/上传）、活动种子数、磁盘占用
- 中部：各客户端缩略卡片（名称、类型图标、速度、种子数、在线状态）
- 底部：最近活动时间线（可选）

### 7.3 RSS 订阅页 (RssSourcesScreen)

- RSS 源列表（名称、条目数、最后刷新时间、自动下载开关）
- 点击进入该源的条目浏览页
- FAB 添加 RSS 源
- 每个源：右滑刷新、长按编辑/删除

### 7.4 RSS 条目页 (RssItemsScreen)

- 条目列表（标题、发布日期、大小、已存在标记）
- 已存在的条目灰显 + "已存在" 标签
- 勾选条目 → 底部弹出选择客户端 → 添加到下载
- 自动下载的条目显示 "已推送" 标记

### 7.5 种子列表页 (TorrentListScreen)

- 顶部搜索栏 + 刷新按钮
- 状态筛选 Chip 行：全部/下载中/做种中/已暂停/错误
- 下拉选择：客户端筛选
- 种子列表项：名称、进度条、速度、做种数、所属客户端标签
- **长按进入批量模式**：
  - 顶部：全选/取消、已选数量
  - 底部操作栏：恢复/暂停/删除/改 Tracker
  - 点选多个种子后批量操作

### 7.6 客户端管理 (嵌套在设置页)

- 客户端列表（名称、类型、连接状态、最后在线时间）
- 添加客户端：填写名称、地址、端口、账号密码
- 连接测试按钮
- 编辑/删除客户端

### 7.7 种子详情页 (TorrentDetailScreen)

- 基本信息：名称、Hash、大小、进度
- 速度曲线（可选）
- 文件列表（文件名、大小、进度、优先级）
- Tracker 列表（URL、状态、更新次数）
- 操作按钮：暂停/恢复/删除/编辑 Tracker

---

## 8. 错误处理

### 8.1 网络异常场景

| 场景 | 表现 |
|------|------|
| 客户端无法连接 | 列表中标记为离线，统计数据排除该客户端 |
| 超时 | 重试 1 次后标记离线 |
| 认证失败 | 提示用户检查账号密码，标记离线 |
| RSS 源无法访问 | 标记该源上次刷新失败，不影响其他源 |

### 8.2 UI 反馈

- 每个客户端卡片显示在线/离线状态
- 离线客户端显示最后在线时间
- 操作失败弹出 SnackBar 提示错误原因
- 刷新时顶部显示加载指示器
- 空列表显示 EmptyState 组件（引导添加客户端/RSS源）

---

## 9. 持久化存储

### 9.1 存储内容

| 数据 | 存储方式 | 备注 |
|------|---------|------|
| 客户端配置 | `shared_preferences` JSON 数组 | 不存密码原文，可考虑加密 |
| RSS 源配置 | `shared_preferences` JSON 数组 | 含过滤规则 |
| RSS 条目缓存 | 内存缓存 + 轻量持久化 | `lastFetchedAt` 和已下载 GUID |
| 应用设置 | `shared_preferences` | 刷新间隔、主题选择等 |

### 9.2 安全性

- 密码使用 `flutter_secure_storage` 或简单 base64 编码（根据用户需求）
- 考虑后续支持指纹/面部解锁

---

## 10. 边界场景与未来扩展

### 10.1 MVP 范围（本期实现）

- [x] 多客户端 CRUD（qBittorrent + Transmission）
- [x] RSS 订阅管理 + 自动/手动下载 + 已存在过滤
- [x] 统一种子列表 + 状态筛选 + 搜索
- [x] 种子批量操作（暂停/恢复/删除/改 Tracker）
- [x] 全局统计面板
- [ ] 种子详情页（文件列表、Tracker 列表）

### 10.2 未来可扩展

- 种子详情页完整实现（文件列表、Tracker 管理、速度曲线图）
- 推送通知（下载完成、出错）
- iOS Widget 显示当前速度
- 多语言支持
- 自动备份配置到 iCloud/Google Drive
- 种子分类/标签管理
- 代理支持
- 速度限制设置
