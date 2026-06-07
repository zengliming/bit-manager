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
              showSearch(context: context, delegate: _TorrentSearchDelegate());
            },
          ),
          Consumer<TorrentProvider>(
            builder: (ctx, tp, _) => Badge(
              isLabelVisible: tp.activeFilterCount > 0,
              label: Text('${tp.activeFilterCount}'),
              child: IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () => _showFilterSheet(ctx),
              ),
            ),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TorrentDetailScreen(torrent: t),
                              ),
                            );
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
    final colorScheme = Theme.of(context).colorScheme;
    final tabs = ['全部', '下载中', '错误异常', '做种中'];
    final errorCount = tp.errorCount;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = tp.stateTabIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => tp.setStateTabIndex(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i == 2 && errorCount > 0) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        tabs[i],
                        style: TextStyle(
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBatchBar(
    BuildContext context,
    TorrentProvider tp,
    ClientProvider cp,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text('已选 ${tp.selectedCount} 个'),
          const Spacer(),
          TextButton(onPressed: () => tp.selectAll(), child: const Text('全选')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ok ? '操作成功' : '操作失败')));
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
          '确定要删除选中的 ${context.read<TorrentProvider>().selectedCount} 个种子吗？',
        ),
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

  void _showFilterSheet(BuildContext context) {
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行
                      Row(
                        children: [
                          Text(
                            '筛选',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              tp.clearAllFilters();
                              setSheetState(() {});
                            },
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                      const Divider(),
                      // ── 状态筛选 ──
                      Text('状态', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected:
                                tp.stateFilter == null ||
                                tp.stateFilter!.isEmpty,
                            onSelected: (_) {
                              tp.setStateFilter(null);
                              tp.setStateTabIndex(0);
                              setSheetState(() {});
                            },
                          ),
                          ...TorrentState.values.map((state) {
                            final labels = {
                              TorrentState.downloading: '下载中',
                              TorrentState.seeding: '做种中',
                              TorrentState.paused: '已暂停',
                              TorrentState.checking: '校验中',
                              TorrentState.queued: '等待中',
                              TorrentState.error: '出错',
                              TorrentState.metaDL: '获取元数据',
                              TorrentState.unknown: '未知',
                            };
                            return FilterChip(
                              label: Text(labels[state] ?? state.name),
                              selected: tp.stateFilter?.contains(state) == true,
                              onSelected: (_) {
                                final current = tp.stateFilter ?? {};
                                final newSet = current.contains(state)
                                    ? (current..remove(state))
                                    : {...current, state};
                                tp.setStateFilter(
                                  newSet.isEmpty ? null : newSet,
                                );
                                setSheetState(() {});
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── 客户端筛选 ──
                      Text(
                        '客户端',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected: tp.clientFilter == null,
                            onSelected: (_) {
                              tp.setClientFilter(null);
                              setSheetState(() {});
                            },
                          ),
                          ...cp.clients.map(
                            (client) => FilterChip(
                              label: Text(client.name),
                              selected: tp.clientFilter == client.id,
                              onSelected: (_) {
                                tp.setClientFilter(
                                  tp.clientFilter == client.id
                                      ? null
                                      : client.id,
                                );
                                setSheetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ── 错误过滤 ──
                      SwitchListTile(
                        title: const Text('仅显示有错误的种子'),
                        value: tp.errorOnly,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (v) {
                          tp.setErrorOnly(v);
                          tp.setErrorFilter(null);
                          setSheetState(() {});
                        },
                      ),
                      if (tp.errorOnly) ...[
                        const SizedBox(height: 8),
                        Text(
                          '错误类型',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            FilterChip(
                              label: const Text('全部'),
                              selected: tp.errorFilter == null,
                              onSelected: (_) {
                                tp.setErrorFilter(null);
                                setSheetState(() {});
                              },
                            ),
                            ...tp.allTorrents
                                .map((t) => t.error)
                                .where((e) => e != null && e.isNotEmpty)
                                .toSet()
                                .map(
                                  (err) => FilterChip(
                                    label: Text(
                                      err!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: tp.errorFilter == err,
                                    onSelected: (_) {
                                      tp.setErrorFilter(
                                        tp.errorFilter == err ? null : err,
                                      );
                                      setSheetState(() {});
                                    },
                                  ),
                                ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // ── 应用按钮 ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('应用'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
        return ListTile(title: Text(t.name), subtitle: Text(t.clientId));
      },
    );
  }
}
