import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
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
    await provider.fetchItems(
      widget.source.id,
      clients: context.read<ClientProvider>().activeClients,
    );
    if (mounted) setState(() => _loading = false);
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
                      } else if (item.link != null &&
                          !item.isDuplicate &&
                          !item.isDownloaded) {
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('下载 (${_selectedGuids.length})'),
            )
          : null,
    );
  }

  void _showDownloadDialog(RssItem item) {
    final clients = context.read<ClientProvider>().activeClients;
    if (clients.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可用的客户端')));
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '下载到...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...clients.map(
            (client) => ListTile(
              leading: Icon(
                client.type == ClientType.qBittorrent
                    ? Icons.download
                    : Icons.wifi,
              ),
              title: Text(client.name),
              onTap: () async {
                final rssProvider = context.read<RssProvider>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(ctx);
                final ok = await rssProvider.downloadItem(item.link!, client);
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ok ? '已添加到 ${client.name}' : '下载失败'),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _batchDownload() async {
    final items = context.read<RssProvider>().getItems(widget.source.id);
    final selectedItems = items
        .where((i) => _selectedGuids.contains(i.guid) && i.link != null)
        .toList();
    if (selectedItems.isEmpty) return;

    final clients = context.read<ClientProvider>().activeClients;
    if (clients.isEmpty) return;

    final client = await showModalBottomSheet<ClientConfig>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '选择目标客户端',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ...clients.map(
            (c) => ListTile(
              leading: Icon(
                c.type == ClientType.qBittorrent ? Icons.download : Icons.wifi,
              ),
              title: Text(c.name),
              onTap: () => Navigator.pop(ctx, c),
            ),
          ),
        ],
      ),
    );

    if (client == null || !mounted) return;

    setState(() => _loadingDownload = true);
    final rssProvider = context.read<RssProvider>();
    for (final item in selectedItems) {
      await rssProvider.downloadItem(item.link!, client);
      await rssProvider.markDownloaded(item.guid);
    }
    if (mounted) {
      setState(() {
        _loadingDownload = false;
        _selectedGuids.clear();
        _selectMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已添加 ${selectedItems.length} 个种子到 ${client.name}'),
        ),
      );
    }
    _fetch();
  }
}
