import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/client_provider.dart';
import 'providers/rss_provider.dart';
import 'providers/torrent_provider.dart';
import 'providers/stats_provider.dart';
import 'services/refresh_service.dart';
import 'screens/home_screen.dart';
import 'screens/rss_sources_screen.dart';
import 'screens/torrent_list_screen.dart';
import 'screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  RefreshService? _refreshService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final clientProvider = context.read<ClientProvider>();
    final rssProvider = context.read<RssProvider>();
    final torrentProvider = context.read<TorrentProvider>();
    final statsProvider = context.read<StatsProvider>();
    await clientProvider.loadClients();
    await rssProvider.loadSources();

    _refreshService = RefreshService(
      clientProvider: clientProvider,
      torrentProvider: torrentProvider,
      statsProvider: statsProvider,
      rssProvider: rssProvider,
    );
    _refreshService!.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshService?.start();
      _refreshService?.refreshNow();
    } else if (state == AppLifecycleState.paused) {
      _refreshService?.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshService?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bit Manager',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: const [
            HomeScreen(),
            RssSourcesScreen(),
            TorrentListScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '概览'),
            NavigationDestination(icon: Icon(Icons.rss_feed_outlined), selectedIcon: Icon(Icons.rss_feed), label: 'RSS'),
            NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download), label: '种子'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
          ],
        ),
      ),
    );
  }
}
