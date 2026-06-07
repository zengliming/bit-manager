import 'package:flutter/material.dart';
import '../models/stats.dart';

class ClientTile extends StatelessWidget {
  final ClientStats stats;

  const ClientTile({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        leading: Icon(
          stats.online ? Icons.check_circle : Icons.error,
          color: stats.online ? Colors.green : Colors.red,
        ),
        title: Text(stats.clientName),
        subtitle: Text('${stats.torrentCount} torrents'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('DL: ${(stats.downloadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                style: const TextStyle(fontSize: 12, color: Colors.green)),
            Text('UL: ${(stats.uploadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                style: const TextStyle(fontSize: 12, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}
