import 'package:flutter/material.dart';
import '../models/stats.dart';

/// Client card for HomeScreen grid display.
/// Shows: name + status, speed, 3 stat pills, free space.
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
                  // ── Header: name + status dot ──
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stats.online ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          stats.clientName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.host}:${stats.port}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // ── Speed row ──
                  if (!_isOffline) ...[
                    Row(
                      children: [
                        Icon(Icons.arrow_downward, size: 14, color: const Color(0xFF4CAF50)),
                        const SizedBox(width: 4),
                        Text(
                          _formatSpeed(stats.downloadSpeed),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.arrow_upward, size: 14, color: const Color(0xFF2196F3)),
                        const SizedBox(width: 4),
                        Text(
                          _formatSpeed(stats.uploadSpeed),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Text(
                      '离线',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Stat pills row ──
                  if (!_isOffline) ...[
                    Row(
                      children: [
                        _StatPill(
                          label: '做种',
                          value: stats.seedingCount.toString(),
                          color: const Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 6),
                        _StatPill(
                          label: '下载',
                          value: stats.downloadingCount.toString(),
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 6),
                        _StatPill(
                          label: '错误',
                          value: stats.errorCount.toString(),
                          color: stats.errorCount > 0 ? const Color(0xFFE53935) : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Free space ──
                    Text(
                      '剩余 ${_formatBytes(stats.freeSpace)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
