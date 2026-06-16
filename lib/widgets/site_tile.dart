import 'package:flutter/material.dart';
import '../models/site_config.dart';
import 'site_favicon.dart';
import '../utils/helpers.dart';

/// 站点列表项 — 紧凑 4 行布局
///
/// 行 1：图标 + 名称 + cookie + 未读徽标
/// 行 2：标签 chips
/// 行 3：用户名 · 等级 · ↑上传 · ↓下载
/// 行 4：✦魔力 · ⇧做种 · ⇩下载 · ⚠H&R
class SiteTile extends StatelessWidget {
  final SiteConfig site;
  final SiteUserInfo? userInfo;
  final bool hasCookie;
  final bool refreshing;
  final String? iconAsset;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onOpenMessages;

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
    this.onOpenMessages,
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
                SiteFavicon(
                  iconAsset: iconAsset,
                  siteName: site.name,
                  size: 44,
                  radius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow1(context),
                      if (site.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: _buildTagChips(theme),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildIdentityLine(theme),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _buildStatusLine(theme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTrailing(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 行 1：图标、名称、cookie、unread ──
  Widget _buildRow1(BuildContext context) {
    final theme = Theme.of(context);
    final info = userInfo;
    final showUnread = hasCookie && (info?.messageCount ?? 0) > 0;
    final unreadCount = info?.messageCount ?? 0;

    return Row(
      children: [
        Flexible(
          child: Text(
            site.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (hasCookie) ...[
          const SizedBox(width: 6),
          Icon(Icons.cookie, size: 14, color: theme.colorScheme.primary),
        ],
        if (showUnread) ...[
          const SizedBox(width: 8),
          _UnreadBadge(count: unreadCount, onTap: onOpenMessages),
        ],
      ],
    );
  }

  Widget _buildTagChips(ThemeData theme) {
    return Wrap(
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
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
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
    );
  }

  // ── 行 3：身份 + 传输 ──
  Widget _buildIdentityLine(ThemeData theme) {
    final mutedStyle = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

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

  // ── 行 4：状态指标 ──
  Widget _buildStatusLine(ThemeData theme) {
    final info = userInfo;
    if (info == null) return const SizedBox.shrink();

    final mutedStyle = TextStyle(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    final children = <Widget>[];

    if (info.bonusPoints != null) {
      children.add(Text('✦${_formatNumber(info.bonusPoints!)}', style: mutedStyle));
    }
    if (info.seedingCount != null) {
      children.add(Text('⇧${info.seedingCount}', style: mutedStyle));
    }
    if (info.leechingCount != null) {
      children.add(Text('⇩${info.leechingCount}', style: mutedStyle));
    }

    final pre = info.hnrPreWarning ?? 0;
    final unsat = info.hnrUnsatisfied ?? 0;
    if (pre + unsat > 0) {
      final hnrColor = unsat > 0
          ? const Color(0xFFFF3B30)
          : const Color(0xFFFF9500);
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: hnrColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '⚠${pre + unsat}',
            style: TextStyle(
              fontSize: 11,
              color: hnrColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, children: children);
  }

  // ── 右侧：ratio / 刷新 + 启用开关 ──
  Widget _buildTrailing(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24, child: _buildTrailingTop(context)),
        const SizedBox(height: 6),
        SizedBox(
          height: 28,
          child: Switch(
            value: site.isActive,
            onChanged: onToggleActive,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }  Widget _buildTrailingTop(BuildContext context) {
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
    if (ratio == double.infinity || ratio >= 2.0) {
      return const Color(0xFF34C759);
    }
    if (ratio >= 1.0) return const Color(0xFF007AFF);
    return const Color(0xFFFF3B30);
  }

  String _formatNumber(num n) {
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }
}

/// 红色未读徽标
class _UnreadBadge extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _UnreadBadge({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Semantics(
      label: '$count 条未读消息',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
