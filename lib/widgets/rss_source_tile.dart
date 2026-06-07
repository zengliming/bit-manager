import 'package:flutter/material.dart';
import '../models/rss_source.dart';

class RssSourceTile extends StatelessWidget {
  final RssSource source;
  final VoidCallback? onTap;

  const RssSourceTile({super.key, required this.source, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.rss_feed, color: Colors.orange),
      title: Text(source.name),
      subtitle: Text(source.url, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
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
