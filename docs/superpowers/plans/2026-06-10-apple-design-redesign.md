# Apple 风格重设计 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Bit Manager 整体视觉风格向 Apple 最新设计语言靠齐，保持 Material 骨架，自定义色彩、导航、卡片、排版。

**Architecture:** 从下往上逐层替换——先更新色彩常量（status_border），再替换全局主题（app.dart），最后逐个刷新组件和页面。

**Tech Stack:** Flutter + Material 3 + Provider

---

### Task 1: 更新状态色彩常量

**Files:**
- Modify: `lib/widgets/status_border.dart`

- [ ] **Step 1: 替换状态色值为 Apple 语义色**

```dart
import 'package:flutter/material.dart';
import '../models/torrent.dart';

/// Holds the three color values for a torrent state visual treatment.
class StatusColors {
  final Color border;
  final Color background;
  final Color progress;

  const StatusColors({
    required this.border,
    required this.background,
    required this.progress,
  });
}

/// Returns the [StatusColors] for the given [TorrentState].
StatusColors statusColors(TorrentState state) {
  return switch (state) {
    TorrentState.downloading => const StatusColors(
      border: Color(0xFF34C759),
      background: Color(0x0D34C759),
      progress: Color(0xFF34C759),
    ),
    TorrentState.seeding => const StatusColors(
      border: Color(0xFF007AFF),
      background: Color(0x0D007AFF),
      progress: Color(0xFF007AFF),
    ),
    TorrentState.paused => const StatusColors(
      border: Color(0xFFFF9500),
      background: Color(0x0DFF9500),
      progress: Color(0xFFFF9500),
    ),
    TorrentState.error => const StatusColors(
      border: Color(0xFFFF3B30),
      background: Color(0x0DFF3B30),
      progress: Color(0xFFFF3B30),
    ),
    TorrentState.unknown => const StatusColors(
      border: Color(0xFFFF3B30),
      background: Color(0x0DFF3B30),
      progress: Color(0xFFFF3B30),
    ),
    _ => const StatusColors(
      border: Color(0xFF8E8E93),
      background: Colors.transparent,
      progress: Color(0xFF8E8E93),
    ),
  };
}
```

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

Expected: 无新增错误。

---

### Task 2: 重构全局主题 — 色彩方案与排版

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: 替换 `_buildLightTheme` 中的 ColorScheme 和基础主题**

```dart
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
      fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, .SF Pro Text, Roboto, Segoe UI, sans-serif',
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
```

- [ ] **Step 2: 替换 `_buildDarkTheme` 中的 ColorScheme 和基础主题**

```dart
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
      fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, .SF Pro Text, Roboto, Segoe UI, sans-serif',
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
```

- [ ] **Step 3: 替换底部导航栏为毛玻璃效果**

将 `build` 方法中的 `bottomNavigationBar` 替换为：

```dart
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
```

同时需要在文件顶部添加 `import 'dart:ui';`：

```dart
import 'dart:ui';
```

- [ ] **Step 4: 更新 AppBar 同样使用毛玻璃**

所有页面中的 AppBar 已通过主题设置了半透明背景（`Color(0xCCFFFFFF)`），但需要确保各页面的 Scaffold 使用 `extendBodyBehindAppBar: true` 或至少 AppBar 背景有透明感。由于 Flutter Material 3 的 AppBar 本身不直接支持毛玻璃，我们通过主题中的 `backgroundColor` 半透明 + `surfaceTintColor: Colors.transparent` 来模拟。这一步不需要改动各页面代码——主题已处理。

- [ ] **Step 5: 运行分析确认无错误**

```
flutter analyze
```

Expected: 无新增错误。

---

### Task 3: 更新 SpeedHeroCard

**Files:**
- Modify: `lib/widgets/speed_hero_card.dart`

- [ ] **Step 1: 替换 SpeedHeroCard 样式**

```dart
import 'package:flutter/material.dart';

/// Hero speed display card for HomeScreen.
/// Shows download/upload speeds with large numbers and icons.
class SpeedHeroCard extends StatelessWidget {
  final int downloadSpeed; // bytes/s
  final int uploadSpeed; // bytes/s

  const SpeedHeroCard({
    super.key,
    required this.downloadSpeed,
    required this.uploadSpeed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.10),
            theme.colorScheme.primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SpeedColumn(
              icon: Icons.arrow_downward,
              iconColor: const Color(0xFF34C759),
              label: '下载',
              speed: downloadSpeed,
              textColor: const Color(0xFF248A3D),
            ),
          ),
          Container(
            width: 1,
            height: 56,
            color: theme.dividerColor,
          ),
          Expanded(
            child: _SpeedColumn(
              icon: Icons.arrow_upward,
              iconColor: const Color(0xFF007AFF),
              label: '上传',
              speed: uploadSpeed,
              textColor: const Color(0xFF0056CC),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int speed;
  final Color textColor;

  const _SpeedColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.speed,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: _formatSpeed(speed),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatSpeed(int bytes) {
    if (bytes <= 0) return '0 KB/s';
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB/s';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)}GB/s';
  }
}
```

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 4: 更新 ClientTile 卡片样式

**Files:**
- Modify: `lib/widgets/client_tile.dart`

- [ ] **Step 1: 替换 build 方法中的 Container 样式**

将 `build` 方法中 Container 的 decoration 替换为：

```dart
    return Opacity(
      opacity: _isOffline ? 0.55 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: _hasErrors
              ? const Border(
                  left: BorderSide(color: Color(0xFFFF3B30), width: 4),
                )
              : null,
          color: theme.cardColor,
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _isOffline ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
```

- [ ] **Step 2: 更新状态色值和排版**

更新 ClientTile 内部的色值引用：
- 在线圆点：`const Color(0xFF34C759)`（替换 `0xFF4CAF50`）
- 离线圆点：`const Color(0xFFFF3B30)`（替换 `0xFFE53935`）
- 下载速度文字：`const Color(0xFF248A3D)`
- 上传速度文字：`const Color(0xFF0056CC)`
- 标题：`fontSize: 15, fontWeight: FontWeight.w600`
- 地址文字：`fontSize: 12, fontWeight: FontWeight.w400`
- _StatPill 中文字：`fontSize: 11, fontWeight: FontWeight.w400`
- _StatPill 中数值：`fontSize: 12, fontWeight: FontWeight.w600`

色值常量统一替换：

```
0xFF4CAF50 → 0xFF34C759（绿）
0xFF2E7D32 → 0xFF248A3D（深绿）
0xFF2196F3 → 0xFF007AFF（蓝）
0xFF1565C0 → 0xFF0056CC（深蓝）
0xFFE53935 → 0xFFFF3B30（红）
0xFF9C27B0 → 0xFFAF52DE（紫）
0xFF607D8B → 0xFF8E8E93（灰）
```

- [ ] **Step 3: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 5: 更新 TorrentTile — 移除左侧色条改圆点

**Files:**
- Modify: `lib/widgets/torrent_tile.dart`

- [ ] **Step 1: 重写 build 方法**

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = statusColors(torrent.state);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: state dot + checkbox + name + StatusChip + progress %
                Row(
                  children: [
                    // State dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (selectMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          isSelected
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        torrent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusChip(state: torrent.state),
                    if (torrent.state == TorrentState.downloading ||
                        torrent.state == TorrentState.seeding) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${(torrent.progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: speed indicators + seeds + total size + added date
                Row(
                  children: [
                    if (torrent.downloadSpeed > 0)
                      Text(
                        '⬇ ${formatBytes(torrent.downloadSpeed)}/s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF34C759),
                        ),
                      ),
                    if (torrent.downloadSpeed > 0 &&
                        torrent.uploadSpeed > 0)
                      const SizedBox(width: 8),
                    if (torrent.uploadSpeed > 0)
                      Text(
                        '⬆ ${formatBytes(torrent.uploadSpeed)}/s',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0) &&
                        (torrent.seedsConnected > 0 ||
                            torrent.seedsTotal > 0))
                      const SizedBox(width: 8),
                    if (torrent.seedsConnected > 0 ||
                        torrent.seedsTotal > 0)
                      Text(
                        '做种 ${torrent.seedsConnected}/${torrent.seedsTotal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0 ||
                            torrent.seedsConnected > 0 ||
                            torrent.seedsTotal > 0) &&
                        torrent.totalSize > 0)
                      const SizedBox(width: 8),
                    if (torrent.totalSize > 0)
                      Text(
                        formatBytes(torrent.totalSize),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if ((torrent.downloadSpeed > 0 ||
                            torrent.uploadSpeed > 0 ||
                            torrent.seedsConnected > 0 ||
                            torrent.seedsTotal > 0 ||
                            torrent.totalSize > 0) &&
                        torrent.addedAt != null)
                      const SizedBox(width: 8),
                    if (torrent.addedAt != null)
                      Text(
                        formatDateTime(torrent.addedAt, pattern: 'MM-dd'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar
                if (torrent.totalSize > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: torrent.progress,
                      minHeight: torrent.state == TorrentState.downloading
                          ? 6
                          : 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: colors.progress,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 6: 更新 StatusChip

**Files:**
- Modify: `lib/widgets/status_chip.dart`

- [ ] **Step 1: 替换 build 方法**

```dart
  @override
  Widget build(BuildContext context) {
    final colors = statusColors(state);
    final (IconData icon, String label) = switch (state) {
      TorrentState.downloading => (Icons.download, '下载中'),
      TorrentState.metaDL => (Icons.downloading, '获取元数据'),
      TorrentState.seeding => (Icons.arrow_upward, '做种中'),
      TorrentState.paused => (Icons.pause, '已暂停'),
      TorrentState.checking => (Icons.hourglass_bottom, '校验中'),
      TorrentState.queued => (Icons.hourglass_empty, '队列中'),
      TorrentState.error => (Icons.error, '出错'),
      TorrentState.unknown => (Icons.help, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: colors.border),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colors.border,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 7: 更新 StatsCard

**Files:**
- Modify: `lib/widgets/stats_card.dart`

- [ ] **Step 1: 替换 build 方法**

```dart
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
```

移除 Card 的 `elevation: 2`。

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 8: 更新 EmptyState

**Files:**
- Modify: `lib/widgets/empty_state.dart`

- [ ] **Step 1: 替换 build 方法**

```dart
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFC7C7CC)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8E8E93),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Color(0xFFC7C7CC),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 9: 更新 HomeScreen 间距

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: 调整间距和排版**

将 ListView padding 从 `EdgeInsets.fromLTRB(16, 8, 16, 24)` 改为 `EdgeInsets.fromLTRB(20, 8, 20, 24)`。

将客户端列表间距从 `bottom: 12` 改为 `bottom: 8`。

将 section header 的标题文字从 `fontSize: 15` 改为 `fontSize: 17`。

将 "管理" 按钮从 `fontSize: 13` 改为 `fontSize: 14`。

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 10: 更新 TorrentListScreen 筛选栏

**Files:**
- Modify: `lib/screens/torrent_list_screen.dart`

- [ ] **Step 1: 替换筛选栏样式**

将 `_buildFilterBar` 中的 `padding` 从 `EdgeInsets.symmetric(horizontal: 12, vertical: 8)` 改为 `EdgeInsets.symmetric(horizontal: 20, vertical: 12)`。

将筛选 chip 的圆角从 `20` 改为 `10`。

将选中 chip 颜色从 `colorScheme.primaryContainer` 改为 `colorScheme.primary.withValues(alpha: 0.12)`。

将选中文字颜色从 `colorScheme.onPrimaryContainer` 改为 `colorScheme.primary`。

- [ ] **Step 2: 调整列表间距**

将 ListView padding 从 `EdgeInsets.symmetric(horizontal: 8)` 改为 `EdgeInsets.symmetric(horizontal: 20)`。

- [ ] **Step 3: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 11: 更新 TorrentDetailScreen 卡片与按钮

**Files:**
- Modify: `lib/screens/torrent_detail_screen.dart`

- [ ] **Step 1: 更新 _buildSection 卡片样式**

```dart
  Widget _buildSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 2: 更新操作按钮样式**

将 `_actionButton` 的圆角从 `10` 改为 `14`。

- [ ] **Step 3: 更新 _statItem 圆角**

将 `_statItem` 的圆角从 `8` 改为 `10`。

- [ ] **Step 4: 更新进度条圆角**

将 `ClipRRect` 的 `borderRadius` 从 `8` 改为 `6`。

- [ ] **Step 5: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 12: 更新 SettingsScreen

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: 调整卡片间距**

将 `SizedBox(height: 8)` 改为 `SizedBox(height: 12)`（RSS 条目已移除，只剩客户端管理和关于两个卡片之间的间距）。

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 13: 更新 ClientListScreen

**Files:**
- Modify: `lib/screens/client_list_screen.dart`

- [ ] **Step 1: 调整间距和状态色值**

将 ListView padding 从 `EdgeInsets.all(16)` 改为 `EdgeInsets.all(20)`。

将在线绿色 `0xFF4CAF50` 替换为 `0xFF34C759`，离线红色 `0xFFE53935` 替换为 `0xFFFF3B30`。

将 `Card` 的 `elevation` 去掉，让它使用主题默认的 `cardTheme`。

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 14: 更新 ClientFormScreen

**Files:**
- Modify: `lib/screens/client_form_screen.dart`

- [ ] **Step 1: 调整间距**

将 `SingleChildScrollView` 的 padding 从 `EdgeInsets.all(16)` 改为 `EdgeInsets.all(20)`。

将各字段之间的 `SizedBox(height: 16)` 保持不变（已在 8px 网格中）。

- [ ] **Step 2: 运行分析确认无错误**

```
flutter analyze
```

---

### Task 15: 最终验证

- [ ] **Step 1: 运行完整分析**

```
flutter analyze
```

Expected: 无新增错误。

- [ ] **Step 2: 运行测试**

```
flutter test
```

Expected: 所有测试通过。

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "refactor: 视觉风格全面向 Apple 设计语言靠齐"
```
