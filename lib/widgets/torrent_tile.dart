import 'package:flutter/material.dart';
import '../models/torrent.dart';
import '../utils/helpers.dart';
import 'status_border.dart';
import 'status_chip.dart';

class TorrentTile extends StatelessWidget {
  final Torrent torrent;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TorrentTile({
    super.key,
    required this.torrent,
    this.isSelected = false,
    this.selectMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = statusColors(torrent.state);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: state dot + checkbox + name + StatusChip + progress %
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        torrent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusChip(state: torrent.state),
                    if (torrent.state == TorrentState.downloading ||
                        torrent.state == TorrentState.seeding) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${(torrent.progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: speed indicators + seeds + total size + added date
                Row(
                  children: [
                    if (torrent.downloadSpeed > 0)
                      Text(
                        '⬇ ${formatBytes(torrent.downloadSpeed)}/s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    if (torrent.downloadSpeed > 0 && torrent.uploadSpeed > 0)
                      const SizedBox(width: 8),
                    if (torrent.uploadSpeed > 0)
                      Text(
                        '⬆ ${formatBytes(torrent.uploadSpeed)}/s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0) &&
                        (torrent.seedsConnected > 0 || torrent.seedsTotal > 0))
                      const SizedBox(width: 8),
                    if (torrent.seedsConnected > 0 || torrent.seedsTotal > 0)
                      Text(
                        '做种 ${torrent.seedsConnected}/${torrent.seedsTotal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0 ||
                            torrent.seedsConnected > 0 ||
                            torrent.seedsTotal > 0) &&
                        torrent.totalSize > 0)
                      const SizedBox(width: 8),
                    if (torrent.totalSize > 0)
                      Text(
                        formatBytes(torrent.totalSize),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0 ||
                            torrent.seedsConnected > 0 ||
                            torrent.seedsTotal > 0 ||
                            torrent.totalSize > 0) &&
                        torrent.addedAt != null)
                      const SizedBox(width: 8),
                    if (torrent.addedAt != null)
                      Text(
                        formatDateTime(torrent.addedAt, pattern: 'MM-dd'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 3: tags — 站点 / 辅种数 / 下载人数 / 异常信息
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (torrent.site != null && torrent.site!.isNotEmpty)
                      _Tag(
                        label: torrent.site!,
                        color: const Color(0xFF5856D6),
                      ),
                    if (torrent.multiSource > 0)
                      _Tag(
                        label: '辅种 ${torrent.multiSource}',
                        color: const Color(0xFF007AFF),
                      ),
                    if (torrent.leechers > 0)
                      _Tag(
                        label: '下载 ${torrent.leechers}',
                        color: const Color(0xFFFF9500),
                      ),
                    if (torrent.error != null && torrent.error!.isNotEmpty)
                      _Tag(
                        label: torrent.error!,
                        color: const Color(0xFFFF3B30),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar
                if (torrent.totalSize > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: torrent.progress,
                      minHeight: torrent.state == TorrentState.downloading
                          ? 6
                          : 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: colors.progress,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 小标签组件
class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
