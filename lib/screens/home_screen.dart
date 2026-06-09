import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../providers/client_provider.dart';
import '../widgets/client_tile.dart';
import '../widgets/speed_hero_card.dart';
import 'client_form_screen.dart';
import 'client_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bit Manager'), centerTitle: true),
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
                // ── Hero speed card ──
                SpeedHeroCard(
                  downloadSpeed: gs.downloadSpeed,
                  uploadSpeed: gs.uploadSpeed,
                ),

                const SizedBox(height: 20),

                // ── Client section header ──
                Row(
                  children: [
                    Icon(Icons.dns_outlined, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      '客户端 (${clients.clients.length})',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClientListScreen(),
                        ),
                      ),
                      child: const Text('管理', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Client list (full-width rows) ──
                ...gs.clientStatsList.map(
                  (cs) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClientTile(stats: cs),
                  ),
                ),
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
            Text(
              '还没有添加客户端',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加下载客户端即可开始管理种子',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加客户端'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientFormScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
