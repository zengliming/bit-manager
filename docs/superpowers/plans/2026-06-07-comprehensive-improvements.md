# Bit Manager - 综合改进实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 本计划直接执行，不需要子代理。

**Goal:** 修复 5 个问题：中文输入法、详情滚动、筛选交互优化、概览卡片重设计、Transmission 连接

**Architecture:** 各任务独立，按文件维度组织。模型扩展 → 服务接口 → Provider 更新 → UI 更新

**Tech Stack:** Flutter / Dart / Provider / Dio

---

### Task 1: 修复中文输入法无法输入

**Files:**
- Modify: `lib/screens/client_form_screen.dart`

- [ ] **Step 1: 将 ListView 改为 SingleChildScrollView + Column**

```dart
// 修改前
body: Form(
  key: _formKey,
  child: ListView(
    padding: const EdgeInsets.all(16),
    children: [...]

// 修改后
body: Form(
  key: _formKey,
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [...]
    ),
  ),
),
```

- [ ] **Step 2: 给名称输入框加 textInputAction**

```dart
TextFormField(
  controller: _nameCtrl,
  textInputAction: TextInputAction.next,
  decoration: const InputDecoration(labelText: '名称', hintText: '例如: NAS-4T'),
  validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
),
```

### Task 2: 修复种子详情页文件列表滚动

**Files:**
- Modify: `lib/screens/torrent_detail_screen.dart`

- [ ] **Step 1: 文件列表改用 ListView.builder 惰性构建**

```dart
// 在 _buildSection 中，文件列表部分：
: _files!.isEmpty
    ? [Text('无文件信息', ...)]
    : [
        SizedBox(
          height: 400, // 限制最大高度使其可滚动
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _files!.length,
            itemBuilder: (ctx, i) => _fileTile(_files![i]),
          ),
        ),
      ],
```

使用 `shrinkWrap: true` 的 ListView.builder 替代直接 map 生成所有 widget。

### Task 3: 种子列表筛选优化 - 底部抽屉面板

**Files:**
- Modify: `lib/screens/torrent_list_screen.dart`
- Modify: `lib/providers/torrent_provider.dart`

- [ ] **Step 1: TorrentProvider 增加错误筛选和站点筛选支持**

```dart
// 新增字段
bool _errorOnly = false;
String? _siteFilter;

bool get errorOnly => _errorOnly;
String? get siteFilter => _siteFilter;

void setErrorOnly(bool v) { _errorOnly = v; notifyListeners(); }
void setSiteFilter(String? v) { _siteFilter = v; notifyListeners(); }
void clearAllFilters() { _stateFilter = null; _clientFilter = null; _searchQuery = ''; _errorOnly = false; _siteFilter = null; notifyListeners(); }
```

修改 `filteredTorrents` getter 加入新的筛选逻辑。

- [ ] **Step 2: 在 filteredTorrents 中加入错误筛选和站点筛选**

```dart
if (_errorOnly) {
  result = result.where((t) => t.error != null && t.error!.isNotEmpty).toList();
}
if (_siteFilter != null) {
  result = result.where((t) => t.trackers.any((tr) => tr.contains(_siteFilter!))).toList();
}
```

- [ ] **Step 3: AppBar 加筛选图标按钮（带角标）**

```dart
// AppBar actions 中新增
Builder(
  builder: (context) {
    final tp = context.watch<TorrentProvider>();
    final activeCount = [
      if (tp.stateFilter != null) 1,
      if (tp.clientFilter != null) 1,
      if (tp.errorOnly) 1,
      if (tp.siteFilter != null) 1,
    ].length;
    return Badge(
      isLabelVisible: activeCount > 0,
      label: Text('$activeCount'),
      child: IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: () => _showFilterSheet(context),
      ),
    );
  },
),
```

- [ ] **Step 4: 实现底部抽屉筛选面板**

```dart
void _showFilterSheet(BuildContext context) {
  final tp = context.read<TorrentProvider>();
  showModalBottomSheet(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('筛选', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                // 状态组
                Text('状态', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [...状态 chips],
                ),
                const SizedBox(height: 16),
                // 客户端组
                Text('客户端', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [...客户端 chips],
                ),
                const SizedBox(height: 16),
                // 错误过滤
                SwitchListTile(
                  title: const Text('仅显示有错误的种子'),
                  value: tp.errorOnly,
                  onChanged: (v) {
                    tp.setErrorOnly(v);
                    setSheetState(() {});
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        tp.clearAllFilters();
                        setSheetState(() {});
                      },
                      child: const Text('重置'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('应用'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
```

### Task 4: 概览页面客户端卡片重设计

**Files:**
- Modify: `lib/models/stats.dart`
- Modify: `lib/providers/stats_provider.dart`
- Modify: `lib/widgets/client_tile.dart`
- Modify: `lib/services/torrent_client.dart`
- Modify: `lib/services/qbittorrent_service.dart`
- Modify: `lib/services/transmission_service.dart`

- [ ] **Step 1: 扩展 ClientStats 模型**

```dart
class ClientStats {
  // 原有字段
  String clientId;
  String clientName;
  ClientType type;
  bool online;
  int torrentCount;
  int downloadSpeed;
  int uploadSpeed;
  int sizeOnDisk;
  
  // 新增字段
  int downloadingCount;
  int seedingCount;
  int pausedCount;
  int errorCount;
  int checkingCount;
  int waitingCount;
  int downloadLimit;
  int uploadLimit;
  int freeSpace;

  ClientStats({
    required this.clientId,
    required this.clientName,
    required this.type,
    this.online = false,
    this.torrentCount = 0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.sizeOnDisk = 0,
    this.downloadingCount = 0,
    this.seedingCount = 0,
    this.pausedCount = 0,
    this.errorCount = 0,
    this.checkingCount = 0,
    this.waitingCount = 0,
    this.downloadLimit = 0,
    this.uploadLimit = 0,
    this.freeSpace = 0,
  });
}
```

- [ ] **Step 2: 服务接口增加 getFreeSpace 和 getSpeedLimits**

```dart
// torrent_client.dart
abstract class ITorrentClientService {
  // ... 现有方法
  
  /// 获取客户端剩余空间
  Future<int> getFreeSpace(ClientConfig config);
  
  /// 获取客户端速度限制 (返回 [downloadLimit, uploadLimit] 字节/秒, 0=不限速)
  Future<List<int>> getSpeedLimits(ClientConfig config);
}
```

- [ ] **Step 3: qBittorrent 实现 getFreeSpace 和 getSpeedLimits**

```dart
@override
Future<int> getFreeSpace(ClientConfig config) async {
  final sid = await _login(config);
  if (sid == null) throw Exception('Login failed');
  final resp = await _get(config, '/api/v2/sync/maindata', sid: sid);
  final data = resp.data as Map<String, dynamic>;
  final serverState = data['server_state'] as Map<String, dynamic>? ?? {};
  // freeSpaceOnDisk 单位字节
  return (serverState['freeSpaceOnDisk'] as num?)?.toInt() ?? 0;
}

@override
Future<List<int>> getSpeedLimits(ClientConfig config) async {
  final sid = await _login(config);
  if (sid == null) throw Exception('Login failed');
  final resp = await _get(config, '/api/v2/transfer/speedLimitsMode', sid: sid);
  // ... 实现
}
```

- [ ] **Step 4: Transmission 实现 getFreeSpace 和 getSpeedLimits**

- [ ] **Step 5: StatsProvider 中计算各状态计数**

```dart
// 在 refreshStats 中，已经遍历了 clientTorrents，可以计算状态计数
int downloading = 0, seeding = 0, paused = 0, error = 0, checking = 0, waiting = 0;
for (final t in clientTorrents) {
  if (t.isDownloading) downloading++;
  else if (t.isSeeding) seeding++;
  else if (t.isPaused) paused++;
  else if (t.isError) error++;
  else if (t.state == TorrentState.checking) checking++;
  else if (t.state == TorrentState.queued) waiting++;
}

clientStatsList.add(ClientStats(
  // ... 原有字段
  downloadingCount: downloading,
  seedingCount: seeding,
  pausedCount: paused,
  errorCount: error,
  checkingCount: checking,
  waitingCount: waiting,
  downloadLimit: 0,  // 后续 API 调用填充
  uploadLimit: 0,
  freeSpace: 0,
));
```

- [ ] **Step 6: 重写 ClientTile 组件**

显示关键信息的紧凑卡片，布局：
```
┌─────────────────────────────────────┐
│ [状态] 客户端名称                    │
│ ┌───────┬───────┬───────┬───────┐  │
│ │ ↓ 下载 │ ↑ 上传 │ 做种  │ 暂停  │  │
│ │ 1.2MB  │ 340KB  │ 12    │ 3     │  │
│ ├───────┼───────┼───────┼───────┤  │
│ │ 错误   │ 校验  │ 等待  │ 总数  │  │
│ │ 1     │ 0     │ 2     │ 18    │  │
│ └───────┴───────┴───────┴───────┘  │
│ 下载限速: 10MB/s  上传限速: 5MB/s  │
│ 剩余空间: 234.5GB                   │
└─────────────────────────────────────┘
```

### Task 5: 修复 Transmission Session ID 获取

**Files:**
- Modify: `lib/services/transmission_service.dart`

- [ ] **Step 1: 放宽 _getSessionId 的 validateStatus**

```dart
Future<String?> _getSessionId(ClientConfig config) async {
  final dio = HttpClientUtil.instance.createClientDio(config);
  try {
    final resp = await dio.post(
      '${config.baseUrl}${AppConstants.trRpc}',
      data: {'method': 'session-get'},
      options: Options(
        validateStatus: (status) => status != null && status >= 200 && status < 500,
      ),
    );
    // 优先从响应头取 session ID
    final sid = resp.headers.value('x-transmission-session-id');
    if (sid != null) return sid;
    // 如果状态是 200，可能已经成功了，但没有 session ID 返回
    if (resp.statusCode == 200) {
      // 已认证成功，生成一个虚拟 session ID
      return 'authenticated';
    }
    return null;
  } catch (_) {
    return null;
  }
}
```
