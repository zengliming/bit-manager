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

  SiteConfig({
    required this.id,
    required this.name,
    this.baseUrl,
    List<String>? tags,
    this.notes,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? addedAt,
  })  : tags = tags ?? [],
        addedAt = addedAt ?? DateTime.now();

  SiteConfig copyWith({
    String? name,
    String? baseUrl,
    List<String>? tags,
    String? notes,
    bool? isActive,
    int? sortOrder,
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
      );
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

  const SitePreset({
    required this.id,
    required this.name,
    this.aka = const [],
    this.description,
    this.baseUrl,
    this.tags = const [],
    this.iconAsset,
    this.category,
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
      );
}

/// 站点用户信息 — 通过 Cookie 抓取
class SiteUserInfo {
  final String siteId;
  String? username;
  int? uploaded;
  int? downloaded;
  double? ratio;
  String? level;
  int? bonusPoints;
  int? seedingCount;
  int? leechingCount;
  DateTime? lastFetchedAt;
  bool fetchFailed;

  SiteUserInfo({
    required this.siteId,
    this.username,
    this.uploaded,
    this.downloaded,
    this.ratio,
    this.level,
    this.bonusPoints,
    this.seedingCount,
    this.leechingCount,
    this.lastFetchedAt,
    this.fetchFailed = false,
  });

  Map<String, dynamic> toJson() => {
        'siteId': siteId,
        'username': username,
        'uploaded': uploaded,
        'downloaded': downloaded,
        'ratio': ratio,
        'level': level,
        'bonusPoints': bonusPoints,
        'seedingCount': seedingCount,
        'leechingCount': leechingCount,
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
        'fetchFailed': fetchFailed,
      };

  factory SiteUserInfo.fromJson(Map<String, dynamic> json) => SiteUserInfo(
        siteId: json['siteId'] as String,
        username: json['username'] as String?,
        uploaded: json['uploaded'] as int?,
        downloaded: json['downloaded'] as int?,
        ratio: (json['ratio'] as num?)?.toDouble(),
        level: json['level'] as String?,
        bonusPoints: json['bonusPoints'] as int?,
        seedingCount: json['seedingCount'] as int?,
        leechingCount: json['leechingCount'] as int?,
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
