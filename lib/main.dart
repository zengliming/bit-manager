import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/client_provider.dart';
import 'providers/torrent_provider.dart';
import 'providers/stats_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BitManagerApp());
}

class BitManagerApp extends StatelessWidget {
  const BitManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClientProvider()),
        ChangeNotifierProvider(create: (_) => TorrentProvider()),
        ChangeNotifierProvider(create: (_) => StatsProvider()),
      ],
      child: const AppShell(),
    );
  }
}
