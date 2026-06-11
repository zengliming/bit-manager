import 'package:flutter/material.dart';
import '../models/stats.dart';

/// Client tile for HomeScreen — full-width horizontal card.
/// Layout: name+host on left, speed on right, stats pills below.
class ClientTile extends StatelessWidget {
  final ClientStats stats;
  final VoidCallback? onTap;

  const ClientTile({super.key, required this.stats, this.onTap});

  bool get _isOffline => !stats.online;
  bool get _hasErrors => stats.errorCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: _isOffline ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: _hasErrors
              ? const Border(
                  left: BorderSide(color: Color(0xFFFF3B30), width: 4),
                )
              : null,
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isOffline ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: name+host (left) + speed (right) ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: name + host
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stats.online
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF3B30),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  stats.clientName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${stats.host}:${stats.port}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right: speed
                      if (!_isOffline) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_downward,
                                  size: 14,
                                  color: const Color(0xFF34C759),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSpeed(stats.downloadSpeed),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF248A3D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_upward,
                                  size: 14,
                                  color: const Color(0xFF007AFF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSpeed(stats.uploadSpeed),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0056CC),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '离线',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Row 2: stat pills ──
                  if (!_isOffline) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _StatPill(
                          label: '做种',
                          value: stats.seedingCount.toString(),
                          color: const Color(0xFF007AFF),
                        ),
                        _StatPill(
                          label: '下载',
                          value: stats.downloadingCount.toString(),
                          color: const Color(0xFF34C759),
                        ),
                        _StatPill(
                          label: '上传',
                          value: stats.uploadingCount.toString(),
                          color: const Color(0xFF007AFF),
                        ),
                        _StatPill(
                          label: '错误',
                          value: stats.errorCount.toString(),
                          color: stats.errorCount > 0
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFF8E8E93),
                        ),
                        _StatPill(
                          label: '校验',
                          value: stats.checkingCount.toString(),
                          color: const Color(0xFFAF52DE),
                        ),
                        _StatPill(
                          label: '等待',
                          value: stats.waitingCount.toString(),
                          color: const Color(0xFF8E8E93),
                        ),
                        _StatPill(
                          label: '暂停上传',
                          value: stats.pausedUpCount.toString(),
                          color: const Color(0xFF8E8E93),
                        ),
                        _StatPill(
                          label: '暂停下载',
                          value: stats.pausedDlCount.toString(),
                          color: const Color(0xFF8E8E93),
                        ),
                        _StatPill(
                          label: '剩余空间',
                          value: _formatBytes(stats.freeSpace),
                          color: const Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatSpeed(int bytes) {
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
