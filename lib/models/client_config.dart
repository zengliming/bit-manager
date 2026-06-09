enum ClientType { qBittorrent, transmission }

class ClientConfig {
  final String id;
  String name;
  ClientType type;
  String host;
  int port;
  String? username;
  String? password;
  bool useSsl;
  bool isActive;
  int timeoutSeconds;
  String? defaultSavePath;
  DateTime addedAt;

  ClientConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.useSsl = false,
    this.isActive = true,
    this.timeoutSeconds = 10,
    this.defaultSavePath,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  String get baseUrl => '${useSsl ? "https" : "http"}://$host:$port';

  ClientConfig copyWith({
    String? name,
    ClientType? type,
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useSsl,
    bool? isActive,
    int? timeoutSeconds,
    String? defaultSavePath,
  }) {
    return ClientConfig(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useSsl: useSsl ?? this.useSsl,
      isActive: isActive ?? this.isActive,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      defaultSavePath: defaultSavePath ?? this.defaultSavePath,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'host': host,
    'port': port,
    'username': username,
    'useSsl': useSsl,
    'isActive': isActive,
    'timeoutSeconds': timeoutSeconds,
    'defaultSavePath': defaultSavePath,
    'addedAt': addedAt.toIso8601String(),
  };

  factory ClientConfig.fromJson(Map<String, dynamic> json) => ClientConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    type: ClientType.values.byName(json['type'] as String),
    host: json['host'] as String,
    port: json['port'] as int,
    username: json['username'] as String?,
    useSsl: json['useSsl'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? true,
    timeoutSeconds: json['timeoutSeconds'] as int? ?? 10,
    defaultSavePath: json['defaultSavePath'] as String?,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
  );
}
