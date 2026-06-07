import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/torrent.dart';
import '../providers/torrent_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/torrent_tile.dart';
import '../widgets/empty_state.dart';
import 'torrent_detail_screen.dart';

class TorrentListScreen extends StatelessWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('种子'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _TorrentSearchDelegate(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<TorrentProvider>().refreshTorrents(
                    context.read<ClientProvider>().activeClients,
                  );
            },
          ),
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
              // Filter bar
              _buildFilterBar(context, tp),
              // Batch mode top bar
              if (tp.selectMode) _buildBatchBar(context, tp, cp),
              // Torrent list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => tp.refreshTorrents(cp.activeClients),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount:
                        tp.filteredTorrents.length + (tp.loading ? 1 : 0),
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
                          } else {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TorrentDetailScreen(torrent: t),
                            ));
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
      floatingActionButton:
          context.watch<TorrentProvider>().selectMode &&
                  context.watch<TorrentProvider>().selectedCount > 0
              ? _buildBatchActions(context)
              : null,
    );
  }

  Widget _buildFilterBar(BuildContext context, TorrentProvider tp) {
    final filters = <TorrentState?>[
      null,
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

  Widget _buildBatchBar(
      BuildContext context, TorrentProvider tp, ClientProvider cp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text('已选 ${tp.selectedCount} 个'),
          const Spacer(),
          TextButton(
            onPressed: () => tp.selectAll(),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () => tp.exitSelectMode(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget? _buildBatchActions(BuildContext context) {
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
        content: Text(
            '确定要删除选中的 ${context.read<TorrentProvider>().selectedCount} 个种子吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

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

class _TorrentSearchDelegate extends SearchDelegate {
  _TorrentSearchDelegate();

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          context.read<TorrentProvider>().setSearchQuery('');
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    context.read<TorrentProvider>().setSearchQuery(query);
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    context.read<TorrentProvider>().setSearchQuery(query);
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final tp = context.watch<TorrentProvider>();
    final results = tp.filteredTorrents;
    if (results.isEmpty) {
      return const Center(child: Text('无匹配结果'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final t = results[index];
        return ListTile(
          title: Text(t.name),
          subtitle: Text(t.clientId),
        );
      },
    );
  }
}
