# 批量种子操作面板设计

日期：2026-06-22

## 背景

种子列表的选择模式当前用右下角浮动按钮（暂停/恢复/删除）承载批量操作，入口不直观；且缺少批量编辑能力。用户要求：批量选择后弹出操作面板，支持批量暂停/恢复/删除，以及批量编辑（经澄清，编辑范围限定为批量改 Tracker）。

## 目标

1. 用底部操作面板（bottom sheet）取代右下角浮动按钮，承载所有批量操作。
2. 面板含：暂停、恢复、删除（复用已有「无辅种时删除文件」选项）、批量改 Tracker。
3. 批量改 Tracker 支持三种操作：添加、替换、删除，跨客户端逐客户端执行。

## 非目标（本期不做）

- 批量改保存路径 / 分类 / 限速（用户已确认本期不做）。
- 单种子 Tracker 编辑流程改动（详情页保持现有单个接口）。

## 现状与能力边界

- `ITorrentClientService` 现有：单个种子的 `addTracker`/`replaceTracker`/`removeTracker`，批量 `pauseTorrents`/`resumeTorrents`/`deleteTorrents`。无批量 Tracker 接口。
- qBittorrent：`/api/v2/torrents/addTrackers`、`/editTracker`、`/removeTrackers` 原生支持 hash 列表（`|` 分隔），天然批量。
- Transmission：`torrent-set` 的 `trackerAdd`/`trackerReplace`/`trackerRemove` 基于 id 列表，一次调用批量。
- Provider 层批量操作沿用「逐客户端分组调用」模式（见现有 `_batchDelete`/`_batchAction`）。

## 设计

### 1. 接口扩展

`ITorrentClientService` 新增 3 个批量 Tracker 方法，与现有单个 Tracker 方法对称：

```dart
Future<void> addTrackers(ClientConfig config, List<String> hashes, List<String> trackerUrls);
Future<void> replaceTrackers(ClientConfig config, List<String> hashes, String oldUrl, String newUrl);
Future<void> removeTrackers(ClientConfig config, List<String> hashes, String trackerUrl);
```

#### QBittorrentService 实现

- `addTrackers`：POST `/api/v2/torrents/addTrackers`，`hashes` 用 `|` 分隔，`urls` 用 `\n` 分隔。
- `replaceTrackers`：POST `/api/v2/torrents/editTracker`，`hashes` 用 `|` 分隔，`origUrl`、`newUrl`。
- `removeTrackers`：POST `/api/v2/torrents/removeTrackers`，`hashes` 用 `|` 分隔，`urls` 用 `\n` 分隔。

沿用现有 `_post` + SID 鉴权模式。

#### TransmissionService 实现

用 `torrent-set` 基于 id 列表，一次调用批量：
- `addTrackers`：`args: {'ids': ids, 'trackerAdd': urls}`
- `replaceTrackers`：`args: {'ids': ids, 'trackerReplace': [oldUrl, newUrl]}`（按数组传一对）
- `removeTrackers`：`args: {'ids': ids, 'trackerRemove': [url]}`

沿用现有 `_hashToIds` + `_rpcCall` 模式。

### 2. Provider 层

`TorrentProvider` 新增逐客户端转发方法，沿用 `pauseTorrents` 模式：

```dart
Future<bool> addTrackers(ClientConfig client, List<String> hashes, List<String> urls);
Future<bool> replaceTrackers(ClientConfig client, List<String> hashes, String oldUrl, String newUrl);
Future<bool> removeTrackers(ClientConfig client, List<String> hashes, String url);
```

- 空 hashes 直接返回 true，不调 service。
- try/catch，失败记入 `_error` 并 `notifyListeners()`，返回 false。

### 3. UI 流程（底部操作面板）

**触发**：选中种子后（`selectMode && selectedCount > 0`），用底部操作面板取代当前右下角浮动按钮 `_buildBatchActions`。

**面板内容**（`showModalBottomSheet`，与 `_showFilterSheet`/`_showSortSheet` 风格一致）：

操作组（ListTile，点击执行后关闭面板）：
- 暂停选中 → 逐客户端 `pauseTorrents`，成功后 `exitSelectMode`
- 恢复选中 → 逐客户端 `resumeTorrents`，成功后 `exitSelectMode`
- 删除选中 → 调 `showDeleteTorrentDialog`（含「无辅种时删除文件」选项），确认后 `_batchDelete`，关闭面板与选择模式
- 改 Tracker ▸ → 展开二级对话框（见下）

**Tracker 子操作**（三个入口，各自弹小对话框收集参数）：
- 添加 Tracker：多行输入框（每行一个 URL）→ 逐客户端 `addTrackers`
- 替换 Tracker：两个输入框（旧 URL / 新 URL）→ 逐客户端 `replaceTrackers`
- 删除 Tracker：输入框（要删除的 URL）→ 逐客户端 `removeTrackers`

**跨客户端**：按 `cp.activeClients` 分组，逐客户端调用对应 provider 方法。

### 4. 错误处理与边界

- **空选校验**：面板按钮点击时 `selectedCount == 0` → SnackBar「未选中种子」并中止。
- **Tracker URL 校验**：非空才提交；URL 不含 `://` 视为非法，提示「Tracker URL 格式异常」，整批不提交。
- **跨客户端部分失败**：逐客户端 await，记录每个客户端成功/失败，SnackBar 汇总（如「已完成：Client A 成功，Client B 失败：网络错误」）。任一失败不中断其余客户端。
- **Transmission `replaceTrackers` 边界**：`trackerReplace` 要求 `oldUrl` 精确匹配；某种子不含该 oldUrl 时 Transmission 会报错。provider 层 catch 单客户端失败、记入汇总，不中断其他客户端。
- **批量 Tracker 操作后状态**：不退出选择模式（用户可能连续做多种 Tracker 操作）；不自动刷新种子列表（Tracker 变更不影响列表项数据）。
- **面板与选择模式生命周期**：面板关闭后选择模式保持；暂停/恢复/删除这类改变列表状态的操作本身会 `exitSelectMode`。

### 5. 测试

#### Provider 测试（扩展 `_FakeTorrentService` 记录调用）

- `addTrackers` 逐客户端转发，hashes/urls 正确传递。
- `replaceTrackers` / `removeTrackers` 同理。
- 任一客户端抛错 → 返回 false、记入 `_error`、不中断其他客户端。
- 空 hashes 直接返回 true 不调 service。

#### Service 层测试

- qBittorrent：验证 `addTrackers` 拼出 `hashes=|`分隔 + `urls=\n`分隔；`replaceTrackers`/`removeTrackers` 请求形态正确。用 dio `HttpClientAdapter` mock 验证请求。
- Transmission：验证 `torrent-set` 用 `trackerAdd`/`trackerReplace`/`trackerRemove` + id 列表。

#### Widget 测试

- 选中种子 → 点底部操作面板入口 → 面板含「暂停/恢复/删除/改 Tracker」。
- 添加 Tracker：填 URL → 确认 → 调 provider `addTrackers`（fake 验证）→ SnackBar 成功。
- 空选校验：未选中时点操作提示「未选中种子」。

删除流程复用现有 `showDeleteTorrentDialog` + `deleteTorrentsSmart` 的测试，不重复。

## 影响范围

- 新增/改动：`lib/services/torrent_client.dart`（接口）、`lib/services/qbittorrent_service.dart`、`lib/services/transmission_service.dart`、`lib/providers/torrent_provider.dart`、`lib/screens/torrent_list_screen.dart`（面板替换浮动按钮）。
- 测试：`test/providers/torrent_provider_test.dart`、`test/services/`、`test/screens/torrent_list_select_test.dart`。
- 详情页单种子 Tracker 编辑不动。
