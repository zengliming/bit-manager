import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/client_tile.dart';
import 'client_form_screen.dart';
import 'client_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

          final gs = stats.globalStats;
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ── Hero speed display ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                        theme.colorScheme.primary.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('下载', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: (gs.downloadSpeed / 1024 / 1024).toStringAsFixed(1),
                                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.green[700]),
                                  ),
                                  TextSpan(
                                    text: ' MB/s',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 50, color: Colors.grey.withValues(alpha: 0.2)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('上传', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: (gs.uploadSpeed / 1024 / 1024).toStringAsFixed(1),
                                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.blue[700]),
                                  ),
                                  TextSpan(
                                    text: ' MB/s',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── 客户端 ──
                Row(
                  children: [
                    Icon(Icons.dns_outlined, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text('客户端 (${clients.clients.length})',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ClientListScreen(),
                      )),
                      child: const Text('管理', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...gs.clientStatsList.map((cs) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text('还没有添加客户端',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              '添加下载客户端即可开始管理种子',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加客户端'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ClientFormScreen(),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
