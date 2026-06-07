import 'package:flutter/material.dart';
import '../models/torrent.dart';
import 'status_border.dart';

class StatusChip extends StatelessWidget {
  final TorrentState state;

  const StatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = statusColors(state);
    final (IconData icon, String label) = switch (state) {
      TorrentState.downloading => (Icons.download, '下载中'),
      TorrentState.metaDL      => (Icons.downloading, '获取元数据'),
      TorrentState.seeding     => (Icons.arrow_upward, '做种中'),
      TorrentState.paused      => (Icons.pause, '已暂停'),
      TorrentState.checking    => (Icons.hourglass_bottom, '校验中'),
      TorrentState.queued      => (Icons.hourglass_empty, '队列中'),
      TorrentState.error       => (Icons.error, '出错'),
      TorrentState.unknown     => (Icons.help, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: colors.border),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: colors.border, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
