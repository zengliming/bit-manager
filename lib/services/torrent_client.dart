import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';

/// 统一 BitTorrent 客户端 API 抽象
abstract class ITorrentClientService {
  /// 测试连接是否可用
  Future<bool> testConnection(ClientConfig config);

  /// 获取所有种子
  Future<List<Torrent>> getTorrents(ClientConfig config);

  /// 获取种子文件列表
  Future<List<TorrentFile>> getTorrentFiles(ClientConfig config, String hash);

  /// 获取种子的 Tracker 列表
  Future<List<TrackerInfo>> getTrackers(ClientConfig config, String hash);

  /// 添加种子（本地文件）
  Future<void> addTorrentFile(
    ClientConfig config, {
    required String filePath,
    String? savePath,
  });

  /// 通过链接添加种子
  Future<void> addTorrentFromUrl(
    ClientConfig config, {
    required String url,
    String? savePath,
  });

  /// 暂停种子
  Future<void> pauseTorrent(ClientConfig config, String hash);

  /// 批量暂停种子
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes);

  /// 恢复种子
  Future<void> resumeTorrent(ClientConfig config, String hash);

  /// 批量恢复种子
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes);

  /// 删除种子
  Future<void> deleteTorrent(
    ClientConfig config,
    String hash, {
    bool deleteFiles = false,
  });

  /// 批量删除种子
  Future<void> deleteTorrents(
    ClientConfig config,
    List<String> hashes, {
    bool deleteFiles = false,
  });

  /// 替换 Tracker
  Future<void> replaceTracker(
    ClientConfig config,
    String hash,
    String oldUrl,
    String newUrl,
  );

  /// 添加 Tracker
  Future<void> addTracker(ClientConfig config, String hash, String trackerUrl);

  /// 移除 Tracker
  Future<void> removeTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  );

  /// 批量添加 Tracker：给 [hashes] 中每个种子追加 [trackerUrls] 里的全部 Tracker
  Future<void> addTrackers(
    ClientConfig config,
    List<String> hashes,
    List<String> trackerUrls,
  );

  /// 批量替换 Tracker：把 [hashes] 中每个种子的 [oldUrl] Tracker 换成 [newUrl]
  Future<void> replaceTrackers(
    ClientConfig config,
    List<String> hashes,
    String oldUrl,
    String newUrl,
  );

  /// 批量移除 Tracker：从 [hashes] 中每个种子删除 [trackerUrl] Tracker
  Future<void> removeTrackers(
    ClientConfig config,
    List<String> hashes,
    String trackerUrl,
  );

  /// 检查种子是否已存在
  Future<bool> isTorrentExist(ClientConfig config, String hash);

  /// 获取客户端统计
  Future<ClientStats> getStats(ClientConfig config);

  /// 获取客户端剩余磁盘空间（字节），0=未知
  Future<int> getFreeSpace(ClientConfig config);

  /// 获取速度限制，返回 [downloadLimit, uploadLimit] 字节/秒，0=不限速
  Future<List<int>> getSpeedLimits(ClientConfig config);
}

class TorrentFile {
  final String name;
  final int size;
  final double progress;
  final int priority;

  TorrentFile({
    required this.name,
    required this.size,
    required this.progress,
    this.priority = 0,
  });
}

class TrackerInfo {
  final String url;
  final String status;
  final int peers;

  TrackerInfo({required this.url, required this.status, this.peers = 0});
}
