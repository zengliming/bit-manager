# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Bit Manager UI to surface errors and active downloads with clear visual priority, enabling fast scanning of client status and torrent health.

**Architecture:** Each screen/widget is a self-contained design unit. Modifications are focused on visual hierarchy (colors, borders, typography) and layout density. No data model changes. New `StatusBorder` widget encapsulates the state-to-color logic shared by TorrentTile and TorrentDetailScreen.

**Tech Stack:** Flutter (Material 3), existing Provider state management, no new dependencies.

---

## File Map

```
lib/
├── widgets/
│   ├── client_tile.dart      # MODIFY — redesign 12-item layout, error red bar
│   ├── torrent_tile.dart     # MODIFY — status borders, compact layout
│   ├── status_chip.dart      # MODIFY — add red variant for error tab badge
│   └── status_border.dart    # CREATE — shared status→border/background color mapper
├── screens/
│   ├── home_screen.dart      # MODIFY — add global speed hero section
│   └── torrent_list_screen.dart  # MODIFY — add state TabBar (全部/下载中/错误异常/做种中)
└── app.dart                  # MODIFY — theme adjustments (color constants)
```

---

## Tasks

### Task 1: Create StatusBorder widget (shared color mapper)

**Files:**
- Create: `lib/widgets/status_border.dart`

- [ ] **Step 1: Write the widget**

```dart
import 'package:flutter/material.dart';
import '../models/torrent.dart';

/// Maps TorrentState to (borderColor, backgroundColor, progressColor).
/// Used by TorrentTile and TorrentDetailScreen to achieve consistent
/// per-state visual treatment.
(StatusColor border, StatusColor background, StatusColor progress)
    getStatusColors(TorrentState state) {
  return switch (state) {
    TorrentState.downloading => (
        StatusColor(Color(0xFF4CAF50)),
        StatusColor(Color(0xFF4CAF50).withValues(alpha: 0.05)),
        Color(0xFF4CAF50),
      ),
    TorrentState.seeding => (
        StatusColor(Color(0xFF2196F3)),
        StatusColor(Color(0xFF2196F3).withValues(alpha: 0.05)),
        Color(0xFF2196F3),
      ),
    TorrentState.paused => (
        StatusColor(Color(0xFFFF9800)),
        StatusColor(Color(0xFFFF9800).withValues(alpha: 0.05)),
        Color(0xFFFF9800),
      ),
    TorrentState.error ||
    TorrentState.unknown =>
      (
        StatusColor(Color(0xFFE53935)),
        StatusColor(Color(0xFFE53935).withValues(alpha: 0.05)),
        Color(0xFFE53935),
      ),
    _ => (
        StatusColor(Color(0xFF9E9E9E)),
        StatusColor(Colors.transparent),
        Color(0xFF9E9E9E),
      ),
  };
}

class StatusColor {
  final Color color;
  const StatusColor(this.color);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/status_border.dart
git commit -m "feat(ui): add StatusBorder color mapper widget"
```

---

### Task 2: Redesign ClientTile — 12-item layout with error red bar

**Files:**
- Modify: `lib/widgets/client_tile.dart`

- [ ] **Step 1: Read current file to confirm structure**

```bash
cat lib/widgets/client_tile.dart
```

- [ ] **Step 2: Replace ClientTile with redesigned version**

```dart
import 'package:flutter/material.dart';
import '../models/stats.dart';
import '../models/client_config.dart';

class ClientTile extends StatelessWidget {
  final ClientStats stats;
  final VoidCallback? onTap;

  const ClientTile({super.key, required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOffline = !stats.online;
    final hasErrors = stats.errorCount > 0;

    return Opacity(
      opacity: isOffline ? 0.55 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isOffline ? null : onTap,
          child: Row(
            children: [
              // Error red bar
              if (hasErrors)
                Container(
                  width: 4,
                  height: 110,
                  color: const Color(0xFFE53935),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: name + speed ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: stats.online
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFFE53935),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      stats.clientName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${stats.host}:${stats.port}  ${stats.type == ClientType.qBittorrent ? "qBittorrent" : "Transmission"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_circle_down,
                                      size: 14, color: Color(0xFF4CAF50)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatSpeed(stats.downloadSpeed),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_circle_up,
                                      size: 14, color: Color(0xFF2196F3)),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatSpeed(stats.uploadSpeed),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      // ── Row 1: high priority ──
                      _buildRow1(),
                      const SizedBox(height: 4),
                      // ── Row 2: medium ──
                      _buildRow2(),
                      const SizedBox(height: 4),
                      // ── Row 3: limits/space ──
                      _buildRow3(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow1() {
    return Row(
      children: [
        _statChip('在线', stats.online ? '是' : '否',
            stats.online ? const Color(0xFF4CAF50) : const Color(0xFFE53935)),
        const SizedBox(width: 8),
        _statChip('下载', '${stats.downloadingCount}', const Color(0xFF4CAF50)),
        const SizedBox(width: 8),
        _statChip('做种', '${stats.seedingCount}', const Color(0xFF2196F3)),
        const SizedBox(width: 8),
        _statChip('错误', '${stats.errorCount}',
            stats.errorCount > 0 ? const Color(0xFFE53935) : null),
      ],
    );
  }

  Widget _buildRow2() {
    return Row(
      children: [
        _statChip('暂停上传', '${stats.pausedUpCount}', null),
        const SizedBox(width: 8),
        _statChip('暂停下载', '${stats.pausedDlCount}', null),
        const SizedBox(width: 8),
        _statChip('校验中', '${stats.checkingCount}', null),
        const SizedBox(width: 8),
        _statChip('等待中', '${stats.waitingCount}', null),
      ],
    );
  }

  Widget _buildRow3() {
    return Row(
      children: [
        _statChip('上传限速',
            stats.uploadLimit > 0 ? '${(stats.uploadLimit / 1024 / 1024).toStringAsFixed(0)}MB/s' : '不限',
            null),
        const SizedBox(width: 8),
        _statChip('下载限速',
            stats.downloadLimit > 0 ? '${(stats.downloadLimit / 1024 / 1024).toStringAsFixed(0)}MB/s' : '不限',
            null),
        const SizedBox(width: 8),
        _statChip('剩余空间', _formatBytes(stats.freeSpace), null),
      ],
    );
  }

  Widget _statChip(String label, String value, Color? color) {
    final textColor = color ?? Colors.grey[700]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytes) {
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/client_tile.dart
git commit -m "feat(ui): redesign ClientTile with 12-item chip layout and error red bar"
```

---

### Task 3: Redesign HomeScreen — global speed hero section

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Replace HomeScreen speed section**

Find this block in home_screen.dart:
```dart
// ── 速度概览 ──
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    gradient: LinearGradient(...)
```

Replace with:
```dart
// ── 全局速度 Hero ──
Container(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    border: Border.all(
      color: theme.colorScheme.primary.withValues(alpha: 0.15),
    ),
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下载', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${(gs.downloadSpeed / 1024 / 1024).toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2E7D32),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Text('MB/s',
                    style: TextStyle(fontSize: 14, color: Colors.green[700])),
              ],
            ),
          ],
        ),
      ),
      Container(
        width: 1,
        height: 44,
        color: Colors.grey.withValues(alpha: 0.2),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('上传', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${(gs.uploadSpeed / 1024 / 1024).toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1565C0),
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('MB/s',
                      style: TextStyle(fontSize: 14, color: Colors.blue[700])),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(ui): redesign HomeScreen with large-speed hero section"
```

---

### Task 4: Redesign TorrentTile — status borders and compact layout

**Files:**
- Modify: `lib/widgets/torrent_tile.dart`

- [ ] **Step 1: Rewrite TorrentTile**

```dart
import 'package:flutter/material.dart';
import '../models/torrent.dart';
import '../utils/helpers.dart';
import 'status_chip.dart';
import 'status_border.dart';

class TorrentTile extends StatelessWidget {
  final Torrent torrent;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TorrentTile({
    super.key,
    required this.torrent,
    this.isSelected = false,
    this.selectMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = getStatusColors(torrent.state);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colors.border.color.withValues(alpha: 0.3),
          width: torrent.state == TorrentState.downloading ||
                  torrent.state == TorrentState.seeding ||
                  torrent.state == TorrentState.paused ||
                  torrent.state == TorrentState.error
              ? 1.5
              : 0.75,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: colors.background.color,
          ),
          child: Row(
            children: [
              // Left status bar
              Container(
                width: 4,
                height: 80,
                color: colors.border.color,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      selectMode ? 8 : 12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Row 1: name + progress ──
                      Row(
                        children: [
                          if (selectMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, top: 2),
                              child: Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                                size: 20,
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
                        ],
                      ),
                      // ── Row 2: progress bar (only for active states) ──
                      if (torrent.totalSize > 0 &&
                          (torrent.state == TorrentState.downloading ||
                              torrent.state == TorrentState.seeding)) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: torrent.progress,
                                  minHeight: torrent.state ==
                                          TorrentState.downloading
                                      ? 6
                                      : 4,
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                  color: colors.progress.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 46,
                              child: Text(
                                '${(torrent.progress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.border.color,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      // ── Row 3: speed + size + seeds ──
                      Row(
                        children: [
                          if (torrent.downloadSpeed > 0)
                            _infoLabel(
                              '⬇ ${_formatSpeed(torrent.downloadSpeed)}',
                              const Color(0xFF4CAF50),
                            ),
                          if (torrent.downloadSpeed > 0 &&
                              torrent.uploadSpeed > 0)
                            const SizedBox(width: 8),
                          if (torrent.uploadSpeed > 0)
                            _infoLabel(
                              '⬆ ${_formatSpeed(torrent.uploadSpeed)}',
                              const Color(0xFF2196F3),
                            ),
                          const Spacer(),
                          _infoLabel(
                            '做种 ${torrent.seedsConnected}/${torrent.seedsTotal}',
                            theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          if (torrent.totalSize > 0)
                            _infoLabel(
                              formatBytes(torrent.totalSize),
                              theme.colorScheme.onSurfaceVariant,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            formatDateTime(torrent.addedAt,
                                pattern: 'MM-dd'),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoLabel(String text, Color color) {
    return Text(text, style: TextStyle(fontSize: 11, color: color));
  }

  String _formatSpeed(int bytes) {
    if (bytes < 1024) return '${bytes}B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB/s';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB/s';
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/torrent_tile.dart
git commit -m "feat(ui): redesign TorrentTile with status left bar and compact layout"
```

---

### Task 5: Add TabBar to TorrentListScreen

**Files:**
- Modify: `lib/screens/torrent_list_screen.dart`

- [ ] **Step 1: Add error count getter and tab constants to TorrentListScreen**

Add after imports:
```dart
// Tab definitions matching spec: 全部/下载中/错误异常/做种中
const _tabs = ['全部', '下载中', '错误异常', '做种中'];
```

- [ ] **Step 2: Replace `_buildFilterBar` with TabBar**

Replace the `_buildFilterBar` method with:
```dart
Widget _buildFilterBar(BuildContext context, TorrentProvider tp) {
  // Compute error count
  final errorCount = tp.allTorrents
      .where((t) =>
          t.state == TorrentState.error || t.state == TorrentState.unknown)
      .length;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: List.generate(_tabs.length, (i) {
        final isSelected = tp.stateTabIndex == i;
        final tabLabel = _tabs[i];
        final hasBadge = i == 2 && errorCount > 0; // 错误异常 tab

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => tp.setStateTabIndex(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasBadge)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    Text(
                      tabLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}
```

- [ ] **Step 3: Update TorrentProvider to support stateTabIndex**

Modify `lib/providers/torrent_provider.dart` to add `stateTabIndex` field and `setStateTabIndex` method. The tab index maps to filter:
- 0 (全部): null filter
- 1 (下载中): downloading + metaDL states
- 2 (错误异常): error + unknown states
- 3 (做种中): seeding states

Also add `setStateTabIndex(int index)` method.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/torrent_list_screen.dart lib/providers/torrent_provider.dart
git commit -m "feat(ui): add state TabBar to TorrentListScreen"
```

---

### Task 6: Add status colors to theme in app.dart

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Add state color constants to theme**

In `_buildLightTheme()` and `_buildDarkTheme()`, add:
```dart
// State colors
extension TorrentStateColors on ColorScheme {
  Color get downloadingColor => const Color(0xFF4CAF50);
  Color get seedingColor => const Color(0xFF2196F3);
  Color get pausedColor => const Color(0xFFFF9800);
  Color get errorColor => const Color(0xFFE53935);
  Color get checkingColor => const Color(0xFF9C27B0);
}
```

Also update `StatusChip` in `lib/widgets/status_chip.dart` to use the new `getStatusColors()` from `status_border.dart`.

- [ ] **Step 2: Commit**

```bash
git add lib/app.dart lib/widgets/status_chip.dart
git commit -m "feat(ui): add state color constants to theme"
```

---

## Spec Coverage Check

| Spec Item | Task |
|-----------|------|
| Home: global speed hero | Task 3 |
| Home: ClientTile 12-item chip layout | Task 2 |
| Home: ClientTile error red bar | Task 2 |
| Home: ClientTile 3-row grouping | Task 2 |
| Torrent list: TabBar (全部/下载中/错误异常/做种中) | Task 5 |
| Torrent list: error red border + bg | Task 4 |
| Torrent list: downloading green border + bg | Task 4 |
| Torrent list: seeding/paused borders | Task 4 |
| TorrentTile: compact layout (no site/path) | Task 4 |
| StatusBorder shared color mapper | Task 1 |
| Theme state colors | Task 6 |
