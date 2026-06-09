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

    // Border width: 1.5px for active states, 0.75px for others
    final isActiveState =
        torrent.state == TorrentState.downloading ||
        torrent.state == TorrentState.seeding ||
        torrent.state == TorrentState.paused ||
        torrent.state == TorrentState.error;
    final borderWidth = isActiveState ? 1.5 : 0.75;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: colors.border.withValues(alpha: 0.3),
            width: borderWidth,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left status bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: checkbox + name + StatusChip + progress %
                      Row(
                        children: [
                          if (selectMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, top: 2),
                              child: Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
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
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Row 2: speed indicators + seeds + total size + added date
                      Row(
                        children: [
                          if (torrent.downloadSpeed > 0)
                            Text(
                              '⬇ ${formatBytes(torrent.downloadSpeed)}/s',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          if (torrent.downloadSpeed > 0 &&
                              torrent.uploadSpeed > 0)
                            const SizedBox(width: 8),
                          if (torrent.uploadSpeed > 0)
                            Text(
                              '⬆ ${formatBytes(torrent.uploadSpeed)}/s',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          if ((torrent.downloadSpeed > 0 ||
                                  torrent.uploadSpeed > 0) &&
                              (torrent.seedsConnected > 0 ||
                                  torrent.seedsTotal > 0))
                            const SizedBox(width: 8),
                          if (torrent.seedsConnected > 0 ||
                              torrent.seedsTotal > 0)
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

                      const SizedBox(height: 6),

                      // Progress bar
                      if (torrent.totalSize > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
