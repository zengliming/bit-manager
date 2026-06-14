// lib/models/site_config.dart

/// 站点配置 — 用户管理的站点实体
class SiteConfig {
  final String id;
  String name;
  String? baseUrl;
  List<String> tags;
  String? notes;
  bool isActive;
  int sortOrder;
  DateTime addedAt;

  /// 站点解析配置（可选）。从预设导入时复制 SitePreset.parseSchema；
  /// 用户手动添加的非预设站点可在站点表单中填写。
  SiteParseSchema? parseSchema;

  SiteConfig({
    required this.id,
    required this.name,
    this.baseUrl,
    List<String>? tags,
    this.notes,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? addedAt,
    this.parseSchema,
  })  : tags = tags ?? [],
        addedAt = addedAt ?? DateTime.now();

  SiteConfig copyWith({
    String? name,
    String? baseUrl,
    List<String>? tags,
    String? notes,
    bool? isActive,
    int? sortOrder,
    SiteParseSchema? parseSchema,
  }) {
    return SiteConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      tags: tags ?? List.from(this.tags),
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt,
      parseSchema: parseSchema ?? this.parseSchema,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'tags': tags,
        'notes': notes,
        'isActive': isActive,
        'sortOrder': sortOrder,
        'addedAt': addedAt.toIso8601String(),
        if (parseSchema != null) 'parseSchema': parseSchema!.toJson(),
      };

  factory SiteConfig.fromJson(Map<String, dynamic> json) => SiteConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        notes: json['notes'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        sortOrder: json['sortOrder'] as int? ?? 0,
        addedAt:
            DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
        parseSchema: json['parseSchema'] is Map<String, dynamic>
            ? SiteParseSchema.fromJson(
                json['parseSchema'] as Map<String, dynamic>)
            : null,
      );
}

/// 站点解析 schema — 自定义某个站点的 td.rowhead 标签词、url 路径等
///
/// 用于覆写默认 NexusPHP 解析行为。例如 13city 的"魔力值"叫"啤酒瓶"，
/// 就可以在预设里加 `"bonusLabels": ["啤酒瓶", "Karma Points"]`。
///
/// 所有字段可选；空时使用默认 NexusPHP 标签。设计上对齐 PT-depiler
/// `definitions/<site>.ts` 中 `userInfo.selectors` 的 `selector + filters` 结构，
/// 但简化为标签字符串列表（不允许任意 JS 代码）。
/// 站点解析 schema — 自定义某个站点的 selector + filter
///
/// 设计对齐 PT-depiler 的 `userInfo.selectors`：每个字段一个
/// `{ selector: [...], attr?, filters?: [...] }` 描述符。
///
/// JSON 形态：
/// ```json
/// "parseSchema": {
///   "userDetailsPath": "/userdetails.php",
///   "fields": {
///     "bonus": {
///       "selector": ["td.rowhead:contains('啤酒瓶') + td"],
///       "filter": "parseNumber"
///     },
///     "levelName": {
///       "selector": ["td.rowhead:contains('等级') + td > img"],
///       "attr": "title"
///     },
///     "joinTime": {
///       "selector": ["td.rowhead:contains('加入日期') + td"],
///       "filter": { "name": "split", "args": ["(", 0] }
///     }
///   }
/// }
/// ```
///
/// 旧版 `bonusLabels: [...]` 等"标签词列表"字段仍保留，作为
/// `fields` 的语法糖（运行时合并）。
class SiteParseSchema {
  /// 站点架构类型：当前支持 'NexusPHP' / 'Gazelle' / null（自动）
  final String? schema;

  /// 详情页路径，默认 `/userdetails.php`
  final String? userDetailsPath;

  /// PT-depiler 风格的字段定义。键名为字段名（与 SiteUserInfo 字段对应）：
  /// `bonus / levelName / uploaded / downloaded / ratio / joinTime /
  ///  seeding / seedingSize / messageCount / bonusPerHour / lastAccessAt /
  ///  hnrPreWarning / hnrUnsatisfied`
  final Map<String, FieldRule>? fields;

  // ── 旧版"标签词列表"语法糖，保留以兼容已存储的用户数据 ──
  final List<String>? usernameLabels;
  final List<String>? levelLabels;
  final List<String>? transferLabels;
  final List<String>? bonusLabels;
  final List<String>? joinTimeLabels;
  final List<String>? seedingLabels;
  final List<String>? leechingLabels;

  const SiteParseSchema({
    this.schema,
    this.userDetailsPath,
    this.fields,
    this.usernameLabels,
    this.levelLabels,
    this.transferLabels,
    this.bonusLabels,
    this.joinTimeLabels,
    this.seedingLabels,
    this.leechingLabels,
  });

  factory SiteParseSchema.fromJson(Map<String, dynamic> json) {
    Map<String, FieldRule>? fields;
    if (json['fields'] is Map) {
      fields = <String, FieldRule>{};
      (json['fields'] as Map).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          fields![k.toString()] = FieldRule.fromJson(v);
        } else if (v is Map) {
          fields![k.toString()] =
              FieldRule.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }
    return SiteParseSchema(
      schema: json['schema'] as String?,
      userDetailsPath: json['userDetailsPath'] as String?,
      fields: fields,
      usernameLabels: (json['usernameLabels'] as List?)?.cast<String>(),
      levelLabels: (json['levelLabels'] as List?)?.cast<String>(),
      transferLabels: (json['transferLabels'] as List?)?.cast<String>(),
      bonusLabels: (json['bonusLabels'] as List?)?.cast<String>(),
      joinTimeLabels: (json['joinTimeLabels'] as List?)?.cast<String>(),
      seedingLabels: (json['seedingLabels'] as List?)?.cast<String>(),
      leechingLabels: (json['leechingLabels'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (schema != null) 'schema': schema,
        if (userDetailsPath != null) 'userDetailsPath': userDetailsPath,
        if (fields != null)
          'fields': fields!.map((k, v) => MapEntry(k, v.toJson())),
        if (usernameLabels != null) 'usernameLabels': usernameLabels,
        if (levelLabels != null) 'levelLabels': levelLabels,
        if (transferLabels != null) 'transferLabels': transferLabels,
        if (bonusLabels != null) 'bonusLabels': bonusLabels,
        if (joinTimeLabels != null) 'joinTimeLabels': joinTimeLabels,
        if (seedingLabels != null) 'seedingLabels': seedingLabels,
        if (leechingLabels != null) 'leechingLabels': leechingLabels,
      };
}

/// 单个字段的解析规则
///
/// 至少要提供 [selector]。其它都可选：
/// - [attr]：取属性值而非元素文本（如 `<img title="VIP">` 取 title）
/// - [filter]：过滤器，可以是字符串名（"parseNumber"）或 Map（{"name": "split", "args": [...]}）
/// - [filters]：多个过滤器顺序应用（PT-depiler 用法，比单个 filter 更灵活）
/// - [contains]：元素 textContent 必须包含的子串（用于扁平筛选）
class FieldRule {
  /// CSS 选择器列表，按顺序尝试，首个非空结果获胜
  final List<String> selector;

  /// 取属性而非文本（"title" / "alt" / "href" 等）
  final String? attr;

  /// 单个过滤器（字符串或 Map）
  final Object? filter;

  /// 多个过滤器顺序应用
  final List<Object>? filters;

  /// 文本必须包含子串
  final String? contains;

  const FieldRule({
    required this.selector,
    this.attr,
    this.filter,
    this.filters,
    this.contains,
  });

  factory FieldRule.fromJson(Map<String, dynamic> json) {
    final selRaw = json['selector'];
    final selectors = <String>[];
    if (selRaw is String) {
      selectors.add(selRaw);
    } else if (selRaw is List) {
      for (final s in selRaw) {
        if (s is String) selectors.add(s);
      }
    }
    // 兼容单数 `filter` 和复数 `filters`：都规范成 `filters` 列表。
    // 编辑器保存时会优先用 `filter`（count==1），但 _runFieldRule 只看 `filters`，
    // 不规范化会导致「单 filter 规则保存后再加载丢失」。
    List<Object> filters = [];
    final filtersRaw = json['filters'];
    if (filtersRaw is List) {
      for (final f in filtersRaw) {
        if (f is String) filters.add(f);
        if (f is Map) filters.add(Map<String, dynamic>.from(f));
      }
    }
    final singleFilter = json['filter'];
    if (singleFilter != null && filters.isEmpty) {
      filters.add(singleFilter);
    }
    return FieldRule(
      selector: selectors,
      attr: json['attr'] as String?,
      filters: filters,
      contains: json['contains'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'selector': selector,
        if (attr != null) 'attr': attr,
        if (filter != null) 'filter': filter,
        if (filters != null) 'filters': filters,
        if (contains != null) 'contains': contains,
      };
}

/// 站点预设 — 内置只读数据，从 assets/sites/presets.json 加载
class SitePreset {
  final String id;
  final String name;
  final List<String> aka;
  final String? description;
  final String? baseUrl;
  final List<String> tags;
  final String? iconAsset;
  final String? category;

  /// 站点解析覆写（可选）。如不提供则使用通用 NexusPHP/Gazelle 默认解析。
  final SiteParseSchema? parseSchema;

  const SitePreset({
    required this.id,
    required this.name,
    this.aka = const [],
    this.description,
    this.baseUrl,
    this.tags = const [],
    this.iconAsset,
    this.category,
    this.parseSchema,
  });

  factory SitePreset.fromJson(Map<String, dynamic> json) => SitePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        aka: (json['aka'] as List?)?.cast<String>() ?? [],
        description: json['description'] as String?,
        baseUrl: json['baseUrl'] as String?,
        tags: (json['tags'] as List?)?.cast<String>() ?? [],
        iconAsset: json['iconAsset'] as String?,
        category: json['category'] as String?,
        parseSchema: json['parseSchema'] is Map<String, dynamic>
            ? SiteParseSchema.fromJson(
                json['parseSchema'] as Map<String, dynamic>)
            : null,
      );
}

/// 站点用户信息 — 通过 Cookie 抓取
class SiteUserInfo {
  final String siteId;
  String? userId;
  String? username;
  int? uploaded;
  int? downloaded;
  /// 真实/实际上传量（NexusPHP 部分站点显示扣除做种加成后的）
  int? trueUploaded;
  /// 真实/实际下载量
  int? trueDownloaded;
  double? ratio;
  String? level;
  int? bonusPoints;
  /// 做种积分（与魔力值是不同的字段）
  num? seedingBonus;
  /// 时魔（每小时获得的魔力）
  num? bonusPerHour;
  int? seedingCount;
  int? leechingCount;
  /// 做种总体积（字节）
  int? seedingSize;
  /// 未读消息数
  int? messageCount;
  /// H&R 待考核数
  int? hnrPreWarning;
  /// H&R 不达标数
  int? hnrUnsatisfied;
  String? joinedAtText;
  /// 最近动向（最近一次站点活动时间，原文）
  String? lastAccessAtText;
  DateTime? lastFetchedAt;
  bool fetchFailed;

  SiteUserInfo({
    required this.siteId,
    this.userId,
    this.username,
    this.uploaded,
    this.downloaded,
    this.trueUploaded,
    this.trueDownloaded,
    this.ratio,
    this.level,
    this.bonusPoints,
    this.seedingBonus,
    this.bonusPerHour,
    this.seedingCount,
    this.leechingCount,
    this.seedingSize,
    this.messageCount,
    this.hnrPreWarning,
    this.hnrUnsatisfied,
    this.joinedAtText,
    this.lastAccessAtText,
    this.lastFetchedAt,
    this.fetchFailed = false,
  });

  Map<String, dynamic> toJson() => {
        'siteId': siteId,
        'userId': userId,
        'username': username,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'trueUploaded': trueUploaded,
        'trueDownloaded': trueDownloaded,
        'ratio': ratio,
        'level': level,
        'bonusPoints': bonusPoints,
        'seedingBonus': seedingBonus,
        'bonusPerHour': bonusPerHour,
        'seedingCount': seedingCount,
        'leechingCount': leechingCount,
        'seedingSize': seedingSize,
        'messageCount': messageCount,
        'hnrPreWarning': hnrPreWarning,
        'hnrUnsatisfied': hnrUnsatisfied,
        'joinedAtText': joinedAtText,
        'lastAccessAtText': lastAccessAtText,
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
        'fetchFailed': fetchFailed,
      };

  factory SiteUserInfo.fromJson(Map<String, dynamic> json) => SiteUserInfo(
        siteId: json['siteId'] as String,
        userId: json['userId'] as String?,
        username: json['username'] as String?,
        uploaded: json['uploaded'] as int?,
        downloaded: json['downloaded'] as int?,
        trueUploaded: json['trueUploaded'] as int?,
        trueDownloaded: json['trueDownloaded'] as int?,
        ratio: (json['ratio'] as num?)?.toDouble(),
        level: json['level'] as String?,
        bonusPoints: json['bonusPoints'] as int?,
        seedingBonus: json['seedingBonus'] as num?,
        bonusPerHour: json['bonusPerHour'] as num?,
        seedingCount: json['seedingCount'] as int?,
        leechingCount: json['leechingCount'] as int?,
        seedingSize: json['seedingSize'] as int?,
        messageCount: json['messageCount'] as int?,
        hnrPreWarning: json['hnrPreWarning'] as int?,
        hnrUnsatisfied: json['hnrUnsatisfied'] as int?,
        joinedAtText: json['joinedAtText'] as String?,
        lastAccessAtText: json['lastAccessAtText'] as String?,
        lastFetchedAt: DateTime.tryParse(json['lastFetchedAt'] as String? ?? ''),
        fetchFailed: json['fetchFailed'] as bool? ?? false,
      );
}

/// Cookie 存储 — 存 SecureStorage，此类只作内存载体
class SiteCookie {
  final String siteId;
  String? cookieString;
  DateTime? lastUpdatedAt;
  bool isLoginValid;

  SiteCookie({
    required this.siteId,
    this.cookieString,
    this.lastUpdatedAt,
    this.isLoginValid = false,
  });
}
