import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/client_provider.dart';
import 'providers/torrent_provider.dart';
import 'providers/stats_provider.dart';
import 'services/refresh_service.dart';
import 'screens/home_screen.dart';
import 'screens/torrent_list_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/status_border.dart';
import 'models/torrent.dart';

/// Extension on [ColorScheme] to provide torrent state colors.
extension TorrentStateColorScheme on ColorScheme {
  Color torrentStateColor(TorrentState state) => statusColors(state).border;
}

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
    final torrentProvider = context.read<TorrentProvider>();
    final statsProvider = context.read<StatsProvider>();
    await clientProvider.loadClients();

    _refreshService = RefreshService(
      clientProvider: clientProvider,
      torrentProvider: torrentProvider,
      statsProvider: statsProvider,
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
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            HomeScreen(onNavigateToTorrents: () => setState(() => _currentIndex = 1)),
            const TorrentListScreen(),
            const SettingsScreen(),
          ],
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (i) => setState(() => _currentIndex = i),
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                indicatorShape: const StadiumBorder(),
                indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: '概览',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.download_outlined),
                    selectedIcon: Icon(Icons.download),
                    label: '种子',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF007AFF),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF007AFF),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF5856D6),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1C1C1E),
      surfaceContainerHighest: Color(0xFFF2F2F7),
      onSurfaceVariant: Color(0xFF8E8E93),
      outline: Color(0xFFE5E5EA),
      outlineVariant: Color(0xFFE5E5EA),
      error: Color(0xFFFF3B30),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0x0DFF3B30),
      shadow: Color(0x0F000000),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily:
          'Inter, -apple-system, BlinkMacSystemFont, .SF Pro Text, Roboto, Segoe UI, sans-serif',
      scaffoldBackgroundColor: const Color(0xFFF2F2F7),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xCCFFFFFF),
        foregroundColor: Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF1C1C1E),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8E8E93),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 24, color: Color(0xFF007AFF));
          }
          return const IconThemeData(size: 22, color: Color(0xFF8E8E93));
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x0F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x1F3C3C43),
        thickness: 0.5,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        circularTrackColor: Color(0xFFE5E5EA),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF0A84FF),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFF0A84FF),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF5E5CE6),
      onSecondary: Color(0xFFFFFFFF),
      surface: Color(0xFF1C1C1E),
      onSurface: Color(0xFFFFFFFF),
      surfaceContainerHighest: Color(0xFF2C2C2E),
      onSurfaceVariant: Color(0xFF98989D),
      outline: Color(0xFF38383A),
      outlineVariant: Color(0xFF38383A),
      error: Color(0xFFFF453A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0x0DFF453A),
      shadow: Color(0x0F000000),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily:
          'Inter, -apple-system, BlinkMacSystemFont, .SF Pro Text, Roboto, Segoe UI, sans-serif',
      scaffoldBackgroundColor: const Color(0xFF000000),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Color(0xB31C1C1E),
        foregroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        indicatorShape: const StadiumBorder(),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A84FF),
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0xFF98989D),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 24, color: Color(0xFF0A84FF));
          }
          return const IconThemeData(size: 22, color: Color(0xFF98989D));
        }),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1C1C1E),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x3338383A),
        thickness: 0.5,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        circularTrackColor: Color(0xFF2C2C2E),
      ),
    );
  }
}
