import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../models/stats.dart';
import '../providers/site_provider.dart';
import '../widgets/site_tile.dart';
import '../widgets/empty_state.dart';
import 'site_form_screen.dart';
import 'site_import_screen.dart';
import 'site_detail_screen.dart';
import 'site_webview_screen.dart';
import '../services/site_service.dart';
import '../utils/helpers.dart';

class SiteListScreen extends StatefulWidget {
  const SiteListScreen({super.key});

  @override
  State<SiteListScreen> createState() => _SiteListScreenState();
}

class _SiteListScreenState extends State<SiteListScreen> {
  bool _searchVisible = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchVisible ? _buildSearchField() : const Text('站点'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_searchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  context.read<SiteProvider>().searchQuery = '';
                }
              });
            },
          ),
          // 刷新全部站点用户信息
          Consumer<SiteProvider>(
            builder: (context, provider, _) {
              if (provider.refreshingAll) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final hasAnyCookie = provider.sites.any(
                (s) => s.isActive && provider.hasCookie(s.id),
              );
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新全部用户信息',
                onPressed: hasAnyCookie
                    ? () => _refreshAll(context, provider)
                    : null,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: '导入预设',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SiteImportScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<SiteProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final sites = provider.filteredSites;

          if (provider.sites.isEmpty) {
            return EmptyState(
              icon: Icons.language,
              title: '还没有添加站点',
              subtitle: '添加站点或从预设导入',
              actionLabel: '导入预设',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SiteImportScreen()),
              ),
            );
          }

          if (sites.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              title: '没有匹配的站点',
              subtitle: '试试调整搜索条件',
            );
          }

          return Column(
            children: [
              // 全站统计汇总卡片
              _buildStatsCard(provider),
              // 标签筛选栏
              if (provider.allTags.isNotEmpty) _buildTagFilter(provider),
              // 站点列表
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: sites.length,
                  itemBuilder: (context, index) {
                    final site = sites[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SiteTile(
                        site: site,
                        userInfo: provider.getUserInfo(site.id),
                        hasCookie: provider.hasCookie(site.id),
                        refreshing: provider.isRefreshing(site.id),
                        iconAsset: site.iconAsset,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SiteDetailScreen(site: site),
                          ),
                        ),
                        onRefresh: () => provider.fetchUserInfo(site.id),
                        onToggleActive: (v) {
                          final updated = site.copyWith(isActive: v);
                          provider.updateSite(site.id, updated);
                        },
                        onOpenMessages: () =>
                            _openMessages(context, site, provider),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SiteFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: '搜索站点名称或标签...',
        border: InputBorder.none,
        isDense: true,
      ),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
      onChanged: (v) => context.read<SiteProvider>().searchQuery = v,
    );
  }

  /// 顶部全站统计汇总卡片
  Widget _buildStatsCard(SiteProvider provider) {
    final stats = provider.siteStats;
    final lastText = stats.lastRefreshAt == null
        ? '尚未刷新'
        : '上次刷新：${_relativeTime(stats.lastRefreshAt!)}';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部概览行
            Row(
              children: [
                Text(
                  '站点 ${stats.totalSites} · 活跃 ${stats.activeSites} · '
                  '已登录 ${stats.sitesWithCookie}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (provider.refreshingAll)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: '刷新全部用户信息',
                    onPressed: stats.sitesWithCookie > 0
                        ? () => _refreshAll(context, provider)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 数值网格
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _statsItems(stats)
                  .map((item) => _statCell(context, item.label, item.value))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
              lastText,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  List<_StatItem> _statsItems(SiteStats stats) {
    return [
      _StatItem('总上传', formatBytes(stats.totalUploaded)),
      _StatItem('总下载', formatBytes(stats.totalDownloaded)),
      _StatItem('总魔力', stats.totalBonus.toString()),
      _StatItem('总做种数', stats.totalSeedingCount.toString()),
      _StatItem('总做种体积', formatBytes(stats.totalSeedingSize)),
      _StatItem('未读消息', stats.unreadTotal.toString()),
      _StatItem('H&R 待考核', stats.hnrPreWarningTotal.toString()),
      _StatItem('H&R 不达标', stats.hnrUnsatisfiedTotal.toString()),
    ];
  }

  Widget _statCell(BuildContext context, String label, String value) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilter(SiteProvider provider) {
    final tags = provider.allTags.toList()..sort();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = provider.tagFilter == null;
            return FilterChip(
              label: const Text('全部'),
              selected: selected,
              onSelected: (_) => provider.tagFilter = null,
              visualDensity: VisualDensity.compact,
            );
          }
          final tag = tags[index - 1];
          final selected = provider.tagFilter == tag;
          return FilterChip(
            label: Text(tag),
            selected: selected,
            onSelected: (_) => provider.tagFilter = selected ? null : tag,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  /// 打开站内消息页（WebView 屏）
  ///
  /// 点击未读徽标触发。先校验 cookie / URL 存在，否则提示并返回。
  void _openMessages(
    BuildContext context,
    SiteConfig site,
    SiteProvider provider,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    if (!provider.hasCookie(site.id)) {
      messenger.showSnackBar(const SnackBar(content: Text('请先配置 Cookie')));
      return;
    }
    if (site.baseUrl == null || site.baseUrl!.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('该站点未配置 URL')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SiteWebViewScreen(
          site: site,
          path: SiteService.messagePathFor(site.parseSchema),
        ),
      ),
    );
  }

  /// 批量刷新所有有 Cookie 的站点用户信息
  Future<void> _refreshAll(BuildContext context, SiteProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final hasAny = provider.sites.any((s) => provider.hasCookie(s.id));
    if (!hasAny) {
      messenger.showSnackBar(
        const SnackBar(content: Text('没有已配置 Cookie 的站点可刷新')),
      );
      return;
    }
    final (success, failed) = await provider.refreshAllUserInfo();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已刷新 $success 个站点'
          '${failed > 0 ? "，$failed 个失败" : ""}',
        ),
        backgroundColor: failed == 0 ? Colors.green : null,
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  _StatItem(this.label, this.value);
}
