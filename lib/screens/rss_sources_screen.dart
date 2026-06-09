import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/rss_provider.dart';
import '../widgets/rss_source_tile.dart';
import 'rss_source_form_screen.dart';
import 'rss_items_screen.dart';

class RssSourcesScreen extends StatelessWidget {
  const RssSourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RSS 订阅')),
      body: Consumer<RssProvider>(
        builder: (context, provider, _) {
          if (provider.sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rss_feed, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '还没有添加 RSS 订阅源',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // RSS auto-refresh handled by RefreshService
            },
            child: ListView.builder(
              itemCount: provider.sources.length,
              itemBuilder: (context, index) {
                final source = provider.sources[index];
                return RssSourceTile(
                  source: source,
                  itemCount: provider.getItems(source.id).length,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RssItemsScreen(source: source),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RssSourceFormScreen()),
        ),
      ),
    );
  }
}
