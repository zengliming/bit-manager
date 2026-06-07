import 'package:flutter/material.dart';
import '../models/stats.dart';
import '../models/client_config.dart';

class ClientTile extends StatelessWidget {
  final ClientStats stats;
  final VoidCallback? onTap;

  const ClientTile({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOffline = !stats.online;
    final hasErrors = stats.errorCount > 0;

    return Opacity(
      opacity: isOffline ? 0.55 : 1.0,
      child: AbsorbPointer(
        absorbing: isOffline,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: hasErrors
                ? const Border(
                    left: BorderSide(color: Color(0xFFE53935), width: 4),
                  )
                : null,
            color: Theme.of(context).cardColor,
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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: isOffline ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: name/host left, speeds right ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: stats.online ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(stats.clientName,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${stats.host}:${stats.port}  ${stats.type == ClientType.qBittorrent ? "qBittorrent" : "Transmission"}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_circle_down, size: 14, color: Colors.green[600]),
                                const SizedBox(width: 4),
                                Text(_formatSpeed(stats.downloadSpeed),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.green[800])),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_circle_up, size: 14, color: Colors.blue[600]),
                                const SizedBox(width: 4),
                                Text(_formatSpeed(stats.uploadSpeed),
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.blue[800])),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── Row 1: high priority, small colored pills ──
                    Row(
                      children: [
                        _pill('在线', stats.online ? '是' : '否', stats.online ? Colors.green : Colors.red),
                        const SizedBox(width: 8),
                        _pill('下载', '${stats.downloadingCount}', Colors.green),
                        const SizedBox(width: 8),
                        _pill('做种', '${stats.seedingCount}', Colors.blue),
                        const SizedBox(width: 8),
                        _pill('错误', '${stats.errorCount}', stats.errorCount > 0 ? Colors.red : Colors.grey),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ── Row 2: medium priority ──
                    Row(
                      children: [
                        _simpleStat('暂停上传', '${stats.pausedUpCount}'),
                        const SizedBox(width: 10),
                        _simpleStat('暂停下载', '${stats.pausedDlCount}'),
                        const SizedBox(width: 10),
                        _simpleStat('校验中', '${stats.checkingCount}'),
                        const SizedBox(width: 10),
                        _simpleStat('等待中', '${stats.waitingCount}'),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ── Row 3: limits and space ──
                    Row(
                      children: [
                        _simpleStat('上传限速', stats.uploadLimit > 0 ? '${(stats.uploadLimit / 1024 / 1024).toStringAsFixed(0)}MB/s' : '不限'),
                        const SizedBox(width: 10),
                        _simpleStat('下载限速', stats.downloadLimit > 0 ? '${(stats.downloadLimit / 1024 / 1024).toStringAsFixed(0)}MB/s' : '不限'),
                        const SizedBox(width: 10),
                        _simpleStat('剩余空间', _formatBytes(stats.freeSpace)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Small colored pill container: label + colored value
  Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ',
              style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  /// Simple label + value pair without background
  Widget _simpleStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[800]),
        ),
      ],
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
