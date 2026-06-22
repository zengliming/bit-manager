import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../providers/torrent_provider.dart';
import '../providers/client_provider.dart';
import '../services/service_factory.dart';
import '../services/torrent_client.dart';
import '../utils/helpers.dart';
import '../widgets/delete_torrent_dialog.dart';

class TorrentDetailScreen extends StatefulWidget {
  final Torrent torrent;
  const TorrentDetailScreen({super.key, required this.torrent});

  @override
  State<TorrentDetailScreen> createState() => _TorrentDetailScreenState();
}

class _TorrentDetailScreenState extends State<TorrentDetailScreen> {
  late Torrent _torrent;
  List<TorrentFile>? _files;
  List<TrackerInfo>? _trackers;
  bool _loadingFiles = false;
  bool _loadingTrackers = false;

  @override
  void initState() {
    super.initState();
    _torrent = widget.torrent;
    _loadDetails();
  }

  ClientConfig? get _client {
    final cp = context.read<ClientProvider>();
    return cp.clients.where((c) => c.id == _torrent.clientId).firstOrNull;
  }

  Future<void> _loadDetails() async {
    final client = _client;
    if (client == null) {
      debugPrint(
        'Cannot load details: client not found for ${_torrent.clientId}',
      );
      return;
    }

    setState(() => _loadingFiles = true);
    try {
      final service = ServiceFactory.getService(client.type);
      _files = await service.getTorrentFiles(client, _torrent.hash);
    } catch (e) {
      debugPrint('Failed to load files: $e');
    }
    if (mounted) setState(() => _loadingFiles = false);

    setState(() => _loadingTrackers = true);
    try {
      final service = ServiceFactory.getService(client.type);
      _trackers = await service.getTrackers(client, _torrent.hash);
    } catch (e) {
      debugPrint('Failed to load trackers: $e');
    }
    if (mounted) setState(() => _loadingTrackers = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _torrent.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDetails),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 操作按钮（置顶） ──
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  '暂停',
                  Icons.pause,
                  () => _operate('pause'),
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  '恢复',
                  Icons.play_arrow,
                  () => _operate('resume'),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  '删除',
                  Icons.delete,
                  _confirmDelete,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 进度卡 ──
          _buildSection('进度', [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _torrent.progress,
                      minHeight: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(_torrent.progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${formatBytes(_torrent.downloaded)} / ${formatBytes(_torrent.totalSize)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  'ETA: ${_torrent.eta > 0 ? formatEta(_torrent.eta) : '--'}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          // ── 速度与状态 ──
          _buildSection('速度', [
            Row(
              children: [
                Expanded(
                  child: _statItem(
                    Icons.download,
                    '下载',
                    formatSpeed(_torrent.downloadSpeed),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statItem(
                    Icons.upload,
                    '上传',
                    formatSpeed(_torrent.uploadSpeed),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statItem(
                    Icons.compare_arrows,
                    '分享率',
                    formatRatio(_torrent.ratio),
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          // ── 做种与连接 ──
          _buildSection('连接', [
            Row(
              children: [
                Expanded(
                  child: _statItem(
                    Icons.arrow_upward,
                    '做种',
                    '${_torrent.seedsConnected} / ${_torrent.seedsTotal}',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statItem(
                    Icons.arrow_downward,
                    '下载',
                    '${_torrent.peersConnected} / ${_torrent.peersTotal}',
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          // ── 基本信息 ──
          _buildSection('信息', [
            _infoRow('Hash', _torrent.hash, selectable: true),
            _infoRow('状态', torrentStateLabel(_torrent.state)),
            _infoRow('总大小', formatBytes(_torrent.totalSize)),
            _infoRow('添加时间', formatDateTime(_torrent.addedAt)),
            _infoRow('完成时间', formatDateTime(_torrent.completedAt)),
            _infoRow('保存路径', _torrent.savePath ?? '-'),
            if (_torrent.error != null && _torrent.error!.isNotEmpty)
              _infoRow('错误信息', _torrent.error!, color: Colors.red),
          ]),

          const SizedBox(height: 12),

          // ── 文件列表 ──
          _buildSection(
            '文件${_files != null ? ' (${_files!.length})' : ''}',
            _loadingFiles
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ]
                : _files == null
                ? [Text('加载失败', style: TextStyle(color: Colors.grey[500]))]
                : _files!.isEmpty
                ? [Text('无文件信息', style: TextStyle(color: Colors.grey[500]))]
                : [
                    SizedBox(
                      height: (_files!.length * 52).clamp(0, 300).toDouble(),
                      child: ListView.builder(
                        itemCount: _files!.length,
                        itemBuilder: (ctx, i) => _fileTile(_files![i]),
                      ),
                    ),
                  ],
          ),

          const SizedBox(height: 12),

          // ── Tracker 列表 ──
          _buildSection(
            'Tracker${_trackers != null ? ' (${_trackers!.length})' : ''}',
            _loadingTrackers
                ? [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ]
                : _trackers == null
                ? [Text('加载失败', style: TextStyle(color: Colors.grey[500]))]
                : _trackers!.isEmpty
                ? [
                    Text(
                      '无 Tracker 信息',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ]
                : [
                    ..._trackers!.map((t) => _trackerTile(t)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _showAddTrackerDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加 Tracker'),
                    ),
                  ],
          ),
        ],
      ),
    );
  }

  // ── 构建工具方法 ──

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    bool selectable = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          Expanded(
            child: selectable
                ? SelectableText(
                    value,
                    style: TextStyle(fontSize: 13, color: color),
                  )
                : Text(value, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
    Color color,
  ) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(TorrentFile file) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            file.name,
            style: const TextStyle(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: file.progress,
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatBytes(file.size),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trackerTile(TrackerInfo tracker) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracker.url,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${tracker.status}  ·  ${tracker.peers} peers',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          PopupMenuButton(
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'replace', child: const Text('替换')),
              PopupMenuItem(
                value: 'remove',
                child: Text('移除', style: TextStyle(color: Colors.red[700])),
              ),
            ],
            onSelected: (action) {
              if (action == 'replace') _showReplaceTrackerDialog(tracker);
              if (action == 'remove') _removeTracker(tracker);
            },
          ),
        ],
      ),
    );
  }

  // ── 操作方法 ──

  Future<void> _operate(String action) async {
    final client = _client;
    if (client == null) return;
    final tp = context.read<TorrentProvider>();
    bool ok;
    if (action == 'pause') {
      ok = await tp.pauseTorrents(client, [_torrent.hash]);
    } else {
      ok = await tp.resumeTorrents(client, [_torrent.hash]);
    }
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'pause' ? '已暂停' : '已恢复')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final client = _client;
    if (client == null || !mounted) return;
    final tp = context.read<TorrentProvider>();

    // 预计算智能删除方案：这个种子删后是否还有辅种引用同一份数据
    final plan = tp.planSmartDelete(client, [_torrent.hash]);
    final willDeleteFiles = plan.deleteFilesHashes.isNotEmpty;

    final result = await showDeleteTorrentDialog(
      context,
      count: 1,
      willDeleteFilesCount: willDeleteFiles ? 1 : 0,
    );
    if (!result.confirmed || !mounted) return;

    await tp.deleteTorrentsSmart(
      client,
      [_torrent.hash],
      deleteFilesWhenNoCrossSeed: result.deleteFilesWhenNoCrossSeed,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showAddTrackerDialog() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 Tracker'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tracker URL',
            labelText: 'URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    final client = _client;
    if (client == null) return;
    try {
      final service = ServiceFactory.getService(client.type);
      await service.addTracker(client, _torrent.hash, url);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tracker 已添加')));
      _loadDetails();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
    }
  }

  Future<void> _showReplaceTrackerDialog(TrackerInfo oldTracker) async {
    final controller = TextEditingController();
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('替换 Tracker'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: oldTracker.url,
            labelText: '新 URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('替换'),
          ),
        ],
      ),
    );
    if (newUrl == null || newUrl.isEmpty || !mounted) return;

    final client = _client;
    if (client == null) return;
    try {
      final service = ServiceFactory.getService(client.type);
      await service.replaceTracker(
        client,
        _torrent.hash,
        oldTracker.url,
        newUrl,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tracker 已替换')));
      _loadDetails();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('替换失败: $e')));
    }
  }

  Future<void> _removeTracker(TrackerInfo tracker) async {
    final client = _client;
    if (client == null) return;
    try {
      final service = ServiceFactory.getService(client.type);
      await service.removeTracker(client, _torrent.hash, tracker.url);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tracker 已移除')));
      }
      _loadDetails();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除失败: $e')));
    }
  }
}

String torrentStateLabel(TorrentState state) {
  switch (state) {
    case TorrentState.downloading:
      return '下载中';
    case TorrentState.seeding:
      return '做种中';
    case TorrentState.paused:
      return '已暂停';
    case TorrentState.checking:
      return '校验中';
    case TorrentState.queued:
      return '队列中';
    case TorrentState.error:
      return '出错';
    case TorrentState.metaDL:
      return '获取元数据';
    case TorrentState.unknown:
      return '未知';
  }
}
