import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../widgets/site_favicon.dart';
import '../utils/helpers.dart';
import 'site_form_screen.dart';
import 'site_cookie_screen.dart';

class SiteDetailScreen extends StatelessWidget {
  final SiteConfig site;

  const SiteDetailScreen({super.key, required this.site});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SiteFormScreen(site: site)),
            ),
          ),
        ],
      ),
      body: Consumer<SiteProvider>(
        builder: (context, provider, _) {
          final userInfo = provider.getUserInfo(site.id);
          final hasCookie = provider.hasCookie(site.id);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 基本信息卡片 ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 图标 + 名称
                      Row(
                        children: [
                          SiteFavicon(
                            iconAsset: _getIconAsset(site.id),
                            siteName: site.name,
                            size: 56,
                            radius: 14,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  site.name,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (site.baseUrl != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    site.baseUrl!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 标签
                      if (site.tags.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          children: site.tags
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // 备注
                      if (site.notes != null && site.notes!.isNotEmpty) ...[
                        const Divider(),
                        Text(
                          site.notes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Cookie 状态卡片 ──
              Card(
                child: ListTile(
                  leading: Icon(
                    hasCookie ? Icons.cookie : Icons.cookie_outlined,
                    color: hasCookie
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(hasCookie ? 'Cookie 已配置' : '未配置 Cookie'),
                  subtitle: Text(
                    hasCookie ? '点击管理 Cookie 或刷新用户信息' : '配置 Cookie 以获取用户信息',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiteCookieScreen(site: site),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── 用户信息卡片 ──
              if (userInfo != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              userInfo.username ?? '未知用户',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (userInfo.level != null) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(userInfo.level!),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoGrid(context, userInfo),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── 操作按钮 ──
              if (hasCookie)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新用户信息'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('正在获取用户信息...'),
                          ],
                        ),
                        duration: Duration(seconds: 30),
                      ),
                    );
                    final ok = await provider.fetchUserInfo(site.id);
                    messenger.hideCurrentSnackBar();
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(ok ? '用户信息已更新' : '获取失败，请检查 Cookie 是否有效'),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                ),

              const SizedBox(height: 12),

              // 删除按钮
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('删除站点',
                    style: TextStyle(color: Colors.red)),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, SiteUserInfo info) {
    final items = <_InfoItem>[
      _InfoItem('分享率',
          info.ratio == double.infinity ? '∞' : info.ratio?.toStringAsFixed(2)),
      _InfoItem('上传量', info.uploaded != null ? formatBytes(info.uploaded!) : null),
      _InfoItem('下载量',
          info.downloaded != null ? formatBytes(info.downloaded!) : null),
      _InfoItem('魔力值', info.bonusPoints?.toString()),
      _InfoItem('做种数', info.seedingCount?.toString()),
      _InfoItem('下载中', info.leechingCount?.toString()),
    ].where((i) => i.value != null).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: (MediaQuery.of(context).size.width - 64) / 2 - 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.value!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除站点'),
        content: Text('确定要删除 "${site.name}" 吗？\n关联的 Cookie 和用户信息也会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<SiteProvider>().deleteSite(site.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  String? _getIconAsset(String siteId) {
    const exts = ['.ico', '.png', '.jpg', '.gif', '.svg', '.webp'];
    for (final ext in exts) {
      return 'assets/sites/icons/$siteId$ext';
    }
    return null;
  }
}

class _InfoItem {
  final String label;
  final String? value;
  _InfoItem(this.label, this.value);
}
