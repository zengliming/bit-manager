import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import 'torrent_client.dart';

class TransmissionService implements ITorrentClientService {
  /// 获取 Session ID（Transmission RPC 需要）
  Future<String?> _getSessionId(ClientConfig config) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.trRpc}',
        data: {'method': 'session-get'},
        options: Options(
          validateStatus: (status) => status == 409,
        ),
      );
      return resp.headers.value('x-transmission-session-id');
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
      final basicAuth =
          base64Encode(utf8.encode('${config.username}:${config.password}'));
      headers['Authorization'] = 'Basic $basicAuth';
    }

    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.trRpc}',
        data: {'method': method, 'arguments': args ?? {}},
        options: Options(headers: headers),
      );
      return resp.data as Map<String, dynamic>;
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
          return retryResp.data as Map<String, dynamic>;
        }
      }
      rethrow;
    }
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
    if (sid == null) throw Exception('Cannot get Transmission session ID');

    final result = await _rpcCall(config, 'torrent-get',
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
            'trackerList',
          ],
        },
        sessionId: sid);

    final arguments = result['arguments'] as Map<String, dynamic>;
    final List<dynamic> rawList = arguments['torrents'] as List<dynamic>;

    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
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
        peersTotal: (m['peersConnected'] as num?)?.toInt() ?? 0,
        seedsTotal: (m['peersSendingToUs'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['errorString'] as String?,
        savePath: m['downloadDir'] as String?,
        addedAt: (m['addedDate'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch(
                (m['addedDate'] as int) * 1000)
            : null,
        completedAt: (m['doneDate'] as num?) != null &&
                (m['doneDate'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                (m['doneDate'] as int) * 1000)
            : null,
        trackers: _parseTrackerList(m['trackerList'] as String? ?? ''),
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

  @override
  Future<ClientStats> getStats(ClientConfig config) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');

    final result = await _rpcCall(config, 'session-stats', sessionId: sid);
    final args = result['arguments'] as Map<String, dynamic>;

    return ClientStats(
      clientId: config.id,
      clientName: config.name,
      type: config.type,
      online: true,
      downloadSpeed: (args['downloadSpeed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (args['uploadSpeed'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> addTorrentFromUrl(
      ClientConfig config, {
        required String url,
        String? savePath,
      }) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final args = <String, dynamic>{'filename': url};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  @override
  Future<void> addTorrentFile(ClientConfig config,
      {required String filePath, String? savePath}) async {
    final fileBytes = await File(filePath).readAsBytes();
    final base64Data = base64Encode(fileBytes);
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final args = <String, dynamic>{'metainfo': base64Data};
    if (savePath != null) args['download-dir'] = savePath;
    await _rpcCall(config, 'torrent-add', args: args, sessionId: sid);
  }

  Future<List<int>> _hashToIds(
      ClientConfig config, List<String> hashes, String sid) async {
    final result = await _rpcCall(config, 'torrent-get',
        args: {'fields': ['id', 'hashString']}, sessionId: sid);
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    return torrents
        .where((t) =>
            hashes.contains((t as Map<String, dynamic>)['hashString'] as String))
        .map((t) => (t as Map<String, dynamic>)['id'] as int)
        .toList();
  }

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(config, 'torrent-stop',
          args: {'ids': ids}, sessionId: sid);
    }
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(config, 'torrent-start',
          args: {'ids': ids}, sessionId: sid);
    }
  }

  @override
  Future<void> deleteTorrent(ClientConfig config, String hash,
      {bool deleteFiles = false}) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isNotEmpty) {
      await _rpcCall(config, 'torrent-remove',
          args: {'ids': ids, 'delete-local-data': deleteFiles},
          sessionId: sid);
    }
  }

  @override
  Future<List<TrackerInfo>> getTrackers(
      ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(config, 'torrent-get',
        args: {'ids': ids, 'fields': ['trackerList', 'trackerStats']},
        sessionId: sid);
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    if (torrents.isEmpty) return [];
    final t = torrents[0] as Map<String, dynamic>;
    final stats = t['trackerStats'] as List<dynamic>? ?? [];
    return stats.map((s) {
      final m = s as Map<String, dynamic>;
      return TrackerInfo(
        url: m['announce'] as String? ?? '',
        status: m['lastAnnounceResult'] as String? ?? '',
        peers: (m['lastAnnouncePeerCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TorrentFile>> getTorrentFiles(
      ClientConfig config, String hash) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return [];
    final result = await _rpcCall(config, 'torrent-get',
        args: {'ids': ids, 'fields': ['files', 'fileStats']},
        sessionId: sid);
    final args = result['arguments'] as Map<String, dynamic>;
    final torrents = args['torrents'] as List<dynamic>;
    if (torrents.isEmpty) return [];
    final t = torrents[0] as Map<String, dynamic>;
    final files = t['files'] as List<dynamic>? ?? [];
    return List.generate(files.length, (i) {
      final f = files[i] as Map<String, dynamic>;
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
      ClientConfig config, String hash, String oldUrl, String newUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls =
        trackers.map((t) => t.url == oldUrl ? newUrl : t.url).toList();
    await _rpcCall(config, 'torrent-set',
        args: {'ids': ids, 'trackerList': urls.join('\n')}, sessionId: sid);
  }

  @override
  Future<void> addTracker(
      ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls = trackers.map((t) => t.url).toList()..add(trackerUrl);
    await _rpcCall(config, 'torrent-set',
        args: {'ids': ids, 'trackerList': urls.join('\n')}, sessionId: sid);
  }

  @override
  Future<void> removeTracker(
      ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _getSessionId(config);
    if (sid == null) throw Exception('Cannot get Transmission session ID');
    final ids = await _hashToIds(config, [hash], sid);
    if (ids.isEmpty) return;
    final trackers = await getTrackers(config, hash);
    final urls =
        trackers.map((t) => t.url).where((u) => u != trackerUrl).toList();
    await _rpcCall(config, 'torrent-set',
        args: {'ids': ids, 'trackerList': urls.join('\n')}, sessionId: sid);
  }
}
