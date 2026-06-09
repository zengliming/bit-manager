class RssSource {
  final String id;
  String name;
  String url;
  String? filterRegex;
  bool enableRegex;
  bool autoDownload;
  String? assignedClientId;
  int refreshIntervalMinutes;
  String? savePath;
  DateTime? lastFetchedAt;
  DateTime addedAt;

  RssSource({
    required this.id,
    required this.name,
    required this.url,
    this.filterRegex,
    this.enableRegex = true,
    this.autoDownload = false,
    this.assignedClientId,
    this.refreshIntervalMinutes = 15,
    this.savePath,
    this.lastFetchedAt,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'filterRegex': filterRegex,
    'enableRegex': enableRegex,
    'autoDownload': autoDownload,
    'assignedClientId': assignedClientId,
    'refreshIntervalMinutes': refreshIntervalMinutes,
    'savePath': savePath,
    'lastFetchedAt': lastFetchedAt?.toIso8601String(),
    'addedAt': addedAt.toIso8601String(),
  };

  factory RssSource.fromJson(Map<String, dynamic> json) => RssSource(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String,
    filterRegex: json['filterRegex'] as String?,
    enableRegex: json['enableRegex'] as bool? ?? true,
    autoDownload: json['autoDownload'] as bool? ?? false,
    assignedClientId: json['assignedClientId'] as String?,
    refreshIntervalMinutes: json['refreshIntervalMinutes'] as int? ?? 15,
    savePath: json['savePath'] as String?,
    lastFetchedAt: DateTime.tryParse(json['lastFetchedAt'] as String? ?? ''),
    addedAt:
        DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class RssItem {
  final String guid;
  String title;
  String? link;
  String? category;
  DateTime pubDate;
  bool isDuplicate;
  bool isDownloaded;

  RssItem({
    required this.guid,
    required this.title,
    this.link,
    this.category,
    required this.pubDate,
    this.isDuplicate = false,
    this.isDownloaded = false,
  });
}
