# bit_manager

一个 Flutter 编写的 BitTorrent 客户端聚合管理 App（Android），统一管理 qBittorrent / Transmission 客户端实例、站点用户信息抓取与种子操作。

## 功能

- **多客户端管理**：同时接入多个 qBittorrent / Transmission 实例，聚合查看全部种子。
- **种子总览**：按状态分类展示，支持搜索、按客户端 / 站点 / 错误原因筛选与多字段排序。
- **种子详情**：进度、速度、分享率、做种 / 连接数、文件列表、Tracker 列表（含添加 Tracker）。
- **批量操作**：选择模式下底部操作面板，批量暂停 / 恢复 / 删除（含「无辅种时删除文件」选项）、批量改 Tracker（添加 / 替换 / 删除）。
- **智能删除**：删除种子时可勾选「无辅种时删除文件」——仅当某份数据已无其他辅种引用时才删除数据文件，有辅种保留的种子仅移除任务、保留文件，避免误删被多站点共享的数据。
- **辅种识别**：按「同一客户端内 contentPath + 总大小相同」识别 cross-seed，正确聚合不同站点以不同名称发布的同一份资源。
- **站点用户信息抓取**：通过 Cookie 抓取 NexusPHP / Gazelle / Unit3D 等架构站点的用户信息（ID、等级、上传 / 下载量、分享率、魔力值、做种数等）。
- **WebView 登录抓取 Cookie**：应用内打开站点登录页，登录后抓取 Cookie（含 HttpOnly），并可查看 / 编辑后保存。
- **HTML 级跳转跟随**：自动跟随 meta refresh / JS location 等非 HTTP 3xx 的页面跳转，兼容 lemonhd.org 等返回「Redirecting...」跳转桩的站点。
- **内置站点预设**：内置约 280 个 PT 站点预设（baseUrl / 名称 / 图标），开箱即用。

## 技术栈

- Flutter（Dart）
- 状态管理：[provider](https://pub.dev/packages/provider)
- HTTP：[dio](https://pub.dev/packages/dio)
- HTML 解析：[html](https://pub.dev/packages/html)
- WebView 与 Cookie 抓取：[webview_flutter](https://pub.dev/packages/webview_flutter) + `webview_cookie_manager`
- 安全存储：SecureStorage（站点 Cookie）

## 项目结构

```
lib/
  models/         # 数据模型（Torrent / SiteConfig / ClientConfig / Stats）
  services/       # 客户端 API 抽象与实现（qBittorrent / Transmission / Site 抓取）
  providers/      # ChangeNotifier 状态管理（Torrent / Client / Site / Stats）
  screens/        # 页面（种子列表 / 详情 / 站点 / 客户端配置等）
  widgets/        # 复用组件
  utils/          # 工具函数
assets/sites/     # 站点预设（presets.json）与解析 schema（NexusPHP/Gazelle/Unit3D）
```

## 开发

```bash
flutter pub get
flutter run              # 运行
flutter test             # 单元测试
flutter analyze          # 静态分析
flutter build apk        # 构建 Android APK
```

Android `applicationId`：`com.bitmanager.bit_manager`。

## 平台

目前仅支持 Android（WebView 与 Cookie 抓取依赖平台原生能力）。
