import 'package:flutter/material.dart';
import '../models/torrent.dart';

class StatusChip extends StatelessWidget {
  final TorrentState state;

  const StatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (state) {
      TorrentState.downloading => (Colors.blue, '下载中'),
      TorrentState.metaDL      => (Colors.lightBlue, '获取元数据'),
      TorrentState.seeding     => (Colors.green, '做种中'),
      TorrentState.paused      => (Colors.orange, '已暂停'),
      TorrentState.checking    => (Colors.purple, '校验中'),
      TorrentState.queued      => (Colors.grey, '队列中'),
      TorrentState.error       => (Colors.red, '出错'),
      TorrentState.unknown     => (Colors.grey, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
