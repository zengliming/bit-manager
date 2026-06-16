import 'package:flutter/material.dart';
import '../models/site_config.dart';
import 'site_favicon.dart';
import '../utils/helpers.dart';

/// 站点列表项 — 展示图标、名称、标签、用户信息摘要
class SiteTile extends StatelessWidget {
  final SiteConfig site;
  final SiteUserInfo? userInfo;
  final bool hasCookie;
  final bool refreshing;
  final String? iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final ValueChanged<bool>? onToggleActive;

  const SiteTile({
    super.key,
    required this.site,
    this.userInfo,
    this.hasCookie = false,
    this.refreshing = false,
    this.iconAsset,
    this.onTap,
    this.onRefresh,
    this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: site.isActive ? 1.0 : 0.5,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 图标
                SiteFavicon(
                  iconAsset: iconAsset,
                  siteName: site.name,
                  size: 44,
                  radius: 10,
                ),
                const SizedBox(width: 12),

                // 中间信息区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称行
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              site.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasCookie) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.cookie,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 标签 Chips
                      if (site.tags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: site.tags
                              .take(3)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),

                      // 用户信息摘要 / 占位提示
                      const SizedBox(height: 4),
                      _buildUserSummary(context),
                    ],
                  ),
                ),

                // 右侧：分享率 / 刷新 + 启用开关
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(height: 24, child: _buildTrailingTop(context)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: site.isActive,
                        onChanged: onToggleActive,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserSummary(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    if (refreshing) {
      return Text('正在获取用户信息...', style: mutedStyle);
    }
    if (!hasCookie) {
      return Text('未配置 Cookie', style: mutedStyle);
    }
    final info = userInfo;
    if (info == null) {
      return Text('点击右侧 ⟳ 获取用户信息', style: mutedStyle);
    }
    if (info.fetchFailed) {
      return Text(
        '抓取失败 · 检查 Cookie 是否有效',
        style: mutedStyle.copyWith(color: const Color(0xFFFF3B30)),
      );
    }

    final parts = <String>[];
    if (info.username != null) parts.add(info.username!);
    if (info.level != null) parts.add(info.level!);
    if (info.uploaded != null) parts.add('↑${formatBytes(info.uploaded!)}');
    if (info.downloaded != null) parts.add('↓${formatBytes(info.downloaded!)}');

    if (parts.isEmpty) {
      return Text('解析未命中字段 · 站点模板可能不兼容', style: mutedStyle);
    }

    return Text(
      parts.join(' · '),
      style: mutedStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 右上角：抓取中显示 spinner；有 ratio 显示 ratio；否则显示刷新图标按钮
  Widget _buildTrailingTop(BuildContext context) {
    if (refreshing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final ratio = userInfo?.ratio;
    if (ratio != null && !(userInfo?.fetchFailed ?? false)) {
      return Text(
        _formatRatio(ratio),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _ratioColor(ratio),
        ),
      );
    }
    if (hasCookie && onRefresh != null) {
      return InkWell(
        onTap: onRefresh,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: Icon(Icons.refresh, size: 20),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _formatRatio(double ratio) {
    if (ratio == double.infinity) return '∞';
    return ratio.toStringAsFixed(2);
  }

  Color _ratioColor(double ratio) {
    if (ratio == double.infinity || ratio >= 2.0)
      return const Color(0xFF34C759);
    if (ratio >= 1.0) return const Color(0xFF007AFF);
    return const Color(0xFFFF3B30);
  }
}
