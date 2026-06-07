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
          borderRadius: BorderRadius.circular(12),
          border: _hasErrors
              ? const Border(left: BorderSide(color: Color(0xFFE53935), width: 4))
              : Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
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
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFE53935),
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
                                color: Colors.grey[500],
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
                                Icon(Icons.arrow_downward,
                                    size: 14, color: const Color(0xFF4CAF50)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSpeed(stats.downloadSpeed),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_upward,
                                    size: 14, color: const Color(0xFF2196F3)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatSpeed(stats.uploadSpeed),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          '离线',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
                          color: const Color(0xFF2196F3),
                        ),
                        _StatPill(
                          label: '下载',
                          value: stats.downloadingCount.toString(),
                          color: const Color(0xFF4CAF50),
                        ),
                        _StatPill(
                          label: '错误',
                          value: stats.errorCount.toString(),
                          color: stats.errorCount > 0
                              ? const Color(0xFFE53935)
                              : Colors.grey,
                        ),
                        _StatPill(
                          label: '暂停上传',
                          value: stats.pausedUpCount.toString(),
                          color: Colors.grey,
                        ),
                        _StatPill(
                          label: '暂停下载',
                          value: stats.pausedDlCount.toString(),
                          color: Colors.grey,
                        ),
                        _StatPill(
                          label: '剩余空间',
                          value: _formatBytes(stats.freeSpace),
                          color: Colors.grey,
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
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
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
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
