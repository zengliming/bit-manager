# Bit Manager — Flutter 多客户端 BT 管理工具 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter 移动端应用，统一管理多个 qBittorrent 和 Transmission 客户端，支持 RSS 订阅下载、统一种子管理、全局统计面板。

**Architecture:** Provider 状态管理 + 抽象接口服务层（ITorrentClientService）统一 qB 和 TR 的 API 差异，底层基于 dio 做 HTTP 通信。RSS 订阅驱动种子添加流程，跨客户端聚合数据展示。

**Tech Stack:** Flutter 3.44+ / Dart 3.12+, Provider, dio, shared_preferences, go_router

---

## File Structure

```
flutter_bit_manager/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   │
│   ├── models/
│   │   ├── client_config.dart
│   │   ├── torrent.dart
│   │   ├── stats.dart
│   │   └── rss_source.dart
│   │
│   ├── services/
│   │   ├── torrent_client.dart        # ITorrentClientService 抽象
│   │   ├── service_factory.dart       # 工厂 + 单例管理
│   │   ├── qbittorrent_service.dart
│   │   ├── transmission_service.dart
│   │   ├── rss_service.dart
│   │   └── refresh_service.dart
│   │
│   ├── providers/
│   │   ├── client_provider.dart
│   │   ├── torrent_provider.dart
│   │   ├── stats_provider.dart
│   │   └── rss_provider.dart
│   │
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── client_list_screen.dart
│   │   ├── client_form_screen.dart
│   │   ├── rss_sources_screen.dart
│   │   ├── rss_source_form_screen.dart
│   │   ├── rss_items_screen.dart
│   │   ├── torrent_list_screen.dart
│   │   └── settings_screen.dart
│   │
│   ├── widgets/
│   │   ├── stats_card.dart
│   │   ├── client_tile.dart
│   │   ├── torrent_tile.dart
│   │   ├── rss_source_tile.dart
│   │   ├── rss_item_tile.dart
│   │   ├── status_chip.dart
│   │   └── empty_state.dart
│   │
│   └── utils/
│       ├── http_client.dart
│       ├── storage.dart
│       ├── constants.dart
│       └── helpers.dart
│
├── pubspec.yaml
└── test/
    ├── models/
    ├── services/
    └── providers/
```

---

## Phase 1: 项目工程与基础设施

### Task 1: 项目创建与依赖配置

**Files:**
- Create: `pubspec.yaml`（通过 `flutter create` 生成后修改）
- Modify: 整个工程结构

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd /d/code/flutter/bit-manager
flutter create --org com.bitmanager --project-name bit_manager .
```

Expected: Flutter 项目骨架生成完毕。

- [ ] **Step 2: 配置 pubspec.yaml 添加依赖**

```yaml
# pubspec.yaml — 在 dependencies 段添加:
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  dio: ^5.7.0
  shared_preferences: ^2.3.3
  go_router: ^14.6.2
  uuid: ^4.5.1
  intl: ^0.19.0
  flutter_secure_storage: ^9.2.4
  xml: ^6.5.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  mockito: ^5.4.4
  build_runner: ^2.4.13
```

- [ ] **Step 3: 安装依赖**

```bash
flutter pub get
```

Expected: 所有依赖下载成功，无报错。

- [ ] **Step 4: 创建目录结构**

```bash
mkdir -p lib/models lib/services lib/providers lib/screens lib/widgets lib/utils test/models test/services test/providers
```

- [ ] **Step 5: 提交**

```bash
git init
git add .
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

### Task 2: 常量与工具函数

**Files:**
- Create: `lib/utils/constants.dart`
- Create: `lib/utils/helpers.dart`

- [ ] **Step 1: 创建常量文件**

```dart
// lib/utils/constants.dart
class AppConstants {
  static const String appName = 'Bit Manager';

  // 默认刷新间隔
  static const int defaultPollIntervalSeconds = 3;
  static const int defaultRssRefreshMinutes = 15;
  static const int defaultTimeoutSeconds = 10;
  static const int maxRetryCount = 3;

  // 存储 Key
  static const String storageKeyClients = 'clients';
  static const String storageKeyRssSources = 'rss_sources';
  static const String storageKeyRssDownloaded = 'rss_downloaded_guids';
  static const String storageKeyThemeMode = 'theme_mode';
  static const String storageKeyPollInterval = 'poll_interval';

  // qBittorrent API 路径
  static const String qbLogin = '/api/v2/auth/login';
  static const String qbTorrents = '/api/v2/torrents/info';
  static const String qbTorrentAdd = '/api/v2/torrents/add';
  static const String qbTorrentDelete = '/api/v2/torrents/delete';
  static const String qbTorrentPause = '/api/v2/torrents/pause';
  static const String qbTorrentResume = '/api/v2/torrents/resume';
  static const String qbTorrentTrackers = '/api/v2/torrents/trackers';
  static const String qbTransferInfo = '/api/v2/transfer/info';

  // Transmission RPC 路径
  static const String trRpc = '/transmission/rpc';
}
```

- [ ] **Step 2: 创建工具函数**

```dart
// lib/utils/helpers.dart
import 'package:intl/intl.dart';

/// 格式化字节数为可读字符串
String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (bytes.bitLength / 10).floor().clamp(0, suffixes.length - 1);
  final value = bytes / (1 << (i * 10));
  return '${value.toStringAsFixed(decimals)} ${suffixes[i]}';
}

/// 格式化速度（带 /s 后缀）
String formatSpeed(int bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

/// 格式化百分比
String formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

/// 格式化时间戳
String formatDateTime(DateTime? dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  if (dt == null) return '-';
  return DateFormat(pattern).format(dt);
}

/// 格式化 ETA（秒数转可读字符串）
String formatEta(int seconds) {
  if (seconds <= 0) return '--';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${seconds % 60}s';
}

/// 格式化分享率
String formatRatio(double ratio) => ratio.toStringAsFixed(2);
```

- [ ] **Step 3: 提交**

```bash
git add lib/utils/
git commit -m "chore: add constants and helper utilities"
```

---

### Task 3: 本地存储封装

**Files:**
- Create: `lib/utils/storage.dart`

- [ ] **Step 1: 创建存储服务**

```dart
// lib/utils/storage.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一的本地存储封装
/// 明文配置使用 SharedPreferences，敏感信息（密码）使用 SecureStorage
class LocalStorage {
  static LocalStorage? _instance;
  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  bool _initialized = false;

  LocalStorage._();

  static Future<LocalStorage> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorage._();
      await _instance!._init();
    } else if (!_instance!._initialized) {
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // --- JSON 数组操作（用于客户端列表、RSS 源列表） ---

  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> saveJsonList(String key, List<Map<String, dynamic>> list) async {
    await _prefs.setString(key, jsonEncode(list));
  }

  // --- 密码存储 ---

  Future<void> savePassword(String clientId, String password) async {
    await _secure.write(key: 'pwd_$clientId', value: password);
  }

  Future<String?> getPassword(String clientId) async {
    return await _secure.read(key: 'pwd_$clientId');
  }

  Future<void> deletePassword(String clientId) async {
    await _secure.delete(key: 'pwd_$clientId');
  }

  // --- 简单键值 ---

  Future<String?> getString(String key) async => _prefs.getString(key);
  Future<void> setString(String key, String value) async => _prefs.setString(key, value);
  Future<int?> getInt(String key) async => _prefs.getInt(key);
  Future<void> setInt(String key, int value) async => _prefs.setInt(key, value);
  Future<bool?> getBool(String key) async => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) async => _prefs.setBool(key, value);
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/utils/storage.dart
git commit -m "feat: add local storage wrapper with secure password storage"
```

---

### Task 4: 数据模型

**Files:**
- Create: `lib/models/client_config.dart`
- Create: `lib/models/torrent.dart`
- Create: `lib/models/stats.dart`
- Create: `lib/models/rss_source.dart`

- [ ] **Step 1: 创建客户端配置模型**

```dart
// lib/models/client_config.dart
import 'dart:convert';

enum ClientType { qBittorrent, transmission }

class ClientConfig {
  final String id;
  String name;
  ClientType type;
  String host;
  int port;
  String? username;
  String? password;
  bool useSsl;
  bool isActive;
  int timeoutSeconds;
  String? defaultSavePath;
  DateTime addedAt;

  ClientConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.useSsl = false,
    this.isActive = true,
    this.timeoutSeconds = 10,
    this.defaultSavePath,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get baseUrl =>
      '${useSsl ? "https" : "http"}://$host:$port';

  ClientConfig copyWith({
    String? name,
    ClientType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useSsl,
    bool? isActive,
    int? timeoutSeconds,
    String? defaultSavePath,
  }) {
    return ClientConfig(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useSsl: useSsl ?? this.useSsl,
      isActive: isActive ?? this.isActive,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      defaultSavePath: defaultSavePath ?? this.defaultSavePath,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'host': host,
    'port': port,
    'username': username,
    'useSsl': useSsl,
    'isActive': isActive,
    'timeoutSeconds': timeoutSeconds,
    'defaultSavePath': defaultSavePath,
    'addedAt': addedAt.toIso8601String(),
  };

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    type: ClientType.values.byName(json['type'] as String),
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String?,
    useSsl: json['useSsl'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
    timeoutSeconds: json['timeoutSeconds'] as int? ?? 10,
    defaultSavePath: json['defaultSavePath'] as String?,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
  );
}
```

- [ ] **Step 2: 创建种子模型**

```dart
// lib/models/torrent.dart
enum TorrentState {
  downloading,
  seeding,
  paused,
  checking,
  queued,
  error,
  metaDL,
  unknown,
}

class Torrent {
  final String id;
  final String hash;
  String name;
  final String clientId;
  final ClientType clientType;
  double progress;
  TorrentState state;
  int downloadSpeed;
  int uploadSpeed;
  int downloaded;
  int uploaded;
  int totalSize;
  double ratio;
  int peersConnected;
  int seedsConnected;
  int peersTotal;
  int seedsTotal;
  int eta;
  String? error;
  String? savePath;
  DateTime? addedAt;
  DateTime? completedAt;
  List<String> trackers;

  Torrent({
    required this.id,
    required this.hash,
    required this.name,
    required this.clientId,
    required this.clientType,
    this.progress = 0,
    this.state = TorrentState.unknown,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.downloaded = 0,
    this.uploaded = 0,
    this.totalSize = 0,
    this.ratio = 0,
    this.peersConnected = 0,
    this.seedsConnected = 0,
    this.peersTotal = 0,
    this.seedsTotal = 0,
    this.eta = 0,
    this.error,
    this.savePath,
    this.addedAt,
    this.completedAt,
    this.trackers = const [],
  });

  bool get isDownloading => state == TorrentState.downloading || state == TorrentState.metaDL;
  bool get isSeeding => state == TorrentState.seeding;
  bool get isPaused => state == TorrentState.paused;
  bool get isComplete => progress >= 1.0;
  bool get isError => state == TorrentState.error;
  bool get isActive => isDownloading || isSeeding || state == TorrentState.checking;
}
```

- [ ] **Step 3: 创建统计模型**

```dart
// lib/models/stats.dart
import 'client_config.dart';

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

  GlobalStats({
    this.totalTorrents = 0,
    this.activeTorrents = 0,
    this.downloadingCount = 0,
    this.seedingCount = 0,
    this.pausedCount = 0,
    this.errorCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalDownloaded = 0,
    this.totalUploaded = 0,
    this.totalSizeOnDisk = 0,
    this.clientStatsList = const [],
  });
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

  ClientStats({
    required this.clientId,
    required this.clientName,
    required this.type,
    this.online = false,
    this.torrentCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.sizeOnDisk = 0,
  });
}
```

- [ ] **Step 4: 创建 RSS 模型**

```dart
// lib/models/rss_source.dart
class RssSource {
  final String id;
  String name;
  String url;
  String? filterRegex;
  bool autoDownload;
  String? assignedClientId;
  int refreshIntervalMinutes;
  String? savePath;
  DateTime? lastFetchedAt;
  DateTime addedAt;

  RssSource({
    required this.id,
    required this.name,
    required this.url,
    this.filterRegex,
    this.autoDownload = false,
    this.assignedClientId,
    this.refreshIntervalMinutes = 15,
    this.savePath,
    this.lastFetchedAt,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'filterRegex': filterRegex,
    'autoDownload': autoDownload,
    'assignedClientId': assignedClientId,
    'refreshIntervalMinutes': refreshIntervalMinutes,
    'savePath': savePath,
    'lastFetchedAt': lastFetchedAt?.toIso8601String(),
    'addedAt': addedAt.toIso8601String(),
  };

  factory RssSource.fromJson(Map<String, dynamic> json) => RssSource(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    filterRegex: json['filterRegex'] as String?,
    autoDownload: json['autoDownload'] as bool? ?? false,
    assignedClientId: json['assignedClientId'] as String?,
    refreshIntervalMinutes: json['refreshIntervalMinutes'] as int? ?? 15,
    savePath: json['savePath'] as String?,
    lastFetchedAt: DateTime.tryParse(json['lastFetchedAt'] as String? ?? ''),
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class RssItem {
  final String guid;
  String title;
  String? link;
  String? category;
  DateTime pubDate;
  bool isDuplicate;
  bool isDownloaded;

  RssItem({
    required this.guid,
    required this.title,
    this.link,
    this.category,
    required this.pubDate,
    this.isDuplicate = false,
    this.isDownloaded = false,
  });
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/models/
git commit -m "feat: add all data models"
```

---

## Phase 2: 服务层

### Task 5: HTTP 客户端封装

**Files:**
- Create: `lib/utils/http_client.dart`

- [ ] **Step 1: 创建 HTTP 客户端工具**

```dart
// lib/utils/http_client.dart
import 'package:dio/dio.dart';
import '../models/client_config.dart';

class HttpClientUtil {
  static HttpClientUtil? _instance;
  late Dio _dio;

  HttpClientUtil._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'BitManager/1.0'},
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[HTTP] $obj'),
    ));
  }

  static HttpClientUtil get instance {
    _instance ??= HttpClientUtil._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// 创建一个为特定客户端配置的 Dio 实例（含超时设置）
  Dio createClientDio(ClientConfig config) {
    return Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: Duration(seconds: config.timeoutSeconds),
      receiveTimeout: Duration(seconds: config.timeoutSeconds + 5),
      sendTimeout: Duration(seconds: config.timeoutSeconds + 5),
      headers: {'User-Agent': 'BitManager/1.0'},
    ));
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/utils/http_client.dart
git commit -m "feat: add HTTP client utility with Dio"
```

---

### Task 6: 抽象接口定义 + 工厂

**Files:**
- Create: `lib/services/torrent_client.dart`
- Create: `lib/services/service_factory.dart`

- [ ] **Step 1: 创建抽象接口**

```dart
// lib/services/torrent_client.dart
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';

/// 统一 BitTorrent 客户端 API 抽象
abstract class ITorrentClientService {
  /// 测试连接是否可用
  Future<bool> testConnection(ClientConfig config);

  /// 获取所有种子
  Future<List<Torrent>> getTorrents(ClientConfig config);

  /// 获取种子文件列表
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash);

  /// 获取种子的 Tracker 列表
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash);

  /// 添加种子（本地文件）
  Future<void> addTorrentFile(ClientConfig config, {required String filePath, String? savePath});

  /// 通过链接添加种子
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

class TorrentFile {
  final String name;
  final int size;
  final double progress;
  final int priority;

  TorrentFile({required this.name, required this.size, required this.progress, this.priority = 0});
}

class TrackerInfo {
  final String url;
  final String status;
  final int peers;

  TrackerInfo({required this.url, required this.status, this.peers = 0});
}
```

- [ ] **Step 2: 创建服务工厂**

```dart
// lib/services/service_factory.dart
import '../models/client_config.dart';
import 'torrent_client.dart';
import 'qbittorrent_service.dart';
import 'transmission_service.dart';

class ServiceFactory {
  static final Map<ClientType, ITorrentClientService> _services = {};

  static ITorrentClientService getService(ClientType type) {
    if (!_services.containsKey(type)) {
      _services[type] = _createService(type);
    }
    return _services[type]!;
  }

  static ITorrentClientService _createService(ClientType type) {
    switch (type) {
      case ClientType.qBittorrent:
        return QBittorrentService();
      case ClientType.transmission:
        return TransmissionService();
    }
  }

  /// 清空缓存（测试用）
  static void reset() => _services.clear();
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/services/torrent_client.dart lib/services/service_factory.dart
git commit -m "feat: add ITorrentClientService abstraction and factory"
```

---

### Task 7: qBittorrent 服务实现

**Files:**
- Create: `lib/services/qbittorrent_service.dart`

- [ ] **Step 1: 创建 qBittorrent 实现**

```dart
// lib/services/qbittorrent_service.dart
import 'package:dio/dio.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import 'torrent_client.dart';

class QBittorrentService implements ITorrentClientService {
  /// 登录并获取 SID
  Future<String?> _login(ClientConfig config) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.qbLogin}',
        data: {
          'username': config.username ?? '',
          'password': config.password ?? '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      // qB 返回 SID 在 Set-Cookie 中
      final setCookie = resp.headers.value('set-cookie');
      if (setCookie != null && setCookie.contains('SID=')) {
        final match = RegExp(r'SID=([^;]+)').firstMatch(setCookie);
        return match?.group(1);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 携带 SID Cookie 的 GET 请求
  Future<Response> _get(ClientConfig config, String path, {Map<String, dynamic>? params, String? sid}) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    return dio.get(
      '${config.baseUrl}$path',
      queryParameters: params,
      options: Options(headers: {'Cookie': 'SID=$sid'}),
    );
  }

  /// 携带 SID Cookie 的 POST 请求
  Future<Response> _post(ClientConfig config, String path, {Map<String, dynamic>? data, String? sid}) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    return dio.post(
      '${config.baseUrl}$path',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': 'SID=$sid'},
      ),
    );
  }

  /// 将 qB 原始状态映射为统一状态
  TorrentState _mapState(String rawState) {
    switch (rawState) {
      case 'downloading': return TorrentState.downloading;
      case 'seeding': return TorrentState.seeding;
      case 'pausedUP':
      case 'pausedDL': return TorrentState.paused;
      case 'checkingUP':
      case 'checkingDL': return TorrentState.checking;
      case 'queuedUP':
      case 'queuedDL': return TorrentState.queued;
      case 'stalledUP':
      case 'stalledDL': return TorrentState.downloading;
      case 'metaDL': return TorrentState.metaDL;
      case 'error':
      case 'missingFiles': return TorrentState.error;
      default: return TorrentState.unknown;
    }
  }

  @override
  Future<bool> testConnection(ClientConfig config) async {
    final sid = await _login(config);
    return sid != null;
  }

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');

    final resp = await _get(config, AppConstants.qbTorrents, sid: sid);
    final List<dynamic> rawList = resp.data;
    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return Torrent(
        id: m['hash'] as String,
        hash: m['hash'] as String,
        name: m['name'] as String? ?? 'Unknown',
        clientId: config.id,
        clientType: config.type,
        progress: (m['progress'] as num).toDouble(),
        state: _mapState(m['state'] as String? ?? ''),
        downloadSpeed: (m['dlspeed'] as num?)?.toInt() ?? 0,
        uploadSpeed: (m['upspeed'] as num?)?.toInt() ?? 0,
        downloaded: (m['downloaded'] as num?)?.toInt() ?? 0,
        uploaded: (m['uploaded'] as num?)?.toInt() ?? 0,
        totalSize: (m['total_size'] as num?)?.toInt() ?? 0,
        ratio: (m['ratio'] as num?)?.toDouble() ?? 0,
        peersConnected: (m['num_leechs'] as num?)?.toInt() ?? 0,
        seedsConnected: (m['num_seeds'] as num?)?.toInt() ?? 0,
        peersTotal: (m['num_incomplete'] as num?)?.toInt() ?? 0,
        seedsTotal: (m['num_complete'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['error'] as String?,
        savePath: m['save_path'] as String?,
        addedAt: (m['added_on'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch((m['added_on'] as int) * 1000)
            : null,
        completedAt: (m['completion_on'] as num?) != null && (m['completion_on'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch((m['completion_on'] as int) * 1000)
            : null,
      );
    }).toList();
  }

  @override
  Future<ClientStats> getStats(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');

    final transferResp = await _get(config, AppConstants.qbTransferInfo, sid: sid);
    final transfer = transferResp.data as Map<String, dynamic>;

    return ClientStats(
      clientId: config.id,
      clientName: config.name,
      type: config.type,
      online: true,
      downloadSpeed: (transfer['dl_info_speed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (transfer['up_info_speed'] as num?)?.toInt() ?? 0,
      sizeOnDisk: 0, // qB 不直接提供，从种子列表汇总
    );
  }

  @override
  Future<void> addTorrentFromUrl(ClientConfig config, {required String url, String? savePath}) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final dio = HttpClientUtil.instance.createClientDio(config);
    final data = <String, dynamic>{'urls': url};
    if (savePath != null) data['savepath'] = savePath;
    await dio.post(
      '${config.baseUrl}${AppConstants.qbTorrentAdd}',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': 'SID=$sid'},
      ),
    );
  }

  @override
  Future<void> addTorrentFile(ClientConfig config, {required String filePath, String? savePath}) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final dio = HttpClientUtil.instance.createClientDio(config);
    final formData = FormData.fromMap({
      'torrents': await MultipartFile.fromFile(filePath),
      if (savePath != null) 'savepath': savePath,
    });
    await dio.post(
      '${config.baseUrl}${AppConstants.qbTorrentAdd}',
      data: formData,
      options: Options(headers: {'Cookie': 'SID=$sid'}),
    );
  }

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentPause, data: {'hashes': hash}, sid: sid);
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentResume, data: {'hashes': hash}, sid: sid);
  }

  @override
  Future<void> deleteTorrent(ClientConfig config, String hash, {bool deleteFiles = false}) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentDelete,
      data: {'hashes': hash, 'deleteFiles': deleteFiles ? 'true' : 'false'},
      sid: sid,
    );
  }

  @override
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final resp = await _get(config, '${AppConstants.qbTorrentTrackers}/$hash', sid: sid);
    final List<dynamic> rawList = resp.data;
    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return TrackerInfo(
        url: m['url'] as String? ?? '',
        status: m['msg'] as String? ?? '',
        peers: (m['num_peers'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final resp = await _get(config, '/api/v2/torrents/files', params: {'hash': hash}, sid: sid);
    final List<dynamic> rawList = resp.data;
    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return TorrentFile(
        name: m['name'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async {
    try {
      final torrents = await getTorrents(config);
      return torrents.any((t) => t.hash == hash);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceTracker(ClientConfig config, String hash, String oldUrl, String newUrl) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/editTracker',
      data: {'hash': hash, 'origUrl': oldUrl, 'newUrl': newUrl},
      sid: sid,
    );
  }

  @override
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/addTrackers',
      data: {'hash': hash, 'urls': trackerUrl},
      sid: sid,
    );
  }

  @override
  Future<void> removeTracker(ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/removeTrackers',
      data: {'hash': hash, 'urls': trackerUrl},
      sid: sid,
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/qbittorrent_service.dart
git commit -m "feat: implement qBittorrent service"
```

---

### Task 8: Transmission 服务实现

**Files:**
- Create: `lib/services/transmission_service.dart`

- [ ] **Step 1: 创建 Transmission 实现**

```dart
// lib/services/transmission_service.dart
import 'package:dio/dio.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import 'torrent_client.dart';

class TransmissionService implements ITorrentClientService {
  /// 获取 Session ID（Transmission RPC 需要）
  Future<String?> _getSessionId(ClientConfig config) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.trRpc}',
        data: {'method': 'session-get'},
        options: Options(
          validateStatus: (status) => status == 409, // 409 返回 Session-Id
        ),
      );
      return resp.headers.value('x-transmission-session-id');
    } catch (_) {
      return null;
    }
  }

  /// 带 Session ID 的 RPC 调用
  Future<Map<String, dynamic>> _rpcCall(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    final headers = <String, dynamic>{};
    if (sessionId != null) headers['X-Transmission-Session-Id'] = sessionId;
    if (config.username != null && config.password != null) {
      final basicAuth = base64Encode(utf8.encode('${config.username}:${config.password}'));
      headers['Authorization'] = 'Basic $basicAuth';
    }

    final resp = await dio.post(
      '${config.baseUrl}${AppConstants.trRpc}',
      data: {'method': method, 'arguments': args ?? {}},
      options: Options(headers: headers),
    );
    return resp.data as Map<String, dynamic>;
  }

  /// 映射 Transmission 状态码到统一状态
  TorrentState _mapState(int status) {
    // 0=停止, 1=校验等待, 2=校验中, 3=下载等待, 4=下载中, 5=做种等待, 6=做种中
    switch (status) {
      case 0: return TorrentState.paused;
      case 1:
      case 3: return TorrentState.queued;
      case 2: return TorrentState.checking;
      case 4: return TorrentState.downloading;
      case 5:
      case 6: return TorrentState.seeding;
      default: return TorrentState.unknown;
    }
  }

  @override
  Future<bool> testConnection(ClientConfig config) async {
    final sid = await _getSessionId(config);
    return sid != null;
  }

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');

    final result = await _rpcCall(config, 'torrent-get',
      args: {
        'fields': [
          'id', 'hashString', 'name', 'status', 'percentDone',
          'rateDownload', 'rateUpload', 'downloadedEver', 'uploadedEver',
          'totalSize', 'uploadRatio', 'peersConnected', 'peersSendingToUs',
          'peersGettingFromUs', 'peersFrom', 'eta', 'error', 'errorString',
          'downloadDir', 'addedDate', 'doneDate', 'trackerList',
        ],
      },
      sessionId: sid,
    );

    final arguments = result['arguments'] as Map<String, dynamic>;
    final List<dynamic> rawList = arguments['torrents'] as List<dynamic>;

    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return Torrent(
        id: (m['id'] as num).toString(),
        hash: m['hashString'] as String? ?? '',
        name: m['name'] as String? ?? 'Unknown',
        clientId: config.id,
        clientType: config.type,
        progress: (m['percentDone'] as num?)?.toDouble() ?? 0,
        state: _mapState((m['status'] as num?)?.toInt() ?? 0),
        downloadSpeed: (m['rateDownload'] as num?)?.toInt() ?? 0,
        uploadSpeed: (m['rateUpload'] as num?)?.toInt() ?? 0,
        downloaded: (m['downloadedEver'] as num?)?.toInt() ?? 0,
        uploaded: (m['uploadedEver'] as num?)?.toInt() ?? 0,
        totalSize: (m['totalSize'] as num?)?.toInt() ?? 0,
        ratio: (m['uploadRatio'] as num?)?.toDouble() ?? 0,
        peersConnected: (m['peersConnected'] as num?)?.toInt() ?? 0,
        seedsConnected: (m['peersSendingToUs'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['errorString'] as String?,
        savePath: m['downloadDir'] as String?,
        addedAt: (m['addedDate'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch((m['addedDate'] as int) * 1000)
            : null,
        completedAt: (m['doneDate'] as num?) != null && (m['doneDate'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch((m['doneDate'] as int) * 1000)
            : null,
        trackers: _parseTrackerList(m['trackerList'] as String? ?? ''),
      );
    }).toList();
  }

  List<String> _parseTrackerList(String trackerList) {
    return trackerList
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  @override
  Future<ClientStats> getStats(ClientConfig config) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');

    final result = await _rpcCall(config, 'session-stats', sessionId: sid);
    final args = result['arguments'] as Map<String, dynamic>;

    return ClientStats(
      clientId: config.id,
      clientName: config.name,
      type: config.type,
      online: true,
      downloadSpeed: (args['downloadSpeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (args['uploadSpeed'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> addTorrentFromUrl(ClientConfig config, {required String url, String? savePath}) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final args = <String, dynamic>{'filename': url};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  @override
  Future<void> addTorrentFile(ClientConfig config, {required String filePath, String? savePath}) async {
    // Transmission 需要 base64 编码的文件内容
    final fileBytes = await File(filePath).readAsBytes();
    final base64Data = base64Encode(fileBytes);
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final args = <String, dynamic>{'metainfo': base64Data};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    // Transmission 使用 id 而非 hash，需要先查找
    final ids = await _hashToIds(config, [hash], sid);
    await _rpcCall(config, 'torrent-stop', args: {'ids': ids}, sessionId: sid);
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    await _rpcCall(config, 'torrent-start', args: {'ids': ids}, sessionId: sid);
  }

  @override
  Future<void> deleteTorrent(ClientConfig config, String hash, {bool deleteFiles = false}) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    await _rpcCall(config, 'torrent-remove',
      args: {'ids': ids, 'delete-local-data': deleteFiles},
      sessionId: sid,
    );
  }

  /// 根据 hash 查找 Transmission 内部 ID
  Future<List<int>> _hashToIds(ClientConfig config, List<String> hashes, String sid) async {
    final result = await _rpcCall(config, 'torrent-get',
      args: {'fields': ['id', 'hashString']},
      sessionId: sid,
    );
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    return torrents
        .where((t) => hashes.contains((t as Map<String, dynamic>)['hashString'] as String))
        .map((t) => (t as Map<String, dynamic>)['id'] as int)
        .toList();
  }

  @override
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(config, 'torrent-get',
      args: {'ids': ids, 'fields': ['trackerList', 'trackerStats']},
      sessionId: sid,
    );
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    if (torrents.isEmpty) return [];
    final t = torrents[0] as Map<String, dynamic>;
    final stats = t['trackerStats'] as List<dynamic>? ?? [];
    return stats.map((s) {
      final m = s as Map<String, dynamic>;
      return TrackerInfo(
        url: m['announce'] as String? ?? '',
        status: m['lastAnnounceResult'] as String? ?? '',
        peers: (m['lastAnnouncePeerCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(config, 'torrent-get',
      args: {'ids': ids, 'fields': ['files', 'fileStats']},
      sessionId: sid,
    );
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    if (torrents.isEmpty) return [];
    final t = torrents[0] as Map<String, dynamic>;
    final files = t['files'] as List<dynamic>? ?? [];
    final fileStats = t['fileStats'] as List<dynamic>? ?? [];
    return List.generate(files.length, (i) {
      final f = files[i] as Map<String, dynamic>;
      final fs = i < fileStats.length ? fileStats[i] as Map<String, dynamic> : {};
      return TorrentFile(
        name: f['name'] as String? ?? '',
        size: (f['length'] as num?)?.toInt() ?? 0,
        progress: (f['bytesCompleted'] as num?)?.toDouble() ?? 0 / (f['length'] as num?)?.toDouble() ?? 1,
      );
    });
  }

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async {
    try {
      final torrents = await getTorrents(config);
      return torrents.any((t) => t.hash == hash);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceTracker(ClientConfig config, String hash, String oldUrl, String newUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;

    // Transmission 不支持直接替换，需要先获取当前 tracker 列表，替换后重新设置
    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url == oldUrl ? newUrl : t.url).toList();
    await _rpcCall(config, 'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }

  @override
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;

    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url).toList()..add(trackerUrl);
    await _rpcCall(config, 'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }

  @override
  Future<void> removeTracker(ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;

    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url).where((u) => u != trackerUrl).toList();
    await _rpcCall(config, 'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }
}
```

Note: `dart:convert` and `dart:io` need to be imported for base64/File. Add to top of file:

```dart
import 'dart:convert';
import 'dart:io';
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/transmission_service.dart
git commit -m "feat: implement Transmission service"
```

---

### Task 9: RSS 订阅服务

**Files:**
- Create: `lib/services/rss_service.dart`

- [ ] **Step 1: 创建 RSS 服务**

```dart
// lib/services/rss_service.dart
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import '../models/rss_source.dart';

class RssService {
  /// 从 RSS URL 获取并解析条目
  Future<List<RssItem>> fetchItems(RssSource source) async {
    try {
      final response = await http.get(Uri.parse(source.url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      return _parseXml(response.body, source);
    } catch (e) {
      throw Exception('Failed to fetch RSS: $e');
    }
  }

  /// 解析 RSS XML
  List<RssItem> _parseXml(String xmlString, RssSource source) {
    final document = XmlDocument.parse(xmlString);
    final items = <RssItem>[];

    // 支持 RSS 2.0 和 Atom 格式
    final rssItems = document.findAllElements('item');
    for (final item in rssItems) {
      final guid = item.findElements('guid').firstOrNull?.innerText ??
                   item.findElements('link').firstOrNull?.innerText ??
                   '';
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText;
      final category = item.findElements('category').firstOrNull?.innerText;
      final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText;

      DateTime? pubDate;
      if (pubDateStr != null) {
        pubDate = DateTime.tryParse(pubDateStr);
        // 处理 RFC 2822 格式
        pubDate ??= _parseRfc2822(pubDateStr);
      }

      items.add(RssItem(
        guid: guid,
        title: title,
        link: link,
        category: category,
        pubDate: pubDate ?? DateTime.now(),
      ));
    }

    // 也尝试 Atom 格式
    if (items.isEmpty) {
      final atomEntries = document.findAllElements('entry');
      for (final entry in atomEntries) {
        final id = entry.findElements('id').firstOrNull?.innerText ?? '';
        final title = entry.findElements('title').firstOrNull?.innerText ?? '';
        final link = entry.findElements('link').firstOrNull?.getAttribute('href');
        final category = entry.findElements('category').firstOrNull?.getAttribute('term');
        final published = entry.findElements('published').firstOrNull?.innerText;

        items.add(RssItem(
          guid: id,
          title: title,
          link: link,
          category: category,
          pubDate: published != null ? DateTime.tryParse(published) ?? DateTime.now() : DateTime.now(),
        ));
      }
    }

    return items;
  }

  DateTime? _parseRfc2822(String input) {
    try {
      // 处理 "Thu, 01 Jun 2026 12:00:00 +0000" 格式
      final cleaned = input.replaceAll(RegExp(r'\s+'), ' ').trim();
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final parts = cleaned.split(' ');
      if (parts.length < 5) return null;

      final day = int.tryParse(parts[1]) ?? 1;
      final month = months[parts[2]] ?? 1;
      final year = int.tryParse(parts[3]) ?? DateTime.now().year;

      final timeParts = parts[4].split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// 根据过滤正则检查标题是否匹配
  bool matchesFilter(String title, String? regex) {
    if (regex == null || regex.isEmpty) return true;
    try {
      return RegExp(regex, caseSensitive: false).hasMatch(title);
    } catch (_) {
      return true; // 正则无效时默认通过
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/rss_service.dart
git commit -m "feat: add RSS feed fetching and parsing service"
```

---

## Phase 3: 状态管理 (Provider)

### Task 10: ClientProvider

**Files:**
- Create: `lib/providers/client_provider.dart`

- [ ] **Step 1: 创建客户端配置 Provider**

```dart
// lib/providers/client_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_config.dart';
import '../services/service_factory.dart';
import '../utils/storage.dart';

class ClientProvider extends ChangeNotifier {
  List<ClientConfig> _clients = [];
  final Map<String, bool> _onlineStatus = {}; // clientId → online
  final Map<String, String> _errorMessages = {};
  bool _loading = false;

  List<ClientConfig> get clients => List.unmodifiable(_clients);
  List<ClientConfig> get activeClients => _clients.where((c) => c.isActive).toList();
  Map<String, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);
  Map<String, String> get errorMessages => Map.unmodifiable(_errorMessages);
  bool get loading => _loading;

  /// 从本地存储加载客户端配置
  Future<void> loadClients() async {
    _loading = true;
    notifyListeners();

    try {
      final storage = await LocalStorage.getInstance();
      final rawList = await storage.getJsonList('clients');
      _clients = rawList.map((json) => ClientConfig.fromJson(json)).toList();

      // 恢复密码
      for (final client in _clients) {
        final pwd = await storage.getPassword(client.id);
        if (pwd != null) {
          client.password = pwd;
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 持久化客户端配置
  Future<void> _saveClients() async {
    final storage = await LocalStorage.getInstance();
    final jsonList = _clients.map((c) {
      final json = c.toJson();
      // 单独存密码
      if (c.password != null) {
        storage.savePassword(c.id, c.password!);
      }
      json.remove('password');
      return json;
    }).toList();
    await storage.saveJsonList('clients', jsonList);
  }

  /// 添加客户端
  Future<void> addClient(ClientConfig config) async {
    _clients.add(config);
    await _saveClients();
    notifyListeners();
  }

  /// 更新客户端
  Future<void> updateClient(String id, ClientConfig updated) async {
    final index = _clients.indexWhere((c) => c.id == id);
    if (index != -1) {
      _clients[index] = updated;
      await _saveClients();
      notifyListeners();
    }
  }

  /// 删除客户端
  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    _onlineStatus.remove(id);
    _errorMessages.remove(id);
    final storage = await LocalStorage.getInstance();
    await storage.deletePassword(id);
    await _saveClients();
    notifyListeners();
  }

  /// 测试连接
  Future<bool> testConnection(ClientConfig config) async {
    try {
      final service = ServiceFactory.getService(config.type);
      final ok = await service.testConnection(config);
      if (ok) {
        _onlineStatus[config.id] = true;
        _errorMessages.remove(config.id);
      } else {
        _onlineStatus[config.id] = false;
        _errorMessages[config.id] = 'Connection failed';
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _onlineStatus[config.id] = false;
      _errorMessages[config.id] = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 刷新所有在线状态
  Future<void> refreshAllStatus() async {
    for (final client in _clients) {
      if (client.isActive) {
        await testConnection(client);
      }
    }
  }

  bool isOnline(String clientId) => _onlineStatus[clientId] ?? false;
  String? getError(String clientId) => _errorMessages[clientId];
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/providers/client_provider.dart
git commit -m "feat: add ClientProvider for client config management"
```

---

### Task 11: TorrentProvider

**Files:**
- Create: `lib/providers/torrent_provider.dart`

- [ ] **Step 1: 创建种子管理 Provider**

```dart
// lib/providers/torrent_provider.dart
import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../services/service_factory.dart';

class TorrentProvider extends ChangeNotifier {
  List<Torrent> _allTorrents = [];
  String _searchQuery = '';
  TorrentState? _stateFilter;
  String? _clientFilter;
  bool _loading = false;
  String? _error;
  bool _selectMode = false;
  final Set<String> _selectedHashes = {};

  List<Torrent> get allTorrents => List.unmodifiable(_allTorrents);

  /// 根据筛选条件过滤后的种子列表
  List<Torrent> get filteredTorrents {
    var result = _allTorrents;

    // 状态筛选
    if (_stateFilter != null) {
      result = result.where((t) => t.state == _stateFilter).toList();
    }

    // 客户端筛选
    if (_clientFilter != null) {
      result = result.where((t) => t.clientId == _clientFilter).toList();
    }

    // 搜索
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((t) => t.name.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  String get searchQuery => _searchQuery;
  TorrentState? get stateFilter => _stateFilter;
  String? get clientFilter => _clientFilter;
  bool get loading => _loading;
  String? get error => _error;
  bool get selectMode => _selectMode;
  Set<String> get selectedHashes => Set.unmodifiable(_selectedHashes);
  int get selectedCount => _selectedHashes.length;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStateFilter(TorrentState? state) {
    _stateFilter = state;
    notifyListeners();
  }

  void setClientFilter(String? clientId) {
    _clientFilter = clientId;
    notifyListeners();
  }

  // ---- 批量选择模式 ----

  void enterSelectMode() {
    _selectMode = true;
    notifyListeners();
  }

  void exitSelectMode() {
    _selectMode = false;
    _selectedHashes.clear();
    notifyListeners();
  }

  void toggleSelection(String hash) {
    if (_selectedHashes.contains(hash)) {
      _selectedHashes.remove(hash);
    } else {
      _selectedHashes.add(hash);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedHashes.addAll(filteredTorrents.map((t) => t.hash));
    notifyListeners();
  }

  void clearSelection() {
    _selectedHashes.clear();
    notifyListeners();
  }

  // ---- 数据刷新 ----

  /// 从所有活跃客户端获取种子列表
  Future<void> refreshTorrents(List<ClientConfig> activeClients) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final allTorrents = <Torrent>[];
      for (final client in activeClients) {
        try {
          final service = ServiceFactory.getService(client.type);
          final torrents = await service.getTorrents(client);
          allTorrents.addAll(torrents);
        } catch (e) {
          // 单个客户端失败不影响其他客户端
          debugPrint('Error fetching torrents from ${client.name}: $e');
        }
      }
      _allTorrents = allTorrents;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---- 种子操作 ----

  Future<bool> pauseTorrents(ClientConfig client, List<String> hashes) async {
    try {
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.pauseTorrent(client, hash);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> resumeTorrents(ClientConfig client, List<String> hashes) async {
    try {
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.resumeTorrent(client, hash);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTorrents(ClientConfig client, List<String> hashes, {bool deleteFiles = false}) async {
    try {
      final service = ServiceFactory.getService(client.type);
      for (final hash in hashes) {
        await service.deleteTorrent(client, hash, deleteFiles: deleteFiles);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> replaceTracker(ClientConfig client, String hash, String oldUrl, String newUrl) async {
    try {
      final service = ServiceFactory.getService(client.type);
      await service.replaceTracker(client, hash, oldUrl, newUrl);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/providers/torrent_provider.dart
git commit -m "feat: add TorrentProvider with filtering and batch ops"
```

---

### Task 12: StatsProvider

**Files:**
- Create: `lib/providers/stats_provider.dart`

- [ ] **Step 1: 创建统计 Provider**

```dart
// lib/providers/stats_provider.dart
import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../services/service_factory.dart';

class StatsProvider extends ChangeNotifier {
  GlobalStats _globalStats = GlobalStats();
  bool _loading = false;
  String? _error;

  GlobalStats get globalStats => _globalStats;
  bool get loading => _loading;
  String? get error => _error;

  /// 从所有活跃客户端汇总统计数据
  Future<void> refreshStats(
    List<ClientConfig> activeClients,
    List<Torrent> allTorrents,
    Map<String, bool> onlineStatus,
  ) async {
    _loading = true;
    notifyListeners();

    try {
      int downloadSpeed = 0;
      int uploadSpeed = 0;
      int totalDownloaded = 0;
      int totalUploaded = 0;
      int totalSize = 0;
      final clientStatsList = <ClientStats>[];

      for (final client in activeClients) {
        final online = onlineStatus[client.id] ?? false;
        int clientDl = 0;
        int clientUl = 0;
        int clientSize = 0;

        if (online) {
          try {
            final service = ServiceFactory.getService(client.type);
            final stats = await service.getStats(client);
            clientDl = stats.downloadSpeed;
            clientUl = stats.uploadSpeed;
          } catch (_) {
            // fallback to client-level stats from torrents
          }
        }

        // 从种子列表汇总补充
        final clientTorrents = allTorrents.where((t) => t.clientId == client.id);
        for (final t in clientTorrents) {
          clientSize += t.totalSize;
          if (!online) {
            clientDl += t.downloadSpeed;
            clientUl += t.uploadSpeed;
          }
        }

        downloadSpeed += clientDl;
        uploadSpeed += clientUl;
        totalDownloaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.downloaded);
        totalUploaded += clientTorrents.fold<int>(0, (sum, t) => sum + t.uploaded);
        totalSize += clientSize;

        clientStatsList.add(ClientStats(
          clientId: client.id,
          clientName: client.name,
          type: client.type,
          online: online,
          torrentCount: clientTorrents.length,
          downloadSpeed: clientDl,
          uploadSpeed: clientUl,
          sizeOnDisk: clientSize,
        ));
      }

      _globalStats = GlobalStats(
        totalTorrents: allTorrents.length,
        activeTorrents: allTorrents.where((t) => t.isActive).length,
        downloadingCount: allTorrents.where((t) => t.isDownloading).length,
        seedingCount: allTorrents.where((t) => t.isSeeding).length,
        pausedCount: allTorrents.where((t) => t.isPaused).length,
        errorCount: allTorrents.where((t) => t.isError).length,
        downloadSpeed: downloadSpeed,
        uploadSpeed: uploadSpeed,
        totalDownloaded: totalDownloaded,
        totalUploaded: totalUploaded,
        totalSizeOnDisk: totalSize,
        clientStatsList: clientStatsList,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/providers/stats_provider.dart
git commit -m "feat: add StatsProvider for global statistics aggregation"
```

---

### Task 13: RssProvider

**Files:**
- Create: `lib/providers/rss_provider.dart`

- [ ] **Step 1: 创建 RSS 管理 Provider**

```dart
// lib/providers/rss_provider.dart
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/client_config.dart';
import '../models/rss_source.dart';
import '../services/rss_service.dart';
import '../services/service_factory.dart';
import '../utils/storage.dart';

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  Map<String, List<RssItem>> _itemsCache = {};
  Set<String> _downloadedGuids = {};
  bool _loading = false;
  String? _error;

  List<RssSource> get sources => List.unmodifiable(_sources);
  bool get loading => _loading;
  String? get error => _error;

  /// 获取某个 RSS 源的条目缓存
  List<RssItem> getItems(String sourceId) => _itemsCache[sourceId] ?? [];

  // ---- 持久化 ----

  Future<void> loadSources() async {
    _loading = true;
    notifyListeners();

    try {
      final storage = await LocalStorage.getInstance();
      final rawList = await storage.getJsonList('rss_sources');
      _sources = rawList.map((json) => RssSource.fromJson(json)).toList();

      final downloadedRaw = await storage.getString('rss_downloaded_guids');
      if (downloadedRaw != null) {
        final list = downloadedRaw.split(',').where((s) => s.isNotEmpty);
        _downloadedGuids = list.toSet();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSources() async {
    final storage = await LocalStorage.getInstance();
    await storage.saveJsonList('rss_sources', _sources.map((s) => s.toJson()).toList());
  }

  Future<void> _saveDownloadedGuids() async {
    final storage = await LocalStorage.getInstance();
    await storage.setString('rss_downloaded_guids', _downloadedGuids.join(','));
  }

  // ---- CRUD ----

  Future<void> addSource(RssSource source) async {
    _sources.add(source);
    await _saveSources();
    notifyListeners();
  }

  Future<void> updateSource(String id, RssSource updated) async {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sources[index] = updated;
      await _saveSources();
      notifyListeners();
    }
  }

  Future<void> deleteSource(String id) async {
    _sources.removeWhere((s) => s.id == id);
    _itemsCache.remove(id);
    await _saveSources();
    notifyListeners();
  }

  // ---- 获取条目 ----

  Future<List<RssItem>> fetchItems(String sourceId, {List<ClientConfig>? clients}) async {
    final source = _sources.firstWhere((s) => s.id == sourceId);
    final rssService = RssService();

    try {
      final items = await rssService.fetchItems(source);

      // 标记已存在的（跨客户端查重）
      if (clients != null && clients.isNotEmpty) {
        for (final item in items) {
          // 已下载过的标记
          if (_downloadedGuids.contains(item.guid)) {
            item.isDownloaded = true;
          }

          // 跨客户端查重（通过磁力链接中的 hash 或链接特征）
          if (item.link != null && item.link!.startsWith('magnet:')) {
            for (final client in clients) {
              try {
                final service = ServiceFactory.getService(client.type);
                final torrents = await service.getTorrents(client);
                // 简单判断：根据链接或标题模糊匹配
                final exists = torrents.any((t) =>
                    t.name == item.title ||
                    (item.link!.contains(t.hash)));
                if (exists) {
                  item.isDuplicate = true;
                  break;
                }
              } catch (_) {}
            }
          }
        }
      }

      // 更新最后获取时间
      source.lastFetchedAt = DateTime.now();
      await _saveSources();

      _itemsCache[sourceId] = items;
      notifyListeners();
      return items;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ---- 自动下载 ----

  /// 检查并执行所有开启了自动下载的 RSS 源
  Future<void> processAutoDownloads(List<ClientConfig> clients) async {
    final rssService = RssService();

    for (final source in _sources) {
      if (!source.autoDownload || source.assignedClientId == null) continue;

      final targetClient = clients.where((c) => c.id == source.assignedClientId).firstOrNull;
      if (targetClient == null || !(true)) continue; // online check done outside

      try {
        final items = await rssService.fetchItems(source);
        for (final item in items) {
          // 自动下载条件判断
          if (_downloadedGuids.contains(item.guid)) continue;
          if (item.link == null) continue;
          if (!rssService.matchesFilter(item.title, source.filterRegex)) continue;

          // 查重
          final service = ServiceFactory.getService(targetClient.type);
          final torrents = await service.getTorrents(targetClient);
          final exists = torrents.any((t) => t.name == item.title);
          if (exists) continue;

          // 推送到客户端
          try {
            await service.addTorrentFromUrl(targetClient, url: item.link!, savePath: source.savePath);
            _downloadedGuids.add(item.guid);
            await _saveDownloadedGuids();
          } catch (e) {
            debugPrint('Auto-download failed for ${item.title}: $e');
          }
        }
      } catch (e) {
        debugPrint('RSS auto-download error for ${source.name}: $e');
      }
    }
  }

  /// 手动下载 RSS 条目
  Future<bool> downloadItem(String link, ClientConfig client, {String? savePath}) async {
    try {
      final service = ServiceFactory.getService(client.type);
      await service.addTorrentFromUrl(client, url: link, savePath: savePath);
      // 记录 guid（如果有）
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 标记 guid 为已下载
  Future<void> markDownloaded(String guid) async {
    _downloadedGuids.add(guid);
    await _saveDownloadedGuids();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/providers/rss_provider.dart
git commit -m "feat: add RssProvider with auto-download logic"
```

---

### Task 14: 刷新服务（定时轮询）

**Files:**
- Create: `lib/services/refresh_service.dart`

- [ ] **Step 1: 创建定时刷新服务**

```dart
// lib/services/refresh_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../providers/client_provider.dart';
import '../providers/torrent_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/rss_provider.dart';
import '../utils/constants.dart';

class RefreshService {
  Timer? _pollTimer;
  Timer? _rssTimer;
  final ClientProvider clientProvider;
  final TorrentProvider torrentProvider;
  final StatsProvider statsProvider;
  final RssProvider rssProvider;
  bool _isRunning = false;

  RefreshService({
    required this.clientProvider,
    required this.torrentProvider,
    required this.statsProvider,
    required this.rssProvider,
  });

  bool get isRunning => _isRunning;

  /// 启动轮询
  void start() {
    if (_isRunning) return;
    _isRunning = true;

    // 种子 + 统计轮询（3秒间隔）
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConstants.defaultPollIntervalSeconds),
      (_) => _pollAll(),
    );

    // RSS 定时刷新（按最短间隔15分钟）
    _rssTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkRssRefresh(),
    );

    // 首次立即刷新
    _pollAll();
    _checkRssRefresh();
  }

  /// 停止轮询
  void stop() {
    _isRunning = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _rssTimer?.cancel();
    _rssTimer = null;
  }

  /// 手动强制刷新全部
  Future<void> refreshNow() async {
    await _pollAll();
    await _checkRssRefresh();
  }

  Future<void> _pollAll() async {
    final activeClients = clientProvider.activeClients;
    if (activeClients.isEmpty) return;

    // 刷新种子列表
    await torrentProvider.refreshTorrents(activeClients);

    // 刷新统计
    await statsProvider.refreshStats(
      activeClients,
      torrentProvider.allTorrents,
      clientProvider.onlineStatus,
    );
  }

  Future<void> _checkRssRefresh() async {
    final now = DateTime.now();
    for (final source in rssProvider.sources) {
      if (!source.autoDownload) continue;
      final lastFetched = source.lastFetchedAt;
      if (lastFetched != null) {
        final diff = now.difference(lastFetched).inMinutes;
        if (diff < source.refreshIntervalMinutes) continue;
      }

      // 执行自动下载处理
      await rssProvider.processAutoDownloads(clientProvider.activeClients);
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/services/refresh_service.dart
git commit -m "feat: add refresh service for periodic polling"
```

---

## Phase 4: UI 界面

### Task 15: App 入口 + 路由 + 主题

**Files:**
- Create: `lib/screens/home_screen.dart`（骨架）
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 创建 App 入口**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/client_provider.dart';
import 'providers/torrent_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/rss_provider.dart';

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
        ChangeNotifierProvider(create: (_) => RssProvider()),
      ],
      child: const AppShell(),
    );
  }
}
```

- [ ] **Step 2: 创建 App Shell（底部导航+路由）**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/client_provider.dart';
import 'providers/rss_provider.dart';
import 'services/refresh_service.dart';
import 'screens/home_screen.dart';
import 'screens/rss_sources_screen.dart';
import 'screens/torrent_list_screen.dart';
import 'screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  RefreshService? _refreshService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final clientProvider = context.read<ClientProvider>();
    final rssProvider = context.read<RssProvider>();

    await clientProvider.loadClients();
    await rssProvider.loadSources();

    // 启动刷新服务
    _refreshService = RefreshService(
      clientProvider: clientProvider,
      torrentProvider: context.read<TorrentProvider>(),
      statsProvider: context.read<StatsProvider>(),
      rssProvider: rssProvider,
    );
    _refreshService!.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshService?.start();
      _refreshService?.refreshNow();
    } else if (state == AppLifecycleState.paused) {
      _refreshService?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bit Manager',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            RssSourcesScreen(),
            TorrentListScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '概览'),
            NavigationDestination(icon: Icon(Icons.rss_feed_outlined), selectedIcon: Icon(Icons.rss_feed), label: 'RSS'),
            NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: '种子'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 首页骨架（简单占位）**

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/stats_card.dart';
import '../widgets/client_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bit Manager'),
        centerTitle: true,
      ),
      body: Consumer2<StatsProvider, ClientProvider>(
        builder: (context, stats, clients, _) {
          if (clients.clients.isEmpty) {
            return _buildEmptyState(context);
          }

          final globalStats = stats.globalStats;
          return RefreshIndicator(
            onRefresh: () async {
              // 触发刷新
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 全局速度卡片
                Row(
                  children: [
                    Expanded(child: StatsCard(
                      icon: Icons.download,
                      label: '下载',
                      value: '${(globalStats.downloadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                      color: Colors.green,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatsCard(
                      icon: Icons.upload,
                      label: '上传',
                      value: '${(globalStats.uploadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                      color: Colors.blue,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatsCard(
                      icon: Icons.downloading,
                      label: '活动种子',
                      value: '${globalStats.activeTorrents} / ${globalStats.totalTorrents}',
                      color: Colors.orange,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatsCard(
                      icon: Icons.storage,
                      label: '磁盘占用',
                      value: '${(globalStats.totalSizeOnDisk / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                      color: Colors.purple,
                    )),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('客户端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...globalStats.clientStatsList.map((cs) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClientTile(stats: cs),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('还没有添加客户端', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // 导航到设置页
            },
            child: const Text('添加第一个客户端'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/main.dart lib/app.dart lib/screens/home_screen.dart
git commit -m "feat: add app shell with navigation and theme"
```

---

### Task 16: 可复用 Widgets

**Files:**
- Create: `lib/widgets/stats_card.dart`
- Create: `lib/widgets/client_tile.dart`
- Create: `lib/widgets/torrent_tile.dart`
- Create: `lib/widgets/rss_source_tile.dart`
- Create: `lib/widgets/rss_item_tile.dart`
- Create: `lib/widgets/status_chip.dart`
- Create: `lib/widgets/empty_state.dart`

- [ ] **Step 1: StatsCard**

```dart
// lib/widgets/stats_card.dart
import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatsCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: ClientTile**

```dart
// lib/widgets/client_tile.dart
import 'package:flutter/material.dart';
import '../models/stats.dart';

class ClientTile extends StatelessWidget {
  final ClientStats stats;

  const ClientTile({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stats.online ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
          child: Icon(
            stats.type == ClientType.qBittorrent ? Icons.download : Icons.wifi,
            color: stats.online ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(stats.clientName),
        subtitle: Text(
          '⬇ ${_formatSpeed(stats.downloadSpeed)}  ⬆ ${_formatSpeed(stats.uploadSpeed)}  ·  ${stats.torrentCount} 个种子',
        ),
        trailing: stats.online
            ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
            : const Icon(Icons.error_outline, color: Colors.red, size: 18),
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
}
```

- [ ] **Step 3: StatusChip**

```dart
// lib/widgets/status_chip.dart
import 'package:flutter/material.dart';
import '../models/torrent.dart';

class StatusChip extends StatelessWidget {
  final TorrentState state;

  const StatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (state) {
      TorrentState.downloading => (Colors.blue, '下载中'),
      TorrentState.metaDL      => (Colors.lightBlue, '获取元数据'),
      TorrentState.seeding     => (Colors.green, '做种中'),
      TorrentState.paused      => (Colors.orange, '已暂停'),
      TorrentState.checking    => (Colors.purple, '校验中'),
      TorrentState.queued      => (Colors.grey, '队列中'),
      TorrentState.error       => (Colors.red, '出错'),
      TorrentState.unknown     => (Colors.grey, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
```

- [ ] **Step 4: TorrentTile**

```dart
// lib/widgets/torrent_tile.dart
import 'package:flutter/material.dart';
import '../models/torrent.dart';
import 'status_chip.dart';

class TorrentTile extends StatelessWidget {
  final Torrent torrent;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TorrentTile({
    super.key,
    required this.torrent,
    this.isSelected = false,
    this.selectMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(torrent.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        StatusChip(state: torrent.state),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (torrent.totalSize > 0) ...[
                      Row(
                        children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: torrent.progress, minHeight: 4),
                          )),
                          const SizedBox(width: 8),
                          Text('${(torrent.progress * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (torrent.downloadSpeed > 0)
                          Text('⬇ ${_format(torrent.downloadSpeed)}', style: TextStyle(fontSize: 12, color: Colors.green[600])),
                        if (torrent.downloadSpeed > 0 && torrent.uploadSpeed > 0) const SizedBox(width: 8),
                        if (torrent.uploadSpeed > 0)
                          Text('⬆ ${_format(torrent.uploadSpeed)}', style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                        const Spacer(),
                        Text('S: ${torrent.seedsConnected}  P: ${torrent.peersConnected}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int bytes) {
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
  }
}
```

- [ ] **Step 5: RssSourceTile 和 RssItemTile**

```dart
// lib/widgets/rss_source_tile.dart
import 'package:flutter/material.dart';
import '../models/rss_source.dart';

class RssSourceTile extends StatelessWidget {
  final RssSource source;
  final VoidCallback? onTap;

  const RssSourceTile({super.key, required this.source, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.rss_feed, color: Colors.orange),
      title: Text(source.name),
      subtitle: Text(source.url, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (source.autoDownload)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('自动', style: TextStyle(fontSize: 11, color: Colors.green)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
```

```dart
// lib/widgets/rss_item_tile.dart
import 'package:flutter/material.dart';
import '../models/rss_source.dart';

class RssItemTile extends StatelessWidget {
  final RssItem item;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback? onTap;

  const RssItemTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.selectMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = item.isDuplicate || item.isDownloaded;

    return ListTile(
      leading: selectMode
          ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank)
          : const Icon(Icons.article_outlined),
      title: Text(
        item.title,
        style: TextStyle(
          color: isDisabled ? Colors.grey : null,
          decoration: isDisabled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${item.pubDate.toString().substring(0, 16)}${item.isDuplicate ? '  ·  已存在' : ''}${item.isDownloaded ? '  ·  已下载' : ''}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      enabled: !isDisabled,
      onTap: isDisabled ? null : onTap,
    );
  }
}
```

- [ ] **Step 6: EmptyState**

```dart
// lib/widgets/empty_state.dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: 提交**

```bash
git add lib/widgets/
git commit -m "feat: add reusable widgets (stats, torrent, rss, empty state)"
```

---

### Task 17: 客户端管理页面

**Files:**
- Create: `lib/screens/client_list_screen.dart`
- Create: `lib/screens/client_form_screen.dart`

- [ ] **Step 1: 客户端列表（内嵌在设置页）**

```dart
// lib/screens/client_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';
import 'client_form_screen.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客户端管理')),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          if (provider.clients.isEmpty) {
            return const Center(child: Text('还没有添加客户端'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.clients.length,
            itemBuilder: (context, index) {
              final client = provider.clients[index];
              final online = provider.isOnline(client.id);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: online ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(
                      client.type == ClientType.qBittorrent ? Icons.download : Icons.wifi,
                      color: online ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(client.name),
                  subtitle: Text('${client.host}:${client.port}\n${client.type == ClientType.qBittorrent ? "qBittorrent" : "Transmission"}'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: const Text('编辑')),
                      PopupMenuItem(value: 'test', child: const Text('测试连接')),
                      PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red[700]))),
                    ],
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ClientFormScreen(client: client),
                          ));
                        case 'test':
                          final ok = await provider.testConnection(client);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? '连接成功' : '连接失败')),
                            );
                          }
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除客户端'),
                              content: Text('确定要删除 "${client.name}" 吗？'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteClient(client.id);
                          }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen())),
      ),
    );
  }
}
```

- [ ] **Step 2: 客户端表单**

```dart
// lib/screens/client_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';

class ClientFormScreen extends StatefulWidget {
  final ClientConfig? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late ClientType _type;
  late bool _useSsl;

  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _hostCtrl = TextEditingController(text: c?.host ?? '');
    _portCtrl = TextEditingController(text: c?.port.toString() ?? (c?.type == ClientType.qBittorrent ? '8080' : '9091'));
    _usernameCtrl = TextEditingController(text: c?.username ?? '');
    _passwordCtrl = TextEditingController(text: c?.password ?? '');
    _type = c?.type ?? ClientType.qBittorrent;
    _useSsl = c?.useSsl ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑客户端' : '添加客户端')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称', hintText: '例如: NAS-4T'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<ClientType>(
              segments: const [
                ButtonSegment(value: ClientType.qBittorrent, label: Text('qBittorrent')),
                ButtonSegment(value: ClientType.transmission, label: Text('Transmission')),
              ],
              selected: {_type},
              onSelectionChanged: (v) {
                setState(() {
                  _type = v.first;
                  if (!isEditing) {
                    _portCtrl.text = _type == ClientType.qBittorrent ? '8080' : '9091';
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostCtrl,
              decoration: const InputDecoration(labelText: '地址', hintText: 'IP 或域名'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入地址' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portCtrl,
              decoration: const InputDecoration(labelText: '端口'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入端口';
                final port = int.tryParse(v);
                if (port == null || port < 1 || port > 65535) return '无效端口';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('使用 HTTPS'),
              value: _useSsl,
              onChanged: (v) => setState(() => _useSsl = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: '用户名（可选）'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(labelText: '密码${_type == ClientType.qBittorrent ? '' : '（可选）'}'),
              obscureText: true,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClientProvider>();
    final config = ClientConfig(
      id: widget.client?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      useSsl: _useSsl,
    );

    if (isEditing) {
      await provider.updateClient(widget.client!.id, config);
    } else {
      await provider.addClient(config);
    }

    if (context.mounted) Navigator.pop(context);
  }
}
```

- [ ] **Step 3: 提交**

```bash
git add lib/screens/client_list_screen.dart lib/screens/client_form_screen.dart
git commit -m "feat: add client management screens (list + form)"
```

---

### Task 18: RSS 相关页面

**Files:**
- Create: `lib/screens/rss_sources_screen.dart`
- Create: `lib/screens/rss_source_form_screen.dart`
- Create: `lib/screens/rss_items_screen.dart`

- [ ] **Step 1: RSS 源列表**

```dart
// lib/screens/rss_sources_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rss_provider.dart';
import '../widgets/rss_source_tile.dart';
import 'rss_source_form_screen.dart';
import 'rss_items_screen.dart';

class RssSourcesScreen extends StatelessWidget {
  const RssSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSS 订阅')),
      body: Consumer<RssProvider>(
        builder: (context, provider, _) {
          if (provider.sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rss_feed, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('还没有添加 RSS 订阅源', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // 刷新所有 RSS 源
            },
            child: ListView.builder(
              itemCount: provider.sources.length,
              itemBuilder: (context, index) {
                final source = provider.sources[index];
                return RssSourceTile(
                  source: source,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RssItemsScreen(source: source),
                  )),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RssSourceFormScreen())),
      ),
    );
  }
}
```

- [ ] **Step 2: RSS 源表单**

```dart
// lib/screens/rss_source_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/rss_source.dart';
import '../providers/rss_provider.dart';
import '../providers/client_provider.dart';

class RssSourceFormScreen extends StatefulWidget {
  final RssSource? source;
  const RssSourceFormScreen({super.key, this.source});

  @override
  State<RssSourceFormScreen> createState() => _RssSourceFormScreenState();
}

class _RssSourceFormScreenState extends State<RssSourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _filterCtrl;
  late bool _autoDownload;
  late String? _assignedClientId;
  late int _refreshInterval;

  bool get isEditing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _urlCtrl = TextEditingController(text: s?.url ?? '');
    _filterCtrl = TextEditingController(text: s?.filterRegex ?? '');
    _autoDownload = s?.autoDownload ?? false;
    _assignedClientId = s?.assignedClientId;
    _refreshInterval = s?.refreshIntervalMinutes ?? 15;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑订阅源' : '添加订阅源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称', hintText: '例如: 动漫花园'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'RSS 地址'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入 RSS 地址' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _filterCtrl,
              decoration: const InputDecoration(
                labelText: '过滤规则（可选）',
                hintText: '例如: 1080p|4K.*CHS',
                helperText: '正则表达式，匹配标题',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('自动下载'),
              subtitle: const Text('匹配规则后自动添加到客户端'),
              value: _autoDownload,
              onChanged: (v) => setState(() => _autoDownload = v),
            ),
            if (_autoDownload) ...[
              const SizedBox(height: 8),
              Consumer<ClientProvider>(
                builder: (context, cp, _) => DropdownButtonFormField<String>(
                  value: _assignedClientId,
                  decoration: const InputDecoration(labelText: '目标客户端'),
                  items: cp.clients.where((c) => c.isActive).map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.name))
                  ).toList(),
                  onChanged: (v) => _assignedClientId = v,
                  validator: (v) => _autoDownload && v == null ? '请选择客户端' : null,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _refreshInterval,
                decoration: const InputDecoration(labelText: '刷新间隔（分钟）'),
                items: [5, 10, 15, 30, 60].map((m) =>
                  DropdownMenuItem(value: m, child: Text('$m 分钟'))
                ).toList(),
                onChanged: (v) => _refreshInterval = v ?? 15,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RssProvider>();
    final source = RssSource(
      id: widget.source?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      filterRegex: _filterCtrl.text.trim().isEmpty ? null : _filterCtrl.text.trim(),
      autoDownload: _autoDownload,
      assignedClientId: _assignedClientId,
      refreshIntervalMinutes: _refreshInterval,
    );

    if (isEditing) {
      await provider.updateSource(widget.source!.id, source);
    } else {
      await provider.addSource(source);
    }

    if (context.mounted) Navigator.pop(context);
  }
}
```

- [ ] **Step 3: RSS 条目浏览页面**

```dart
// lib/screens/rss_items_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rss_source.dart';
import '../providers/rss_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/rss_item_tile.dart';
import '../widgets/empty_state.dart';

class RssItemsScreen extends StatefulWidget {
  final RssSource source;
  const RssItemsScreen({super.key, required this.source});

  @override
  State<RssItemsScreen> createState() => _RssItemsScreenState();
}

class _RssItemsScreenState extends State<RssItemsScreen> {
  bool _loading = false;
  final Set<String> _selectedGuids = {};
  bool _selectMode = false;
  bool _loadingDownload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final provider = context.read<RssProvider>();
    await provider.fetchItems(widget.source.id, clients: context.read<ClientProvider>().activeClients);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final rssProvider = context.watch<RssProvider>();
    final items = rssProvider.getItems(widget.source.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.source.name),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              icon: Icon(_selectMode ? Icons.close : Icons.checklist),
              onPressed: () => setState(() {
                _selectMode = !_selectMode;
                if (!_selectMode) _selectedGuids.clear();
              }),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const EmptyState(icon: Icons.rss_feed, title: '暂无条目')
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return RssItemTile(
                        item: item,
                        isSelected: _selectedGuids.contains(item.guid),
                        selectMode: _selectMode,
                        onTap: () {
                          if (_selectMode) {
                            setState(() {
                              if (_selectedGuids.contains(item.guid)) {
                                _selectedGuids.remove(item.guid);
                              } else {
                                _selectedGuids.add(item.guid);
                              }
                            });
                          } else if (item.link != null && !item.isDuplicate && !item.isDownloaded) {
                            _showDownloadDialog(item);
                          }
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: _selectMode && _selectedGuids.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _loadingDownload ? null : _batchDownload,
              label: _loadingDownload
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('下载 (${_selectedGuids.length})'),
            )
          : null,
    );
  }

  void _showDownloadDialog(RssItem item) {
    final clients = context.read<ClientProvider>().activeClients;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有可用的客户端')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('下载到...', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...clients.map((client) => ListTile(
            leading: Icon(client.type == ClientType.qBittorrent ? Icons.download : Icons.wifi),
            title: Text(client.name),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await context.read<RssProvider>().downloadItem(item.link!, client);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? '已添加到 ${client.name}' : '下载失败')),
                );
              }
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _batchDownload() async {
    final items = context.read<RssProvider>().getItems(widget.source.id);
    final selectedItems = items.where((i) => _selectedGuids.contains(i.guid) && i.link != null).toList();
    if (selectedItems.isEmpty) return;

    final clients = context.read<ClientProvider>().activeClients;
    if (clients.isEmpty) return;

    // 选择目标客户端
    if (!context.mounted) return;
    final client = await showModalBottomSheet<ClientConfig>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('选择目标客户端', style: Theme.of(context).textTheme.titleMedium),
          ),
          ...clients.map((c) => ListTile(
            leading: Icon(c.type == ClientType.qBittorrent ? Icons.download : Icons.wifi),
            title: Text(c.name),
            onTap: () => Navigator.pop(ctx, c),
          )),
        ],
      ),
    );

    if (client == null) return;

    setState(() => _loadingDownload = true);
    final rssProvider = context.read<RssProvider>();
    for (final item in selectedItems) {
      await rssProvider.downloadItem(item.link!, client);
      await rssProvider.markDownloaded(item.guid);
    }
    setState(() {
      _loadingDownload = false;
      _selectedGuids.clear();
      _selectMode = false;
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加 ${selectedItems.length} 个种子到 ${client.name}')),
      );
    }
    _fetch();
  }
}
```

- [ ] **Step 4: 提交**

```bash
git add lib/screens/rss_sources_screen.dart lib/screens/rss_source_form_screen.dart lib/screens/rss_items_screen.dart
git commit -m "feat: add RSS management screens"
```

---

### Task 19: 种子列表页面

**Files:**
- Create: `lib/screens/torrent_list_screen.dart`

- [ ] **Step 1: 种子列表（含筛选、搜索、批量操作）**

```dart
// lib/screens/torrent_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/torrent.dart';
import '../providers/torrent_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/torrent_tile.dart';
import '../widgets/empty_state.dart';

class TorrentListScreen extends StatelessWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('种子'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {
            // 展开搜索
          }),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            context.read<TorrentProvider>().refreshTorrents(
              context.read<ClientProvider>().activeClients,
            );
          }),
        ],
      ),
      body: Consumer2<TorrentProvider, ClientProvider>(
        builder: (context, tp, cp, _) {
          if (cp.clients.isEmpty) {
            return const EmptyState(
              icon: Icons.download,
              title: '还没有添加客户端',
              subtitle: '在设置中添加客户端后即可查看种子',
            );
          }

          if (tp.allTorrents.isEmpty && !tp.loading) {
            return const EmptyState(
              icon: Icons.inbox,
              title: '暂无种子',
              subtitle: '通过 RSS 订阅添加种子',
            );
          }

          return Column(
            children: [
              // 筛选栏
              _buildFilterBar(context, tp),
              // 批量模式顶部栏
              if (tp.selectMode) _buildBatchBar(context, tp, cp),
              // 种子列表
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => tp.refreshTorrents(cp.activeClients),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: tp.filteredTorrents.length + (tp.loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == 0 && tp.loading) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final t = tp.filteredTorrents[index];
                      return TorrentTile(
                        torrent: t,
                        selectMode: tp.selectMode,
                        isSelected: tp.selectedHashes.contains(t.hash),
                        onLongPress: () {
                          if (!tp.selectMode) {
                            tp.enterSelectMode();
                            tp.toggleSelection(t.hash);
                          }
                        },
                        onTap: () {
                          if (tp.selectMode) {
                            tp.toggleSelection(t.hash);
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      // 批量操作底部栏（在批量模式且选中时显示）
      floatingActionButton: context.watch<TorrentProvider>().selectMode &&
              context.watch<TorrentProvider>().selectedCount > 0
          ? _buildBatchActions(context)
          : null,
    );
  }

  Widget _buildFilterBar(BuildContext context, TorrentProvider tp) {
    final filters = <TorrentState?>[
      null, // 全部
      TorrentState.downloading,
      TorrentState.seeding,
      TorrentState.paused,
      TorrentState.error,
    ];
    final labels = ['全部', '下载中', '做种中', '已暂停', '出错'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(filters.length, (i) {
          final isSelected = tp.stateFilter == filters[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(labels[i]),
              selected: isSelected,
              onSelected: (_) => tp.setStateFilter(filters[i]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBatchBar(BuildContext context, TorrentProvider tp, ClientProvider cp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text('已选 ${tp.selectedCount} 个'),
          const Spacer(),
          TextButton(onPressed: () => tp.selectAll(), child: const Text('全选')),
          TextButton(onPressed: () => tp.exitSelectMode(), child: const Text('取消')),
        ],
      ),
    );
  }

  Widget? _buildBatchActions(BuildContext context) {
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'resume',
          onPressed: () => _batchAction(context, 'resume'),
          child: const Icon(Icons.play_arrow),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'pause',
          onPressed: () => _batchAction(context, 'pause'),
          child: const Icon(Icons.pause),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'delete',
          onPressed: () => _batchDelete(context),
          child: const Icon(Icons.delete, color: Colors.red),
        ),
      ],
    );
  }

  Future<void> _batchAction(BuildContext context, String action) async {
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final selected = tp.selectedHashes.toList();

    // 按客户端分组执行
    for (final client in cp.activeClients) {
      final clientHashes = tp.allTorrents
          .where((t) => selected.contains(t.hash) && t.clientId == client.id)
          .map((t) => t.hash)
          .toList();
      if (clientHashes.isEmpty) continue;

      bool ok;
      if (action == 'resume') {
        ok = await tp.resumeTorrents(client, clientHashes);
      } else {
        ok = await tp.pauseTorrents(client, clientHashes);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? '操作成功' : '操作失败')),
        );
      }
    }
    tp.exitSelectMode();
  }

  Future<void> _batchDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${context.read<TorrentProvider>().selectedCount} 个种子吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final selected = tp.selectedHashes.toList();

    for (final client in cp.activeClients) {
      final hashes = tp.allTorrents
          .where((t) => selected.contains(t.hash) && t.clientId == client.id)
          .map((t) => t.hash)
          .toList();
      if (hashes.isNotEmpty) {
        await tp.deleteTorrents(client, hashes);
      }
    }
    tp.exitSelectMode();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add lib/screens/torrent_list_screen.dart
git commit -m "feat: add torrent list screen with filtering and batch operations"
```

---

### Task 20: 设置页面

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 创建设置页面**

```dart
// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/rss_provider.dart';
import '../services/refresh_service.dart';
import 'client_list_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 客户端管理入口
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('客户端管理'),
              subtitle: Consumer<ClientProvider>(
                builder: (_, cp, __) => Text('${cp.clients.length} 个客户端'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ClientListScreen(),
              )),
            ),
          ),
          const SizedBox(height: 8),
          // RSS 订阅源管理
          Card(
            child: ListTile(
              leading: const Icon(Icons.rss_feed, color: Colors.orange),
              title: const Text('RSS 订阅源'),
              subtitle: Consumer<RssProvider>(
                builder: (_, rp, __) => Text('${rp.sources.length} 个订阅源'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const RssSourcesScreen(),
              )),
            ),
          ),
          const SizedBox(height: 24),
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

- [ ] **Step 2: 提交**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: add settings screen"
```

---

## Phase 5: 构建验证

### Task 21: 验证构建

- [ ] **Step 1: 运行 Dart 静态分析**

```bash
flutter analyze
```

Expected: 无 error，允许少量 info/hint。

- [ ] **Step 2: 尝试构建 APK**

```bash
flutter build apk --debug
```

Expected: 构建成功，APK 生成在 `build/app/outputs/flutter-apk/`。

- [ ] **Step 3: 提交最终版本**

```bash
git add .
git commit -m "chore: finalize initial implementation"
```

---

## Phase 6: 后续优化清单

第一阶段完成后，可以继续迭代：

1. **种子详情页** — 文件列表、Tracker 列表、速度曲线
2. **连接状态持久化** — 应用重启后自动恢复在线状态
3. **通知推送** — 下载完成/出错时推送
4. **自定义主题** — 更多 Material 3 颜色主题
5. **搜索增强** — 搜索框中实时过滤
6. **排序** — 按名称/进度/速度/添加时间排序
