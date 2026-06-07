import 'package:flutter/material.dart';
import '../models/torrent.dart';
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
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: isSelected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(torrent.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 4),
                        StatusChip(state: torrent.state),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (torrent.totalSize > 0) ...[
                      Row(
                        children: [
                          Expanded(child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(value: torrent.progress, minHeight: 4),
                          )),
                          const SizedBox(width: 8),
                          Text('${(torrent.progress * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (torrent.downloadSpeed > 0)
                          Text('⬇ ${_format(torrent.downloadSpeed)}', style: TextStyle(fontSize: 12, color: Colors.green[600])),
                        if (torrent.downloadSpeed > 0 && torrent.uploadSpeed > 0) const SizedBox(width: 8),
                        if (torrent.uploadSpeed > 0)
                          Text('⬆ ${_format(torrent.uploadSpeed)}', style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                        const Spacer(),
                        Text('S: ${torrent.seedsConnected}  P: ${torrent.peersConnected}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(int bytes) {
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
  }
}
