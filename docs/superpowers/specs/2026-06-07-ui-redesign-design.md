# Bit Manager UI Redesign — 2026-06-07

## 1. Concept & Vision

A modern torrent management app that feels calm and professional. Information is organized into clear visual hierarchy — the most important data (speeds, status) are immediately visible, while secondary details stay accessible but unobtrusive. The interface should feel like a well-designed dashboard: dense with information, yet never overwhelming.

---

## 2. Design Language

### Aesthetic Direction
Modern card-based dashboard. Inspired by fintech and health apps — clean, spacious cards with subtle depth, clear typographic hierarchy, purposeful use of color only for status indication.

### Color Palette
- **Primary**: `#1A5C8A` (light) / `#4D9FD8` (dark)
- **Background**: `#F5F7FA` (light) / `#111318` (dark)
- **Surface/Card**: theme surface color with 1px border `outlineVariant`
- **Download**: `#4CAF50` green
- **Upload/Seeding**: `#2196F3` blue
- **Paused**: `#FF9800` orange
- **Error**: `#E53935` red
- **Text primary**: `onSurface` / secondary: `onSurfaceVariant`

### Typography
- **Speed hero numbers**: 48px, weight 800
- **Card titles**: 15px, weight 600
- **Body/labels**: 13-14px, weight 400-500
- **Caption/secondary**: 11-12px, weight 400

### Spatial System
- Card border-radius: 12px
- Card padding: 16px
- Card gap (grid): 12px
- Section spacing: 16-24px
- Inner element spacing: 8-12px

### Motion
- No decorative animations
- Only functional transitions: list item taps, modal sheets, loading states

---

## 3. Layout & Structure

### Navigation
Bottom NavigationBar with 4 tabs: Overview, Torrents, RSS, Settings. Already implemented.

### HomeScreen (Overview)
```
┌──────────────────────────────────┐
│  Hero Speed Card (full width)    │
│  ┌─────────────┬─────────────┐   │
│  │  ⬇ 12.5 MB/s│  ⬆ 1.2 MB/s │   │
│  │    下载      │    上传      │   │
│  └─────────────┴─────────────┘   │
├──────────────────────────────────┤
│  客户端 (2)              [管理]  │
│  ┌─────────────┬─────────────┐  │
│  │ NAS-qBitt ● │ Home-Trans○ │  │
│  │ ⬇2 ⬆1     │ offline    │  │
│  │ 12.5 MB/s   │            │  │
│  │ 做种3 下载2  │            │  │
│  └─────────────┴─────────────┘  │
└──────────────────────────────────┘
```

- Hero card: full-width, gradient background, two speed columns with icons
- Section header with count + "管理" button
- 2-column grid of ClientCards
- Each ClientCard: name + status dot, speed, 3 stat pills (做种/下载/错误), free space

### ClientListScreen
- Full client list with detailed stats
- Each item as expanded card showing all stats

### TorrentListScreen
- Filter bar at top (状态 tabs): 全部/下载中/错误异常/做种中
- Each TorrentTile: compact 2-row layout
  - Row 1: checkbox (if select mode) + name + StatusChip + progress%
  - Row 2: ⬇ speed + ⬆ speed + 做种peer + size + date
- Left border color indicates state (already implemented)

### TorrentDetailScreen
```
┌──────────────────────────────────┐
│ [暂停]  [恢复]  [删除]            │
├──────────────────────────────────┤
│ 进度 ─────────────────── 78.5%  │
│ 2.3GB / 3.1GB        ETA: 2h30m │
├──────────────────────────────────┤
│ ⬇ 12.5 MB/s  ⬆ 1.2 MB/s  📊 2.1│
├──────────────────────────────────┤
│ 做种 12/15         下载 3/8      │
├──────────────────────────────────┤
│ 信息 ────────────────────────────│
│ Hash: abc123...                  │
│ 状态: 下载中                     │
│ 总大小: 3.1GB                   │
│ 添加时间: 2024-01-15            │
│ 保存路径: /downloads             │
├──────────────────────────────────┤
│ 文件 (5) ───────────────────────│
│ [file1.mp4] ████████░░ 1.2GB   │
│ [file2.jpg] ██████████ 12MB     │
├──────────────────────────────────┤
│ Tracker (2) ─────────────────────│
│ tracker1.com ✓  5 peers         │
│ tracker2.com ✓  3 peers         │
│ [+ 添加 Tracker]                 │
└──────────────────────────────────┘
```

### RSS Screens
- Source list: icon + name + item count + last fetched
- Items list: title + date + duplicate/downloaded badge

### SettingsScreen
- Grouped list tiles for preferences

---

## 4. Features & Interactions

### HomeScreen
- Pull-to-refresh: triggers stats refresh
- Tap client card → navigates to client detail (future)
- Tap "管理" → ClientListScreen

### TorrentListScreen
- Long press → enter select mode
- Tap item → TorrentDetailScreen
- Filter tabs → instant filter, no loading
- Search → existing delegate
- Filter sheet → client/name/category filters

### TorrentDetailScreen
- Tap action buttons: pause/resume/delete with snackbar feedback
- File list: scrollable, max 300px height
- Tracker: tap to replace/remove
- Add tracker: dialog with URL input

### Client Management
- Add/edit client: form with validation
- Test connection: shows success/fail snackbar
- Delete: confirmation dialog

---

## 5. Component Inventory

### SpeedHeroCard (new)
- Full-width gradient container
- Two columns: download (green icon) + upload (blue icon)
- Large number (48px) + small unit label
- Divider between columns

### ClientCard (redesign of ClientTile)
- 2-column grid item
- Top: name + online dot
- Middle: ⬇ speed + ⬆ speed with icons
- Bottom row: 3 pills — 做种(n), 下载(n), 错误(n)
- Footer: free space
- Error state: red left border (4px)

### TorrentTile (existing, minor tweaks)
- Keep current 2-row compact layout
- Ensure progress bar min-height 6px for downloading, 4px otherwise
- StatusChip already good

### StatusChip (existing)
- Icon + label in colored pill
- Background color 8% opacity, border 20% opacity

### SectionCard (for detail screen)
- Left color bar (3px) + title
- Padding 16px
- Border: 1px outlineVariant

### StatItem
- Icon + value + label stacked
- Background: color 6% opacity, radius 8px

---

## 6. Technical Approach

### Framework
- Flutter with Material 3 (already in use)
- Provider for state management (already in use)

### Changes by File

**New files:**
- `lib/widgets/speed_hero_card.dart` — Hero speed display for HomeScreen

**Modified files:**
- `lib/widgets/client_tile.dart` — Redesign as grid card with stats pills
- `lib/screens/home_screen.dart` — Use SpeedHeroCard + grid layout
- `lib/screens/torrent_detail_screen.dart` — Restructure with SectionCard components
- `lib/widgets/stats_card.dart` — Update for new detail view style

### Implementation Order
1. SpeedHeroCard — creates the new visual anchor
2. ClientTile redesign — tests new card language
3. HomeScreen update — puts it all together
4. TorrentDetailScreen sections — refines detail view
5. Stats_card.dart cleanup — if needed

---

## 7. Out of Scope (This Session)

- RSS UI changes (lowest priority)
- Settings screen changes
- New screens or navigation changes
- Dark/light theme divergence beyond current setup
