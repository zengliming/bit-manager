# Apple 风格重设计

## 概述

将 Bit Manager 整体视觉风格向 Apple 最新设计语言（iOS 19/visionOS）靠齐，采用**中等深度改造**：保留 Material 骨架（`MaterialApp`、`Scaffold`、`Navigator`），自定义关键视觉组件。

## 色彩体系

### 浅色模式

| 用途 | 色值 | 说明 |
|---|---|---|
| 页面背景 | `#F2F2F7` | iOS 系统级浅灰 |
| 卡片背景 | `#FFFFFF` | 纯白 |
| 主色调 | `#007AFF` | iOS 蓝 |
| 成功/下载 | `#34C759` | iOS 绿 |
| 警告/暂停 | `#FF9500` | iOS 橙 |
| 错误 | `#FF3B30` | iOS 红 |
| 信息/做种 | `#007AFF` | iOS 蓝 |
| 主要文字 | `#1C1C1E` | 近黑 |
| 次要文字 | `#8E8E93` | 灰 |
| 分隔线 | `#3C3C43` 12% | hairline |

### 深色模式

| 用途 | 色值 | 说明 |
|---|---|---|
| 页面背景 | `#000000` | 纯黑 |
| 卡片背景 | `#1C1C1E` | iOS 暗色卡片 |
| 主色调 | `#0A84FF` | iOS 暗色蓝 |
| 主要文字 | `#FFFFFF` | 纯白 |
| 次要文字 | `#98989D` | 暗色灰 |

### 实现方式

- 不依赖 `ColorScheme.fromSeed`，直接构造 `ColorScheme` 对象
- 明暗两套完全独立的 `ColorScheme`

## 导航栏

### 底部导航栏

- 毛玻璃背景：`ClipRect` + `BackdropFilter(blur: 20)` + 半透明白/黑背景
- 移除 `elevation` 阴影，顶部 `0.5px` hairline 分割线
- 选中指示器：`StadiumBorder` 圆角胶囊，`primaryContainer` 色填充
- 选中项：图标 24px、文字 11px `w600`
- 未选中项：图标 22px、文字 11px `w400` 灰色
- 3 个 tab：概览 / 种子 / 设置

### 顶部 AppBar

- 同样毛玻璃背景（`SliverAppBar` 或用 `PreferredSize` 包裹）
- 无阴影，底部 hairline 分割线
- 标题 17px `w600`

## 卡片与圆角

### 通用规则

- 卡片背景纯白（浅色）/ `#1C1C1E`（深色）
- 阴影：`offset(0, 1), blurRadius(4), color: #000000 6%`
- **无彩色边框**，统一圆角 `14px`
- 列表项分隔靠间距 + 背景色差，不用 `Divider`

### 各组件调整

| 组件 | 调整 |
|---|---|
| `SpeedHeroCard` | 圆角 `20px`，减小内边距 |
| `TorrentTile` | 移除左侧状态色条，改用行首状态色圆点 |
| `ClientTile` | 保留左侧错误红条，其余风格统一 |
| `StatsCard` | 保持简洁，圆角 `14px` |
| `StatusChip` | 圆角 `8px`，更紧凑 |

## 排版

### 字体

```dart
// 全局 fontFamily 设定
'Inter, -apple-system, BlinkMacSystemFont, .SF Pro Text, Roboto, Segoe UI, sans-serif'
```

### 字号/字重

| 用途 | 字号 | 字重 |
|---|---|---|
| AppBar 标题 | 17px | `w600` |
| 卡片标题 | 15px | `w600` |
| 正文/列表项 | 14px | `w400` |
| 辅助文字 | 12px | `w400` |
| 状态 Chip | 11px | `w600` |
| 指标大数 | 28px | `w700` |
| 导航栏标签 | 11px | `w600`/`w400` |

### 字重规则

仅使用 `w400`、`w600`、`w700`，不使用 `w500`、`w800`。

## 间距

采用 **8px 网格**：

| 用途 | 值 |
|---|---|
| 极小间距 | 4px |
| 小间距 | 8px |
| 中间距 | 12px / 16px |
| 大间距 | 20px / 24px |
| 页面外边距 | horizontal: 20px |
| 列表项间距 | 8px |
| 卡片内边距 | 14-16px |

## 图标

- 导航栏选中用 `filled` 变体（如 `Icons.dashboard`），未选中用 `outlined` 变体（已有此模式，保持不变）

## 受影响文件

| 文件 | 改动 |
|---|---|
| `lib/app.dart` | 色彩方案、导航栏毛玻璃、全局主题 |
| `lib/screens/home_screen.dart` | 间距、卡片样式 |
| `lib/screens/torrent_list_screen.dart` | 筛选栏、列表间距 |
| `lib/screens/torrent_detail_screen.dart` | 卡片、按钮、排版 |
| `lib/screens/settings_screen.dart` | 卡片样式 |
| `lib/screens/client_list_screen.dart` | 卡片、间距 |
| `lib/screens/client_form_screen.dart` | 按钮、排版 |
| `lib/widgets/speed_hero_card.dart` | 圆角、间距 |
| `lib/widgets/torrent_tile.dart` | 移除色条改圆点 |
| `lib/widgets/client_tile.dart` | 卡片阴影、圆角 |
| `lib/widgets/stats_card.dart` | 卡片样式 |
| `lib/widgets/empty_state.dart` | 图标颜色、排版 |
| `lib/widgets/status_border.dart` | 状态色值更新 |
| `lib/widgets/status_chip.dart` | 圆角、字号 |
