import 'package:flutter/material.dart';
import '../models/rss_source.dart';

class RssSourceTile extends StatelessWidget {
  final RssSource source;
  final int? itemCount;
  final VoidCallback? onTap;

  const RssSourceTile({super.key, required this.source, this.itemCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final lastFetchedStr = source.lastFetchedAt != null
        ? '${source.lastFetchedAt!.hour.toString().padLeft(2, '0')}:${source.lastFetchedAt!.minute.toString().padLeft(2, '0')}'
        : '未刷新';

    return ListTile(
      leading: const Icon(Icons.rss_feed, color: Colors.orange),
      title: Text(source.name),
      subtitle: Text(
        '${source.url}  ·  ${itemCount ?? 0} 条  ·  $lastFetchedStr',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (source.autoDownload)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('自动', style: TextStyle(fontSize: 11, color: Colors.green)),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
