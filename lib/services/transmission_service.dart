import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/http_client.dart';
import 'torrent_client.dart';

class TransmissionService implements ITorrentClientService {
  @visibleForTesting
  Future<String?> debugGetSessionIdForTest(ClientConfig config) =>
      _getSessionId(config);

  @visibleForTesting
  Future<Map<String, dynamic>> debugRpcCallForTest(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) => _rpcCall(config, method, args: args, sessionId: sessionId);

  /// 获取 Session ID（Transmission RPC 需要）
  Future<String?> _getSessionId(ClientConfig config) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.trRpc}',
        data: {'method': 'session-get'},
        options: Options(
          validateStatus: (status) =>
              status != null && status >= 200 && status < 500,
        ),
      );
      // 优先从响应头取 session ID
      final sid = resp.headers.value('x-transmission-session-id');
      if (sid != null) return sid;
      // 状态 200 说明已认证成功，使用标记
      if (resp.statusCode == 200) return 'authenticated';
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 带 Session ID 的 RPC 调用
  Future<Map<String, dynamic>> _rpcCall(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    final headers = <String, dynamic>{};
    if (sessionId != null) headers['X-Transmission-Session-Id'] = sessionId;
    if (config.username != null && config.password != null) {
      final basicAuth = base64Encode(
        utf8.encode('${config.username}:${config.password}'),
      );
      headers['Authorization'] = 'Basic $basicAuth';
    }

    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.trRpc}',
        data: {'method': method, 'arguments': args ?? {}},
        options: Options(headers: headers),
      );
      final data = resp.data;
      if (data is! Map<String, dynamic>)
        throw Exception('Invalid RPC response');
      return data;
    } on DioException catch (e) {
      // 如果是 409，尝试重新获取 Session ID 并重试
      if (e.response?.statusCode == 409) {
        final newSid = e.response?.headers.value('x-transmission-session-id');
        if (newSid != null) {
          headers['X-Transmission-Session-Id'] = newSid;
          final retryResp = await dio.post(
            '${config.baseUrl}${AppConstants.trRpc}',
            data: {'method': method, 'arguments': args ?? {}},
            options: Options(headers: headers),
          );
          final retryData = retryResp.data;
          if (retryData is! Map<String, dynamic>)
            throw Exception('Invalid RPC response');
          return retryData;
        }
      }
      rethrow;
    }
  }

  /// 安全获取 Map 值
  Map<String, dynamic> _safeMap(dynamic value) {
    return (value is Map<String, dynamic>) ? value : <String, dynamic>{};
  }

  TorrentState _mapState(int status) {
    switch (status) {
      case 0:
        return TorrentState.paused;
      case 1:
      case 3:
        return TorrentState.queued;
      case 2:
        return TorrentState.checking;
      case 4:
        return TorrentState.downloading;
      case 5:
      case 6:
        return TorrentState.seeding;
      default:
        return TorrentState.unknown;
    }
  }

  @override
  Future<bool> testConnection(ClientConfig config) async {
    final sid = await _getSessionId(config);
    return sid != null;
  }

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final sid = await _getSessionId(config);

    final result = await _rpcCall(
      config,
      'torrent-get',
      args: {
        'fields': [
          'id',
          'hashString',
          'name',
          'status',
          'percentDone',
          'rateDownload',
          'rateUpload',
          'downloadedEver',
          'uploadedEver',
          'totalSize',
          'uploadRatio',
          'peersConnected',
          'peersSendingToUs',
          'peersGettingFromUs',
          'peersFrom',
          'eta',
          'error',
          'errorString',
          'downloadDir',
          'addedDate',
          'doneDate',
          'activityDate',
          'trackerList',
          'trackerStats',
        ],
      },
      sessionId: sid,
    );

    final arguments = result['arguments'];
    final argsMap = (arguments is Map<String, dynamic>)
        ? arguments
        : <String, dynamic>{};
    final torrentsRaw = argsMap['torrents'];
    final List<dynamic> rawList = (torrentsRaw is List) ? torrentsRaw : [];

    return rawList.map((json) {
      final m = (json is Map<String, dynamic>) ? json : <String, dynamic>{};
      return Torrent(
        id: (m['id'] as num).toString(),
        hash: m['hashString'] as String? ?? '',
        name: m['name'] as String? ?? 'Unknown',
        clientId: config.id,
        clientType: config.type,
        progress: (m['percentDone'] as num?)?.toDouble() ?? 0,
        state: _mapState((m['status'] as num?)?.toInt() ?? 0),
        downloadSpeed: (m['rateDownload'] as num?)?.toInt() ?? 0,
        uploadSpeed: (m['rateUpload'] as num?)?.toInt() ?? 0,
        downloaded: (m['downloadedEver'] as num?)?.toInt() ?? 0,
        uploaded: (m['uploadedEver'] as num?)?.toInt() ?? 0,
        totalSize: (m['totalSize'] as num?)?.toInt() ?? 0,
        ratio: (m['uploadRatio'] as num?)?.toDouble() ?? 0,
        peersConnected: (m['peersConnected'] as num?)?.toInt() ?? 0,
        seedsConnected: (m['peersSendingToUs'] as num?)?.toInt() ?? 0,
        // Transmission 标准接口不返回 swarm 总做种/下载者数，置 0 避免给出错误的同源值
        peersTotal: 0,
        seedsTotal: 0,
        // leechers 字段映射到已连接下载者数（peersGettingFromUs）
        leechers: (m['peersGettingFromUs'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['errorString'] as String?,
        savePath: m['downloadDir'] as String?,
        addedAt: (m['addedDate'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (m['addedDate'] as int) * 1000,
              )
            : null,
        completedAt:
            (m['doneDate'] as num?) != null && (m['doneDate'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch((m['doneDate'] as int) * 1000)
            : null,
        lastActivity:
            (m['activityDate'] as num?) != null &&
                (m['activityDate'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                (m['activityDate'] as int) * 1000,
              )
            : null,
        site: extractSiteFromUrl(
          _parseTrackerList(m['trackerList'] as String? ?? '').firstOrNull,
        ),
        trackers: _parseTrackerList(m['trackerList'] as String? ?? ''),
        trackerStatuses: _parseTrackerStatuses(m['trackerStats']),
      );
    }).toList();
  }

  List<String> _parseTrackerList(String trackerList) {
    return trackerList
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trim())
        .toList();
  }

  List<String> _parseTrackerStatuses(dynamic trackerStatsRaw) {
    final stats = (trackerStatsRaw is List) ? trackerStatsRaw : <dynamic>[];
    return stats
        .map(
          (s) => (s is Map<String, dynamic>)
              ? s['lastAnnounceResult'] as String? ?? ''
              : '',
        )
        .where((status) => status.isNotEmpty)
        .toList();
  }

  @override
  Future<ClientStats> getStats(ClientConfig config) async {
    final sid = await _getSessionId(config);

    final result = await _rpcCall(config, 'session-stats', sessionId: sid);
    final args = _safeMap(result['arguments']);

    return ClientStats(
      clientId: config.id,
      clientName: config.name,
      type: config.type,
      online: sid != null,
      downloadSpeed: (args['downloadSpeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (args['uploadSpeed'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<int> getFreeSpace(ClientConfig config) async {
    try {
      // 先获取默认下载目录
      final sid = await _getSessionId(config);
      final sessResult = await _rpcCall(
        config,
        'session-get',
        args: {
          'fields': ['download-dir'],
        },
        sessionId: sid,
      );
      final sessArgs = _safeMap(sessResult['arguments']);
      final downloadDir = sessArgs['download-dir'] as String? ?? '/downloads';

      // 查询 free-space
      final freeResult = await _rpcCall(
        config,
        'free-space',
        args: {'path': downloadDir},
        sessionId: sid,
      );
      final freeArgs = _safeMap(freeResult['arguments']);
      return (freeArgs['size'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async {
    try {
      final sid = await _getSessionId(config);
      final result = await _rpcCall(
        config,
        'session-get',
        args: {
          'fields': [
            'speed-limit-down',
            'speed-limit-down-enabled',
            'speed-limit-up',
            'speed-limit-up-enabled',
          ],
        },
        sessionId: sid,
      );
      final args = _safeMap(result['arguments']);

      // Transmission 限速单位是 KB/s
      final dlEnabled = args['speed-limit-down-enabled'] == true;
      final ulEnabled = args['speed-limit-up-enabled'] == true;
      final dlLimit = (args['speed-limit-down'] as num?)?.toInt() ?? 0;
      final ulLimit = (args['speed-limit-up'] as num?)?.toInt() ?? 0;

      return [dlEnabled ? dlLimit * 1024 : 0, ulEnabled ? ulLimit * 1024 : 0];
    } catch (_) {
      return [0, 0];
    }
  }

  @override
  Future<void> addTorrentFromUrl(
    ClientConfig config, {
    required String url,
    String? savePath,
  }) async {
    final sid = await _getSessionId(config);
    final args = <String, dynamic>{'filename': url};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  @override
  Future<void> addTorrentFile(
    ClientConfig config, {
    required String filePath,
    String? savePath,
  }) async {
    final fileBytes = await File(filePath).readAsBytes();
    final base64Data = base64Encode(fileBytes);
    final sid = await _getSessionId(config);
    final args = <String, dynamic>{'metainfo': base64Data};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  Future<List<int>> _hashToIds(
    ClientConfig config,
    List<String> hashes,
    String? sid,
  ) async {
    final result = await debugRpcCallForTest(
      config,
      'torrent-get',
      args: {
        'fields': ['id', 'hashString'],
      },
      sessionId: sid,
    );
    final args = _safeMap(result['arguments']);
    final torrentsRaw = args['torrents'];
    final torrents = (torrentsRaw is List) ? torrentsRaw : <dynamic>[];
    final ids = <int>[];
    for (final t in torrents) {
      if (t is! Map<String, dynamic>) continue;
      final hash = t['hashString'] as String? ?? '';
      if (hashes.contains(hash)) {
        final id = t['id'] as int?;
        if (id != null) ids.add(id);
      }
    }
    return ids;
  }

  Future<List<int>> _hashToIdsOrThrow(
    ClientConfig config,
    List<String> hashes,
    String? sid,
  ) async {
    final ids = await _hashToIds(config, hashes, sid);
    if (ids.length != hashes.toSet().length) {
      throw Exception(
        'Unable to resolve torrent hashes: expected ${hashes.toSet().length}, found ${ids.length}',
      );
    }
    return ids;
  }

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-stop',
        args: {'ids': ids},
        sessionId: sid,
      );
    }
  }

  @override
  Future<void> pauseTorrents(ClientConfig config, List<String> hashes) async {
    if (hashes.isEmpty) return;
    final sid = await debugGetSessionIdForTest(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-stop',
        args: {'ids': ids},
        sessionId: sid,
      );
    }
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-start',
        args: {'ids': ids},
        sessionId: sid,
      );
    }
  }

  @override
  Future<void> resumeTorrents(ClientConfig config, List<String> hashes) async {
    if (hashes.isEmpty) return;
    final sid = await debugGetSessionIdForTest(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-start',
        args: {'ids': ids},
        sessionId: sid,
      );
    }
  }

  @override
  Future<void> deleteTorrent(
    ClientConfig config,
    String hash, {
    bool deleteFiles = false,
  }) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-remove',
        args: {'ids': ids, 'delete-local-data': deleteFiles},
        sessionId: sid,
      );
    }
  }

  @override
  Future<void> deleteTorrents(
    ClientConfig config,
    List<String> hashes, {
    bool deleteFiles = false,
  }) async {
    if (hashes.isEmpty) return;
    final sid = await debugGetSessionIdForTest(config);
    final ids = await _hashToIdsOrThrow(config, hashes, sid);
    if (ids.isNotEmpty) {
      await _rpcCall(
        config,
        'torrent-remove',
        args: {'ids': ids, 'delete-local-data': deleteFiles},
        sessionId: sid,
      );
    }
  }

  @override
  Future<List<TrackerInfo>> getTrackers(
    ClientConfig config,
    String hash,
  ) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(
      config,
      'torrent-get',
      args: {
        'ids': ids,
        'fields': ['trackerList', 'trackerStats'],
      },
      sessionId: sid,
    );
    final args = _safeMap(result['arguments']);
    final torrentsRaw = args['torrents'];
    final torrents = (torrentsRaw is List) ? torrentsRaw : <dynamic>[];
    if (torrents.isEmpty) return [];
    final t = (torrents[0] is Map<String, dynamic>)
        ? torrents[0] as Map<String, dynamic>
        : <String, dynamic>{};
    final statsRaw = t['trackerStats'];
    final stats = (statsRaw is List) ? statsRaw : <dynamic>[];
    return stats.map((s) {
      final m = (s is Map<String, dynamic>) ? s : <String, dynamic>{};
      return TrackerInfo(
        url: m['announce'] as String? ?? '',
        status: m['lastAnnounceResult'] as String? ?? '',
        peers: (m['lastAnnouncePeerCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TorrentFile>> getTorrentFiles(
    ClientConfig config,
    String hash,
  ) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(
      config,
      'torrent-get',
      args: {
        'ids': ids,
        'fields': ['files', 'fileStats'],
      },
      sessionId: sid,
    );
    final args = _safeMap(result['arguments']);
    final torrentsRaw = args['torrents'];
    final torrents = (torrentsRaw is List) ? torrentsRaw : <dynamic>[];
    if (torrents.isEmpty) return [];
    final t = (torrents[0] is Map<String, dynamic>)
        ? torrents[0] as Map<String, dynamic>
        : <String, dynamic>{};
    final filesRaw = t['files'];
    final files = (filesRaw is List) ? filesRaw : <dynamic>[];
    return List.generate(files.length, (i) {
      final f = (files[i] is Map<String, dynamic>)
          ? files[i] as Map<String, dynamic>
          : <String, dynamic>{};
      final completed = (f['bytesCompleted'] as num?)?.toDouble() ?? 0;
      final length = (f['length'] as num?)?.toDouble() ?? 1;
      return TorrentFile(
        name: f['name'] as String? ?? '',
        size: (f['length'] as num?)?.toInt() ?? 0,
        progress: completed / length,
      );
    });
  }

  @override
  Future<bool> isTorrentExist(ClientConfig config, String hash) async {
    try {
      final torrents = await getTorrents(config);
      return torrents.any((t) => t.hash == hash);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceTracker(
    ClientConfig config,
    String hash,
    String oldUrl,
    String newUrl,
  ) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url == oldUrl ? newUrl : t.url).toList();
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }

  @override
  Future<void> addTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url).toList()..add(trackerUrl);
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }

  @override
  Future<void> removeTracker(
    ClientConfig config,
    String hash,
    String trackerUrl,
  ) async {
    final sid = await _getSessionId(config);
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls = trackers
        .map((t) => t.url)
        .where((u) => u != trackerUrl)
        .toList();
    await _rpcCall(
      config,
      'torrent-set',
      args: {'ids': ids, 'trackerList': urls.join('\n')},
      sessionId: sid,
    );
  }
}
