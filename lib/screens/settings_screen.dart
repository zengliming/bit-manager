import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/client_provider.dart';
import '../providers/rss_provider.dart';
import 'client_list_screen.dart';
import 'rss_sources_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 客户端管理入口
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('客户端管理'),
              subtitle: Consumer<ClientProvider>(
                builder: (_, cp, __) => Text('${cp.clients.length} 个客户端'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientListScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // RSS 订阅源管理
          Card(
            child: ListTile(
              leading: const Icon(Icons.rss_feed, color: Colors.orange),
              title: const Text('RSS 订阅源'),
              subtitle: Consumer<RssProvider>(
                builder: (_, rp, __) => Text('${rp.sources.length} 个订阅源'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RssSourcesScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 关于
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bit Manager'),
              subtitle: Text('版本 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}
