import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:html/dom.dart' as dom;
import 'package:path_provider/path_provider.dart';
import '../models/site_config.dart';
import 'filters.dart';
import 'selector_engine.dart';

/// 站点用户信息抓取
///
/// 设计参考 PT-depiler（https://github.com/pt-plugins/PT-depiler）
/// 的 NexusPHP schema：分两阶段抓取，因为首页只有缩略数据，等级 / 加入时间 /
/// 真实上传下载量等只在 `/userdetails.php?id=N` 详情页里。
///
/// 阶段 1：抓首页（baseUrl），从 `#info_block` 里的 `userdetails.php?id=N`
///   链接拿到 user id 和昵称。
/// 阶段 2：抓 `/userdetails.php?id=N`，按 `td.rowhead` 标签行解析所有字段。
class SiteService {
  final Dio _dio;

  SiteService()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
          // 用 bytes 类型跳过 dio FusedTransformer 中的 isJsonMimeType 检查；
          // 部分 PT 站把非法参数（如 Cache-control:private）拼进 Content-Type，
          // 会触发 MediaType.parse 抛 FormatException 并在控制台刷警告。
          responseType: ResponseType.bytes,
        ),
      );

  /// 抓取站点用户信息。返回 null 表示抓取失败
  Future<SiteUserInfo?> fetchUserInfo(SiteConfig config, String? cookie) async {
    if (cookie == null || cookie.isEmpty) return null;
    if (config.baseUrl == null || config.baseUrl!.isEmpty) return null;

    // 启动时一次性把 default_schema.json 加进内存（幂等）
    await ensureDefaultSchemaLoaded();

    // 长度太短（少于 6 字符）或不含 '=' 直接判无效。
    // 之前阈值 10 太严，会拒掉手动从 DevTools 复制单字段（如 uid=1）。
    // 这个判断只是初筛 — 真正"是否登录"还是看 fetch 时是否被服务器重定向。
    final cookieTrim = cookie.trim();
    if (cookieTrim.length < 6 || !cookieTrim.contains('=')) {
      _log(
        '[${config.id}] cookie 太短或格式异常，直接判失败 '
        '(${cookieTrim.length} chars)',
      );
      return null;
    }

    final schema = config.parseSchema;
    final detailsPath = schema?.userDetailsPath ?? '/userdetails.php';

    _log(
      '[${config.id}] start: baseUrl=${config.baseUrl} '
      'cookie=${cookie.length} chars, '
      'has_uid=${RegExp(r'\b(uid|user_id|c_secure_uid)\b').hasMatch(cookie)}',
    );

    try {
      // 阶段 1：抓首页
      final indexHtml = await _getHtml(config.baseUrl!, cookie);
      _log(
        '[${config.id}] index html: '
        '${indexHtml == null ? "null" : "${indexHtml.length} chars"}',
      );
      if (indexHtml == null) return null;
      await _dumpHtmlIfDebug(config.id, 'index', indexHtml);

      // 诊断：找几个标志性 token，判断 HTML 大致是什么页面
      _logHtmlFingerprint(config.id, 'index', indexHtml);

      // 落地是登录页 → cookie 失效，直接返回失败
      if (RegExp(
        r'takelogin\.php|<title[^>]*>[^<]*登[录錄][\s\S-]*</title>',
        caseSensitive: false,
      ).hasMatch(indexHtml)) {
        _log('[${config.id}] ❌ 落地登录页，cookie 已失效。请重新登录抓 cookie。');
        return null;
      }

      // 先用首页能拿到的字段填充
      final info = _parseIndexHtml(config.id, indexHtml);
      _log(
        '[${config.id}] after index: userId=${info.userId} '
        'username=${info.username} ratio=${info.ratio} '
        'uploaded=${info.uploaded} downloaded=${info.downloaded}',
      );

      // 阶段 2：如果拿到了 user id，再抓详情页补全
      final userId = info.userId;
      if (userId == null || userId.isEmpty) {
        _log(
          '[${config.id}] WARNING: 未在首页找到 userId — '
          '检查 baseUrl 是否真的是登录后首页（而非登录页/重定向页）',
        );
      } else {
        final detailUrl = _joinUrl(config.baseUrl!, '$detailsPath?id=$userId');
        final detailHtml = await _getHtml(detailUrl, cookie);
        _log(
          '[${config.id}] detail html: '
          '${detailHtml == null ? "null" : "${detailHtml.length} chars"}',
        );
        if (detailHtml != null) {
          await _dumpHtmlIfDebug(config.id, 'detail', detailHtml);
          _mergeDetailHtml(info, detailHtml, schema: schema);
          _log(
            '[${config.id}] after detail: '
            'username=${info.username} level=${info.level} '
            'uploaded=${info.uploaded} downloaded=${info.downloaded} '
            'ratio=${info.ratio} bonus=${info.bonusPoints} '
            'joined=${info.joinedAtText}',
          );
        }
      }

      info.lastFetchedAt = DateTime.now();
      info.fetchFailed = false;
      return info;
    } catch (e, st) {
      _log('[${config.id}] fetch error: $e\n$st');
      return null;
    }
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[SiteService] $msg');
  }

  /// 印一段「这个 HTML 像不像登录后页面」的指纹，帮助诊断
  void _logHtmlFingerprint(String siteId, String tag, String html) {
    if (!kDebugMode) return;
    final lower = html.toLowerCase();
    bool has(String s) => lower.contains(s.toLowerCase());
    final findings = <String>[
      if (has('userdetails.php')) 'userdetails.php✓',
      if (has('user.php?id=')) 'user.php?id=✓',
      if (has('logout.php')) 'logout✓',
      if (has('takelogin.php')) 'takelogin(登录页)✓',
      if (has('login.php')) 'login.php✓',
      if (has('id="info_block"') || has("id='info_block'")) 'info_block✓',
      if (has('class="rowhead"') ||
          has("class='rowhead'") ||
          has('class="rowfollow"') ||
          has('class=\'rowfollow\''))
        'rowhead/rowfollow✓',
      if (RegExp(r'<noscript', caseSensitive: false).hasMatch(html))
        'noscript✓',
      if (has('window.__nuxt') ||
          has('window.__next_data') ||
          has('id="app"') && has('vue') ||
          has('id="root"') && has('react'))
        'SPA shell✓(JS 渲染)',
    ];
    _log(
      '[$siteId] $tag fingerprint: '
      '${findings.isEmpty ? "(无任何关键词)" : findings.join(", ")}',
    );

    // 尝试看 <title>，登录页通常 title 是「登录」
    final title = RegExp(
      r'<title[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html)?.group(1)?.trim();
    if (title != null) _log('[$siteId] $tag title: $title');
  }

  /// debug 模式下把 HTML 落到 `app documents/site_dumps/<siteId>_<tag>.html`，
  /// 方便用户复制到对话里给我们看真实页面结构
  Future<void> _dumpHtmlIfDebug(String siteId, String tag, String html) async {
    if (!kDebugMode) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dumpDir = Directory('${dir.path}/site_dumps');
      if (!await dumpDir.exists()) await dumpDir.create(recursive: true);
      final file = File('${dumpDir.path}/${siteId}_$tag.html');
      await file.writeAsString(html);
      _log('dumped to ${file.path}');
    } catch (e) {
      _log('dump failed: $e');
    }
  }

  /// 公开：返回 dump 文件绝对路径（如果存在）。供 SiteRulesScreen 加载预览 HTML。
  static Future<String?> dumpPathFor(String siteId, String tag) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/site_dumps/${siteId}_$tag.html');
      if (await file.exists()) return file.path;
    } catch (_) {}
    return null;
  }

  /// 公开：读 dump 文件全文
  static Future<String?> readDump(String path) async {
    try {
      return await File(path).readAsString();
    } catch (_) {
      return null;
    }
  }

  /// 公开：在 HTML 上跑一组 field 规则，返回每字段命中值。
  /// 供 SiteRulesScreen 预览使用 — 不写回 site data。
  static Map<String, Object?> runFieldRulesForPreview(
    String html,
    Map<String, FieldRule> rules,
  ) {
    final doc = SelectorEngine.parse(html);
    final info = SiteUserInfo(siteId: 'preview');
    final svc = SiteService();
    svc._applyFieldRules(info, doc, rules);
    return _infoToMap(info);
  }

  static Map<String, Object?> _infoToMap(SiteUserInfo info) {
    return {
      'userId': info.userId,
      'username': info.username,
      'level': info.level,
      'uploaded': info.uploaded,
      'downloaded': info.downloaded,
      'trueUploaded': info.trueUploaded,
      'trueDownloaded': info.trueDownloaded,
      'ratio': info.ratio,
      'bonusPoints': info.bonusPoints,
      'seedingBonus': info.seedingBonus,
      'bonusPerHour': info.bonusPerHour,
      'seedingCount': info.seedingCount,
      'leechingCount': info.leechingCount,
      'seedingSize': info.seedingSize,
      'messageCount': info.messageCount,
      'hnrPreWarning': info.hnrPreWarning,
      'hnrUnsatisfied': info.hnrUnsatisfied,
      'joinedAtText': info.joinedAtText,
      'lastAccessAtText': info.lastAccessAtText,
    };
  }

  /// 拉取一个 URL 的 HTML，失败返回 null
  Future<String?> _getHtml(String url, String cookie) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        headers: {
          'Cookie': cookie,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
        followRedirects: true,
        responseType: ResponseType.bytes,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    _log('GET $url -> ${response.statusCode} (final: ${response.realUri})');
    if (response.statusCode != 200) return null;
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) return null;
    // 容错解码：站点偶尔返回非严格 UTF-8（GB2312/GBK 等），allowMalformed 防抛
    final html = utf8.decode(Uint8List.fromList(bytes), allowMalformed: true);
    return html.isEmpty ? null : html;
  }

  /// 把相对路径 `/userdetails.php?id=1` 拼到 baseUrl 上
  String _joinUrl(String baseUrl, String path) {
    final base = Uri.parse(baseUrl);
    final relative = Uri.parse(path);
    return base.resolveUri(relative).toString();
  }

  // ── 暴露给测试 ──

  @visibleForTesting
  SiteUserInfo parseIndexHtml(String siteId, String html) =>
      _parseIndexHtml(siteId, html);

  @visibleForTesting
  void mergeDetailHtml(
    SiteUserInfo info,
    String html, {
    SiteParseSchema? schema,
  }) => _mergeDetailHtml(info, html, schema: schema);

  /// 兼容旧 API：parseHtml = parseIndex + 额外尝试一些纯文本兜底
  /// 仅用于测试旧的「单页解析」用例
  @visibleForTesting
  SiteUserInfo parseHtml(
    String siteId,
    String html, {
    SiteParseSchema? schema,
  }) {
    final info = _parseIndexHtml(siteId, html);
    _mergeDetailHtml(info, html, schema: schema);
    info.lastFetchedAt = DateTime.now();
    info.fetchFailed = false;
    return info;
  }

  // ── 阶段 1：首页解析 ──

  /// 从首页 HTML 提取 userId / username，并尽量补一些首页就能拿到的字段
  SiteUserInfo _parseIndexHtml(String siteId, String html) {
    final info = SiteUserInfo(siteId: siteId);

    // PT-depiler 的 baseUserIdSelector 等价实现：
    // 1) #info_block 内的 userdetails.php?id=N 链接
    // 2) class 含 "Name" / "username" 的（NexusPHP 用户名链接的标志）
    // 3) 任意 a[href*='userdetails.php']
    //
    // 关键：cspt 等站点 #info_block 里第一个链接是头像（<a><img alt="用户头像"></a>），
    // 用户名链接排在后面。所以「第一个 userdetails 链接」不一定是用户名 — 必须按
    // class*=Name 优先 + 跳过纯 <img> 链接 来挑。
    final infoBlock = _innerHtmlOf(html, idOrName: 'info_block') ?? html;
    final userPick = _pickUserDetailsLink(infoBlock);
    if (userPick != null) {
      info.userId = userPick.userId;
      info.username = userPick.username;
    } else {
      // Gazelle 风格：a[href*='user.php?id=']
      final gz = RegExp(
        r'''<a[^>]+href=["'][^"']*user\.php\?id=(\d+)[^"']*["'][^>]*>(.+?)</a>''',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (gz != null) {
        info.userId = gz.group(1);
        final inner = _stripTags(gz.group(2) ?? '').trim();
        if (inner.isNotEmpty && inner.length < 60) info.username = inner;
      }
    }

    // 首页 info_block 里 NexusPHP 通常已经有上传/下载/分享率（带 class 着色）
    info.uploaded ??= parseSize(_classText(html, 'color_uploaded'));
    info.downloaded ??= parseSize(_classText(html, 'color_downloaded'));
    info.ratio ??= parseRatio(_classText(html, 'color_ratio'));
    info.bonusPoints ??= _parseInt(_classText(html, 'color_bonus'));

    // Gazelle 首页风格的 li#stats_*，内部可能有 "Up: <span>2.5 TiB</span>" 这种前缀
    info.uploaded ??= parseSize(
      _extractSizeFromText(_idInnerText(html, 'stats_uploaded')),
    );
    info.downloaded ??= parseSize(
      _extractSizeFromText(_idInnerText(html, 'stats_downloaded')),
    );
    info.ratio ??= parseRatio(
      _extractRatioFromText(_idInnerText(html, 'stats_ratio')),
    );

    return info;
  }

  /// 从 info_block 中挑一个最像「用户名链接」的 `<a href="userdetails.php?id=N">`
  ///
  /// 评分规则（高分胜出，等分按 HTML 顺序前胜）：
  /// - +20 class 含 "Name"/"User_Name"/"username"
  /// - -50 inner 只是一个 `<img>`（必然是头像链接）
  /// - -30 inner 纯文本是已知头像标签（"用户头像"/"头像"/"avatar"/"user avatar"）
  ///
  /// 返回 null 表示没找到任何 userdetails.php 链接
  _UserPick? _pickUserDetailsLink(String html) {
    // 抓 a 标签整段 + href + class + inner
    final linkRe = RegExp(
      r'''<a\b([^>]*?)href=["']([^"']*userdetails\.php\?id=(\d+)[^"']*)["']([^>]*)>(.+?)</a>''',
      caseSensitive: false,
      dotAll: true,
    );

    _UserPick? best;
    int bestScore = -1 << 30;
    int orderIdx = 0;

    for (final m in linkRe.allMatches(html)) {
      final attrsBefore = m.group(1) ?? '';
      final attrsAfter = m.group(4) ?? '';
      final attrs = '$attrsBefore $attrsAfter';
      final userId = m.group(3);
      final inner = m.group(5) ?? '';

      var score = -orderIdx; // 同分时倾向先出现的，但权重最低
      orderIdx += 1;

      // class 含 Name/username → 大概率是用户名链接
      final classMatch = RegExp(
        r'''class=["']([^"']*)["']''',
        caseSensitive: false,
      ).firstMatch(attrs);
      final cls = classMatch?.group(1)?.toLowerCase() ?? '';
      if (cls.contains('name') || cls.contains('username')) score += 20;

      // inner 是纯 <img>（一个标签 + 空白），即头像链接
      final innerTrimmed = inner.trim();
      final imgOnly = RegExp(
        r'''^\s*<img\b[^>]*/?\s*>\s*$''',
        caseSensitive: false,
        dotAll: true,
      ).hasMatch(innerTrimmed);
      if (imgOnly) score -= 50;

      // 剥光后纯文本若是已知头像标签也降权
      final stripped = _stripTags(inner).trim();
      const avatarLabels = {'用户头像', '头像', 'avatar', 'user avatar'};
      if (avatarLabels.contains(stripped.toLowerCase())) score -= 30;

      // inner 完全空（理论上不该出现，安全兜底）
      if (stripped.isEmpty) score -= 20;

      if (score > bestScore) {
        bestScore = score;
        // 用户名取剥光后文本，过长（><60）视为脏数据丢弃
        final username =
            (stripped.isNotEmpty &&
                stripped.length < 60 &&
                !avatarLabels.contains(stripped.toLowerCase()) &&
                !imgOnly)
            ? stripped
            : null;
        best = _UserPick(userId: userId, username: username);
      }
    }
    return best;
  }

  // ── 阶段 2：详情页解析 ──

  // ── 默认 NexusPHP td.rowhead 标签词（多语言）──
  // 对齐 PT-depiler/src/packages/site/schemas/NexusPHP.ts 的 selectors
  static const _defaultUsernameLabels = ['用户名', '用戶名', '會員名稱', 'Username'];
  static const _defaultLevelLabels = ['等级', '等級', 'Class'];
  static const _defaultTransferLabels = ['传输', '傳送', 'Transfers', '分享率'];
  static const _defaultBonusLabels = [
    '魔力值',
    '猫粮',
    '麦粒',
    '星焱',
    '魅力值',
    '沙粒',
    'Karma Points',
    'Bonus',
  ];
  static const _defaultJoinTimeLabels = ['加入日期', 'Join date', 'Joined'];
  static const _defaultSeedingLabels = ['当前做种', '當前做種', 'Seeding'];
  static const _defaultLeechingLabels = ['当前下载', '當前下載', 'Leeching'];

  /// 默认 NexusPHP schema selectors
  ///
  /// 把 PT-depiler `schemas/NexusPHP.ts` 里的 default `userInfo.selectors`
  /// 翻译成我们的 FieldRule 形式。所有用户特殊规则（[parseSchema.fields]）跑完后，
  /// 这里再补刀一遍 — 任何字段值仍是 null 才会被覆盖。
  ///
  /// 真正的规则定义在 `assets/sites/schemas/nexusphp.json` 等，启动时按
  /// `assets/sites/schemas/manifest.json` 一次性加载到这里。改 JSON 不用动代码。
  /// 测试代码可以通过 [setDefaultFieldsForTest] 注入用例。
  static Map<String, Map<String, FieldRule>> _defaultFieldsBySchema = {
    'NexusPHP': _builtinFallback,
  };

  /// 是否已加载过 schemas/manifest.json（首次 fetch 时触发）
  static bool _manifestLoaded = false;

  /// 兜底：assets 加载失败时使用的最小内置规则（保证 app 不崩）
  static final Map<String, FieldRule> _builtinFallback = const {
    'levelName': FieldRule(
      selector: [
        "td.rowhead:contains('等级') + td > img",
        "td.rowhead:contains('等級') + td > img",
        "td.rowhead:contains('Class') + td > img",
      ],
      attr: 'title',
    ),
  };

  /// 测试钩子：直接注入默认 fields，跳过 assets 加载
  @visibleForTesting
  static void setDefaultFieldsForTest(
    Map<String, Map<String, FieldRule>> fields,
  ) {
    _defaultFieldsBySchema = fields;
    _manifestLoaded = true;
  }

  /// 重置默认 fields 为内置 fallback（测试 tearDown 用）
  @visibleForTesting
  static void resetDefaultFieldsForTest() {
    _defaultFieldsBySchema = {'NexusPHP': _builtinFallback};
    _manifestLoaded = false;
  }

  /// 测试钩子：读取指定 schema 的默认 fields
  @visibleForTesting
  static Map<String, FieldRule>? defaultFieldsForTest(String schema) =>
      _defaultFieldsBySchema[schema];

  /// 从 assets/schemas/manifest.json 加载所有默认规则；幂等，反复调只读一次
  static Future<void> ensureDefaultSchemaLoaded() async {
    if (_manifestLoaded) return;
    _manifestLoaded = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/sites/schemas/manifest.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['schemas'] as List?;
      if (list == null) return;
      for (final entry in list) {
        if (entry is! Map) continue;
        final key = entry['key'] as String?;
        final path = entry['path'] as String?;
        if (key == null || path == null) continue;
        try {
          final rawSchema = await rootBundle.loadString(path);
          final schemaJson = jsonDecode(rawSchema) as Map<String, dynamic>;
          final fieldsJson = schemaJson['fields'] as Map<String, dynamic>?;
          if (fieldsJson == null) continue;
          final fields = <String, FieldRule>{};
          fieldsJson.forEach((k, v) {
            if (v is! Map) return;
            // 跳过 _label / _comment 等带下划线开头的元数据字段
            if (k.startsWith('_')) return;
            try {
              fields[k.toString()] = FieldRule.fromJson(
                Map<String, dynamic>.from(v),
              );
            } catch (_) {
              // 单个字段加载失败不影响其它字段
            }
          });
          if (fields.isNotEmpty) {
            _defaultFieldsBySchema[key] = fields;
          }
        } catch (e) {
          // 单个 schema 文件失败时保持内置 fallback，不影响其它 schema
          if (kDebugMode) {
            debugPrint('[SiteService] $path 加载失败: $e');
          }
        }
      }
    } catch (e) {
      // manifest 加载失败时 NexusPHP 仍走 _builtinFallback
      if (kDebugMode) {
        debugPrint('[SiteService] manifest.json 加载失败: $e — 使用内置 NexusPHP 兜底');
      }
    }
  }

  /// 合并默认标签和站点自定义标签（自定义标签优先匹配）
  List<String> _mergeLabels(List<String> defaults, List<String>? custom) {
    if (custom == null || custom.isEmpty) return defaults;
    return [...custom, ...defaults];
  }

  /// 根据站点架构返回站内消息页路径
  static String messagePathFor(SiteParseSchema? schema) {
    switch (schema?.schema) {
      case 'Gazelle':
        return '/inbox.php';
      case 'NexusPHP':
      default:
        return '/messages.php';
    }
  }

  /// 探测 assets/sites/icons/ 下真实存在的图标文件路径
  ///
  /// 用途：用户已有的持久化数据（旧版 SiteConfig 没存 iconAsset），
  /// 启动时用站点 id 探测一次实际文件扩展名，填回 site.iconAsset。
  /// 新流程（importPresets）已经直接复制 preset.iconAsset，不需要 probe。
  static const _iconExtensions = [
    '.ico',
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.svg',
    '.webp',
  ];

  static Future<String?> resolveIconAsset(String siteId) async {
    for (final ext in _iconExtensions) {
      final path = 'assets/sites/icons/$siteId$ext';
      try {
        await rootBundle.load(path);
        return path;
      } catch (_) {
        // 文件不存在，尝试下一个扩展名
      }
    }
    return null;
  }

  /// 用 schema.fields 提供的 selector + filter 规则填充 info
  ///
  /// 字段名对照（key 沿用 PT-depiler 命名）：
  /// - `id` / `name`               → userId / username
  /// - `uploaded` / `downloaded`   → uploaded / downloaded
  /// - `trueUploaded` / `trueDownloaded` → trueUploaded / trueDownloaded
  /// - `ratio`                     → ratio
  /// - `levelName`                 → level
  /// - `bonus`                     → bonusPoints (魔力值)
  /// - `seedingBonus`              → seedingBonus (做种积分)
  /// - `bonusPerHour`              → bonusPerHour (时魔)
  /// - `joinTime`                  → joinedAtText
  /// - `lastAccessAt`              → lastAccessAtText
  /// - `seeding`                   → seedingCount
  /// - `seedingSize`               → seedingSize (做种体积)
  /// - `messageCount`              → messageCount
  /// - `hnrPreWarning` / `hnrUnsatisfied` → 同名
  void _applyFieldRules(
    SiteUserInfo info,
    dom.Document doc,
    Map<String, FieldRule> fields,
  ) {
    void run(String fieldName, void Function(Object? value) setter) {
      final rule = fields[fieldName];
      if (rule == null) return;
      final raw = _runFieldRule(doc, rule);
      if (raw == null) return;
      setter(raw);
    }

    run('id', (v) {
      // 防御：必须看起来像数字 id，否则可能被错塞了用户名 / 中文等
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) return;
      if (info.userId != null) return;
      // querystring filter 出来是字符串 '42'，int.tryParse 接受；
      // 数字字面量 / 整型也直接放过
      if (int.tryParse(s) != null) {
        info.userId = s;
      } else if (RegExp(r'^\d{1,15}$').hasMatch(s)) {
        info.userId = s;
      }
    });
    run('name', (v) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty && s.length < 60) info.username ??= s;
    });
    run('uploaded', (v) => info.uploaded ??= _toInt(v));
    run('downloaded', (v) => info.downloaded ??= _toInt(v));
    run('trueUploaded', (v) => info.trueUploaded ??= _toInt(v));
    run('trueDownloaded', (v) => info.trueDownloaded ??= _toInt(v));
    run('ratio', (v) => info.ratio ??= _toDouble(v));
    run('levelName', (v) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) info.level ??= s;
    });
    run('bonus', (v) => info.bonusPoints ??= _toInt(v));
    run('seedingBonus', (v) => info.seedingBonus ??= _toNum(v));
    run('bonusPerHour', (v) => info.bonusPerHour ??= _toNum(v));
    run('joinTime', (v) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) info.joinedAtText ??= s;
    });
    run('lastAccessAt', (v) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) info.lastAccessAtText ??= s;
    });
    run('seeding', (v) => info.seedingCount ??= _toInt(v));
    run('seedingSize', (v) => info.seedingSize ??= _toInt(v));
    run('messageCount', (v) => info.messageCount ??= _toInt(v));
    run('hnrPreWarning', (v) => info.hnrPreWarning ??= _toInt(v));
    run('hnrUnsatisfied', (v) => info.hnrUnsatisfied ??= _toInt(v));
  }

  static num? _toNum(Object? v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }

  /// 跑一条 FieldRule，返回 filter 后的值；任一步骤失败返回 null
  Object? _runFieldRule(dom.Document doc, FieldRule rule) {
    for (final selector in rule.selector) {
      final elements = SelectorEngine.query(doc.documentElement!, selector);
      for (final el in elements) {
        // 取属性 / 文本
        String? raw;
        if (rule.attr != null) {
          raw = el.attributes[rule.attr];
        } else {
          raw = el.text;
        }
        if (raw == null) continue;
        raw = raw.trim();
        if (raw.isEmpty) continue;

        // contains 过滤
        if (rule.contains != null && !raw.contains(rule.contains!)) continue;

        // filter / filters 应用
        Object? value = raw;
        if (rule.filters != null) {
          value = Filters.applyAll(value, rule.filters!);
        } else if (rule.filter != null) {
          value = Filters.apply(value, rule.filter!);
        }
        if (value == null) continue;
        if (value is String && value.isEmpty) continue;
        return value;
      }
    }
    return null;
  }

  static int? _toInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().replaceAll(',', '').trim()) ??
        double.tryParse(v.toString().replaceAll(',', '').trim())?.toInt();
  }

  static double? _toDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s == '∞' || s == 'Inf.' || s == 'Infinity' || s == '---') {
      return double.infinity;
    }
    return double.tryParse(s);
  }

  /// 从 `/userdetails.php?id=N` 详情页 HTML 解析全字段，覆盖 info 里 null 的项
  ///
  /// NexusPHP 详情页是规整的 `<tr><td class="rowhead">标签</td><td class="rowfollow">值</td></tr>`
  /// 表格，按 PT-depiler 的 selectors 实现：
  /// - 等级：rowhead "等级" / "等級" / "Class" → 下一格 img 的 title 属性（不是 alt！）
  /// - 加入日期：rowhead "加入日期" / "Join date"
  /// - 传输：rowhead "传输" / "傳送" / "Transfers" → 一大段含「上传量: X 下载量: Y 分享率: Z」
  /// - 魔力值：rowhead "魔力值" 或 rowfollow 自带 "魔力值: N"
  ///
  /// [schema] 允许某个站点自定义标签词。例如 13city 把"魔力值"叫"啤酒瓶"，
  /// 站点配置里写 `bonusLabels: ['啤酒瓶']` 即可。
  void _mergeDetailHtml(
    SiteUserInfo info,
    String html, {
    SiteParseSchema? schema,
  }) {
    // 只解析 HTML 一次，三层规则共用同一个 Document
    final doc = SelectorEngine.parse(html);

    // ── 阶段 1：先跑 schema.fields 里的精确 selector + filter 规则 ──
    // 对齐 PT-depiler `userInfo.selectors`，按字段名映射到 SiteUserInfo 属性
    if (schema?.fields != null) {
      _applyFieldRules(info, doc, schema!.fields!);
    }

    // ── 阶段 2：按 schema 选默认规则（null 回落 NexusPHP）──
    final schemaKey = schema?.schema ?? 'NexusPHP';
    final defaults =
        _defaultFieldsBySchema[schemaKey] ??
        _defaultFieldsBySchema['NexusPHP']!;
    _applyFieldRules(info, doc, defaults);

    // ── 阶段 3：旧的「td.rowhead 标签词」路径，兜底各种二开站点变体 ──
    final usernameLabels = _mergeLabels(
      _defaultUsernameLabels,
      schema?.usernameLabels,
    );
    final levelLabels = _mergeLabels(_defaultLevelLabels, schema?.levelLabels);
    final transferLabels = _mergeLabels(
      _defaultTransferLabels,
      schema?.transferLabels,
    );
    final bonusLabels = _mergeLabels(_defaultBonusLabels, schema?.bonusLabels);
    final joinTimeLabels = _mergeLabels(
      _defaultJoinTimeLabels,
      schema?.joinTimeLabels,
    );
    final seedingLabels = _mergeLabels(
      _defaultSeedingLabels,
      schema?.seedingLabels,
    );
    final leechingLabels = _mergeLabels(
      _defaultLeechingLabels,
      schema?.leechingLabels,
    );

    // ── 用户名（详情页通常有，且更准确）──
    info.username ??= _rowText(html, usernameLabels);

    // ── 等级：从 td.rowhead "等级" + td 里的 <img title="VIP"> 取 ──
    info.level ??= _rowImgAttr(html, levelLabels, attr: 'title');
    // 兜底：如果该 img 没有 title，就用 alt
    info.level ??= _rowImgAttr(html, levelLabels, attr: 'alt');
    // 兜底 2：rowText 取纯文本（部分站点等级是文字非图片）
    if (info.level == null) {
      final raw = _rowText(html, levelLabels);
      if (raw != null && raw.length < 30) info.level = raw;
    }

    // ── 传输信息：包含上传/下载/分享率 ──
    final transfer = _rowText(html, transferLabels);
    if (transfer != null) {
      info.uploaded ??= _matchSize(transfer, [
        RegExp(
          r'(?:上[传傳]量|Uploaded)\s*[:：]?\s*([\d.,]+\s*[ZEPTGMK]?i?B)',
          caseSensitive: false,
        ),
      ]);
      info.downloaded ??= _matchSize(transfer, [
        RegExp(
          r'(?:下[载載]量|Downloaded)\s*[:：]?\s*([\d.,]+\s*[ZEPTGMK]?i?B)',
          caseSensitive: false,
        ),
      ]);
      info.ratio ??= _matchRatio(transfer, [
        RegExp(
          r'(?:分享率|Ratio|Share\s*Ratio)\s*[:：]?\s*([\d.]+|∞|Inf\.|Infinity|---)',
          caseSensitive: false,
        ),
      ]);
    }

    // 魔力值
    info.bonusPoints ??= _parseInt(_rowText(html, bonusLabels));

    // 加入日期
    final joinedRaw = _rowText(html, joinTimeLabels);
    if (joinedRaw != null) {
      info.joinedAtText = joinedRaw.split('(').first.trim();
    }

    // 当前做种 / 当前下载
    info.seedingCount ??= _parseInt(_rowText(html, seedingLabels));
    info.leechingCount ??= _parseInt(_rowText(html, leechingLabels));

    // ── 兜底：如果详情页没用 td.rowhead 表格（少数二开站点），扫纯文本 ──
    final text = _stripTags(html);

    info.uploaded ??= _matchSize(text, [
      RegExp(
        r'(?:上[传傳]量|Uploaded)\s*[:：]?\s*([\d.,]+\s*[ZEPTGMK]?i?B)',
        caseSensitive: false,
      ),
    ]);
    info.downloaded ??= _matchSize(text, [
      RegExp(
        r'(?:下[载載]量|Downloaded)\s*[:：]?\s*([\d.,]+\s*[ZEPTGMK]?i?B)',
        caseSensitive: false,
      ),
    ]);
    info.ratio ??= _matchRatio(text, [
      RegExp(
        r'(?:分享率|Ratio|Share\s*Ratio)\s*[:：]?\s*([\d.]+|∞|Inf\.?|Infinity|---)',
        caseSensitive: false,
      ),
    ]);
    info.bonusPoints ??= _parseInt(
      _firstMatch(text, [
        RegExp(
          r'(?:魔力值|Karma Points|Bonus)\s*[:：]?\s*([\d,]+(?:\.\d+)?)',
          caseSensitive: false,
        ),
      ]),
    );
    if (info.level == null) {
      final lvl = _firstMatch(text, [
        RegExp(r'User\s*Class\s*[:：]\s*([^\s|·]{1,20})', caseSensitive: false),
      ]);
      if (lvl != null) info.level = lvl;
    }
    // 最后一道兜底：按 NexusPHP 等级图片约定（src 含 /class/）取 img alt
    info.level ??= _imgAlt(html, srcContains: '/class/');
    info.level ??= _imgAlt(html, classContains: 'userlevel');

    // 做种 / 下载中：兜底纯文本扫描（部分站点不在 td.rowhead 里）
    info.seedingCount ??= _parseInt(
      _firstMatch(text, [
        RegExp(
          r'(?:当前做种|當前做種|做种数|Seeding)\s*[:：]?\s*(\d+)',
          caseSensitive: false,
        ),
      ]),
    );
    info.leechingCount ??= _parseInt(
      _firstMatch(text, [
        RegExp(
          r'(?:当前下载|當前下載|下载中|Leeching)\s*[:：]?\s*(\d+)',
          caseSensitive: false,
        ),
      ]),
    );
  }

  /// 在 HTML 中找出符合条件的 `<img>` 标签的 alt 属性。
  ///
  /// 优先匹配 src 中包含 [srcContains] 的 img；找不到则退回 class 中包含
  /// [classContains] 的 img。属性顺序不敏感。
  ///
  /// NexusPHP 用户等级一般是 `<img class="userlevel_image" src="pic/class/VIP.gif" alt="VIP">`，
  /// 等级名直接放在 alt 里，比扫文本「等级:」准得多（很多站点根本没有这行字）。
  static final _imgTagRe = RegExp(r'<img\b[^>]*>', caseSensitive: false);
  static final _imgAltRe = RegExp(r'''\balt=["']([^"']*)["']''');
  static final _imgSrcRe = RegExp(r'''\bsrc=["']([^"']*)["']''');
  static final _imgClassRe = RegExp(r'''\bclass=["']([^"']*)["']''');

  String? _imgAlt(String html, {String? srcContains, String? classContains}) {
    final imgs = _imgTagRe.allMatches(html);

    String? fallback;
    for (final m in imgs) {
      final tag = m.group(0)!;
      final alt = _imgAltRe.firstMatch(tag)?.group(1)?.trim();
      if (alt == null || alt.isEmpty) continue;

      final src = _imgSrcRe.firstMatch(tag)?.group(1) ?? '';
      // 把反斜杠当分隔符处理，容忍 Windows 风格路径
      final normSrc = src.toLowerCase().replaceAll(r'\', '/');
      if (srcContains != null && normSrc.contains(srcContains.toLowerCase())) {
        return alt;
      }
      if (classContains != null) {
        final cls = _imgClassRe.firstMatch(tag)?.group(1)?.toLowerCase() ?? '';
        if (cls.contains(classContains.toLowerCase())) {
          fallback ??= alt;
        }
      }
    }
    return fallback;
  }

  // ── HTML 抽取 helpers ──

  /// 找 `<td class="rowhead">` 单元格里 trim 后等于（或包含）任一 [labels] 的，
  /// 返回相邻下一个 `<td>` 的纯文本
  ///
  /// 是 PT-depiler `td.rowhead:contains('xxx') + td` 选择器的 Dart 实现
  String? _rowText(String html, List<String> labels) {
    final cell = _rowHeadFollowingCell(html, labels);
    if (cell == null) return null;
    final t = _stripTags(cell).trim();
    return t.isEmpty ? null : t;
  }

  /// 找 `<td.rowhead>label</td>` 后相邻 td 中 `<img>` 的指定属性
  String? _rowImgAttr(
    String html,
    List<String> labels, {
    required String attr,
  }) {
    final cell = _rowHeadFollowingCell(html, labels);
    if (cell == null) return null;
    final imgMatch = RegExp(
      r'<img\b[^>]*>',
      caseSensitive: false,
    ).firstMatch(cell);
    if (imgMatch == null) return null;
    final tag = imgMatch.group(0)!;
    final m = RegExp(
      '''\\b${RegExp.escape(attr)}=["']([^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(tag);
    final v = m?.group(1)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// 抽取 `<td class="rowhead">label</td>` 后相邻 `<td>` 的原始 HTML
  String? _rowHeadFollowingCell(String html, List<String> labels) {
    // 匹配 <td ... class="...rowhead..."> ... </td><td ...>VALUE</td>
    // labels 里任一作为 rowhead 内文本子串即可（PT-depiler 用 :contains）
    final pattern = RegExp(
      r'''<td[^>]*\bclass=["'][^"']*rowhead[^"']*["'][^>]*>([\s\S]*?)</td>\s*<td[^>]*>([\s\S]*?)</td>''',
      caseSensitive: false,
    );
    for (final m in pattern.allMatches(html)) {
      final headText = _stripTags(m.group(1) ?? '').trim();
      for (final label in labels) {
        if (headText.contains(label)) {
          return m.group(2);
        }
      }
    }
    return null;
  }

  /// 找 `id="<name>"` 元素的内部 HTML（不剥标签）
  ///
  /// 按开标签名（div/table/span 等）配对闭合标签，不会被嵌套的同名子元素或
  /// 邻近的其他标签错误截断。例如 `<table id="x"><span>y</span>z</table>`
  /// 必须返回 `<span>y</span>z`，不能在第一个 `</span>` 截断。
  String? _innerHtmlOf(String html, {required String idOrName}) {
    final escapedId = RegExp.escape(idOrName);
    // 捕获开标签名 (group 1)，再用 \1 反向引用要求 close tag 同名。
    // 注意 dart 正则反向引用语法：使用命名分组更稳。
    final re = RegExp(
      '''<(?<tag>div|table|span|section|nav|header|aside|main|article)[^>]*\\bid=["']$escapedId["'][^>]*>([\\s\\S]*?)</\\k<tag>>''',
      caseSensitive: false,
    );
    return re.firstMatch(html)?.group(2);
  }

  /// 取 HTML 中 `class="...<name>..."` 元素的纯文本
  String? _classText(String html, String className) {
    final escaped = RegExp.escape(className);
    final m = RegExp(
      '''<[a-z]+[^>]*class=["'][^"']*$escaped[^"']*["'][^>]*>(.*?)</''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    final t = _stripTags(m.group(1) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// 取 HTML 中 `id="<name>"` 元素的纯文本
  String? _idInnerText(String html, String id) {
    final escaped = RegExp.escape(id);
    final m = RegExp(
      '''<[a-z]+[^>]*id=["']$escaped["'][^>]*>(.*?)</''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return null;
    final t = _stripTags(m.group(1) ?? '').trim();
    return t.isEmpty ? null : t;
  }

  /// 剥除 HTML 标签 / 注释 / script / style，并合并空白
  /// 保留 `<img alt="...">` 中的 alt 文本（NexusPHP 用图片表示等级）
  String _stripTags(String html) {
    return html
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
        // <img ... alt="X" ...> -> " X "（保留等级名等关键文本）
        .replaceAllMapped(
          RegExp(
            r'''<img[^>]*\balt=["']([^"']*)["'][^>]*>''',
            caseSensitive: false,
          ),
          (m) => ' ${m.group(1)} ',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' \n ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ');
  }

  /// 在文本中按多个正则尝试取第一个匹配，返回 group(1) 经 trim
  String? _firstMatch(String text, List<RegExp> patterns) {
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) {
        final v = m.group(1)?.trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  /// 用一组正则匹配大小（如 1.23 TB），返回字节数
  int? _matchSize(String text, List<RegExp> patterns) =>
      parseSize(_firstMatch(text, patterns));

  /// 用一组正则匹配分享率
  double? _matchRatio(String text, List<RegExp> patterns) =>
      parseRatio(_firstMatch(text, patterns));

  /// 从含其他文本的字符串中抽出第一个大小串（"Up: 2.5 TiB" → "2.5 TiB"）
  String? _extractSizeFromText(String? s) {
    if (s == null) return null;
    final m = RegExp(
      r'([\d.,]+\s*[ZEPTGMK]?i?B)\b',
      caseSensitive: false,
    ).firstMatch(s);
    return m?.group(1);
  }

  /// 从含其他文本的字符串中抽出第一个数字（"Ratio: 2.50" → "2.50"）
  String? _extractRatioFromText(String? s) {
    if (s == null) return null;
    final m = RegExp(r'([\d.]+|∞|Inf\.|Infinity)').firstMatch(s);
    return m?.group(1);
  }

  /// 解析整数，容忍千分位逗号；带小数则截取整数部分
  static int? _parseInt(String? s) {
    if (s == null) return null;
    final cleaned = s.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final asDouble = double.tryParse(cleaned);
    return asDouble?.toInt();
  }

  /// 解析文件大小字符串（如 "1.23 TB", "500 GB"）为字节数
  static int? parseSize(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim().replaceAll(',', '');

    // 优先匹配带 i 的二进制单位（TiB/GiB 等），避免 "TiB" 被 "TB" 误匹配
    final units = [
      ['TiB', 1099511627776],
      ['GiB', 1073741824],
      ['MiB', 1048576],
      ['KiB', 1024],
      ['TB', 1000000000000],
      ['GB', 1000000000],
      ['MB', 1000000],
      ['KB', 1000],
      ['B', 1],
    ];

    for (final entry in units) {
      final unit = entry[0] as String;
      final factor = entry[1] as int;
      if (s.toUpperCase().endsWith(unit.toUpperCase())) {
        final numStr = s.substring(0, s.length - unit.length).trim();
        final num = double.tryParse(numStr);
        if (num != null) return (num * factor).round();
        return null;
      }
    }

    return int.tryParse(s);
  }

  /// 解析分享率字符串
  static double? parseRatio(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim();
    if (s == '∞' || s == 'Inf.' || s == 'Infinity' || s == '---') {
      return double.infinity;
    }
    return double.tryParse(s);
  }
}

/// `_pickUserDetailsLink` 的返回值
class _UserPick {
  final String? userId;
  final String? username;
  const _UserPick({this.userId, this.username});
}
