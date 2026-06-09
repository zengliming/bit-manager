import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';
import 'client_form_screen.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('客户端管理')),
      body: Consumer<ClientProvider>(
        builder: (context, provider, _) {
          if (provider.clients.isEmpty) {
            return const Center(child: Text('还没有添加客户端'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.clients.length,
            itemBuilder: (context, index) {
              final client = provider.clients[index];
              final online = provider.isOnline(client.id);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: online
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    child: Icon(
                      client.type == ClientType.qBittorrent
                          ? Icons.download
                          : Icons.wifi,
                      color: online ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(client.name),
                  subtitle: Text(
                    '${client.host}:${client.port}\n${client.type == ClientType.qBittorrent ? "qBittorrent" : "Transmission"}',
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                      const PopupMenuItem(value: 'test', child: Text('测试连接')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                    onSelected: (action) async {
                      switch (action) {
                        case 'edit':
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClientFormScreen(client: client),
                            ),
                          );
                        case 'test':
                          final ok = await provider.testConnection(client);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ok ? '连接成功' : '连接失败')),
                            );
                          }
                        case 'delete':
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('删除客户端'),
                              content: Text('确定要删除 "${client.name}" 吗？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    '删除',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteClient(client.id);
                          }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClientFormScreen()),
        ),
      ),
    );
  }
}
