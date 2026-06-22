import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/torrent.dart';
import '../providers/torrent_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/torrent_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/batch_operation_sheet.dart';
import 'torrent_detail_screen.dart';

class TorrentListScreen extends StatelessWidget {
  const TorrentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('种子'),
        actions: [
          Consumer<TorrentProvider>(
            builder: (ctx, tp, _) {
              final active = tp.selectMode && tp.selectedCount > 0;
              return IconButton(
                icon: Icon(
                  active ? Icons.deselect : Icons.select_all,
                ),
                tooltip: active ? '取消全选' : '全选',
                onPressed: tp.toggleSelectAllOrExit,
              );
            },
          ),
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
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortSheet(context);
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
              subtitle: '添加种子开始下载',
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
                  child: Builder(
                    builder: (listCtx) {
                      // filteredTorrents 是每次访问都重算的 getter；
                      // itemCount 与 itemBuilder 分两次访问会在 provider
                      // 数据刷新瞬间拿到不一致的 length（加载完成时列表
                      // 变长，旧帧 itemCount 越界 → RangeError）。这里算一次
                      // 缓存，保证两处用同一份列表。
                      final torrents = tp.filteredTorrents;
                      final loading = tp.loading;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: torrents.length + (loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (loading && index == 0) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final t = loading
                              ? torrents[index - 1]
                              : torrents[index];
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
                                    builder: (_) =>
                                        TorrentDetailScreen(torrent: t),
                                  ),
                                );
                              }
                            },
                          );
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
      floatingActionButton: () {
        final tp = context.watch<TorrentProvider>();
        final showFab = tp.selectMode && tp.selectedCount > 0;
        debugPrint(
          '[TorrentListScreen] FAB eval: selectMode=${tp.selectMode} '
          'selected=${tp.selectedCount} -> show=$showFab',
        );
        return showFab
            ? FloatingActionButton.extended(
                onPressed: () => showBatchOperationSheet(context),
                icon: const Icon(Icons.adb),
                label: Text('操作 ${tp.selectedCount}'),
              )
            : null;
      }(),
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
          TextButton(onPressed: tp.selectAll, child: const Text('全选')),
          TextButton(
            onPressed: tp.exitSelectMode,
            child: const Text('取消全选'),
          ),
        ],
      ),
    );
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
                              // setStateTabIndex(0) 内部已清空 _stateFilter，
                              // 单次 notifyListeners 避免双 rebuild 闪烁
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
                      // ── 异常原因筛选 ──
                      Text(
                        '异常原因',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ...tp.errorReasons.map(
                            (entry) => FilterChip(
                              label: Text(
                                '${entry.key} (${entry.value})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: tp.errorFilter == entry.key,
                              onSelected: (_) {
                                tp.setErrorFilter(
                                  tp.errorFilter == entry.key
                                      ? null
                                      : entry.key,
                                );
                                setSheetState(() {});
                              },
                            ),
                          ),
                          if (tp.errorReasons.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '暂无异常种子',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
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

  void _showSortSheet(BuildContext context) {
    final tp = context.read<TorrentProvider>();
    final fields = <(TorrentSortField, String)>[
      (TorrentSortField.addedAt, '添加时间'),
      (TorrentSortField.downloadSpeed, '下载速度'),
      (TorrentSortField.uploadSpeed, '上传速度'),
      (TorrentSortField.ratio, '分享率'),
      (TorrentSortField.uploaded, '总计上传'),
      (TorrentSortField.downloaded, '总计下载'),
      (TorrentSortField.totalSize, '种子大小'),
      (TorrentSortField.progress, '种子进度'),
      (TorrentSortField.eta, '剩余时间'),
      (TorrentSortField.lastActivity, '活动时间'),
      (TorrentSortField.seedsConnected, '做种人数'),
      (TorrentSortField.leechers, '下载人数'),
      (TorrentSortField.multiSource, '辅种数量'),
    ];
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
                      Text('排序', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      ...fields.map(
                        (f) => RadioListTile<TorrentSortField>(
                          title: Row(
                            children: [
                              Text(f.$2),
                              if (tp.sortField == f.$1)
                                Icon(
                                  tp.sortAsc
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                          value: f.$1,
                          groupValue: tp.sortField,
                          onChanged: (v) {
                            tp.setSortField(v!);
                            Navigator.pop(context);
                          },
                          contentPadding: EdgeInsets.zero,
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
