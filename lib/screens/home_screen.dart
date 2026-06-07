import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/stats_card.dart';
import '../widgets/client_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bit Manager'),
        centerTitle: true,
      ),
      body: Consumer2<StatsProvider, ClientProvider>(
        builder: (context, stats, clients, _) {
          if (clients.clients.isEmpty) {
            return _buildEmptyState(context);
          }

          final globalStats = stats.globalStats;
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh is handled by RefreshService
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: StatsCard(
                      icon: Icons.download,
                      label: '下载',
                      value: '${(globalStats.downloadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                      color: Colors.green,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatsCard(
                      icon: Icons.upload,
                      label: '上传',
                      value: '${(globalStats.uploadSpeed / 1024 / 1024).toStringAsFixed(1)} MB/s',
                      color: Colors.blue,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatsCard(
                      icon: Icons.downloading,
                      label: '活动种子',
                      value: '${globalStats.activeTorrents} / ${globalStats.totalTorrents}',
                      color: Colors.orange,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatsCard(
                      icon: Icons.storage,
                      label: '磁盘占用',
                      value: '${(globalStats.totalSizeOnDisk / 1024 / 1024 / 1024).toStringAsFixed(1)} GB',
                      color: Colors.purple,
                    )),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('客户端', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...globalStats.clientStatsList.map((cs) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClientTile(stats: cs),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('还没有添加客户端', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            '在设置中添加客户端即可开始使用',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
