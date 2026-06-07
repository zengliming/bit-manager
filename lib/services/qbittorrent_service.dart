import 'package:dio/dio.dart';
import '../models/client_config.dart';
import '../models/torrent.dart';
import '../models/stats.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import 'torrent_client.dart';

class QBittorrentService implements ITorrentClientService {
  /// SID 缓存：clientId → sid，复用会话避免重复登录
  final Map<String, String> _sidCache = {};

  /// 登录并获取 SID
  Future<String?> _login(ClientConfig config) async {
    // 如果已有缓存的 SID，直接返回（通常有效，失败时下游会触发重试）
    if (_sidCache.containsKey(config.id)) {
      return _sidCache[config.id];
    }
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      final resp = await dio.post(
        '${config.baseUrl}${AppConstants.qbLogin}',
        data: {
          'username': config.username ?? '',
          'password': config.password ?? '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      // qB 返回 SID 在 Set-Cookie 中
      final setCookie = resp.headers.value('set-cookie');
      if (setCookie != null && setCookie.contains('SID=')) {
        final match = RegExp(r'SID=([^;]+)').firstMatch(setCookie);
        final sid = match?.group(1);
        if (sid != null) {
          _sidCache[config.id] = sid;
        }
        return sid;
      }
      return null;
    } catch (_) {
      _sidCache.remove(config.id);
      return null;
    }
  }

  /// 携带 SID Cookie 的 GET 请求
  Future<Response> _get(ClientConfig config, String path,
      {Map<String, dynamic>? params, String? sid}) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      return await dio.get(
        '${config.baseUrl}$path',
        queryParameters: params,
        options: Options(headers: {'Cookie': 'SID=$sid'}),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _sidCache.remove(config.id);
      }
      rethrow;
    }
  }

  /// 携带 SID Cookie 的 POST 请求
  Future<Response> _post(ClientConfig config, String path,
      {Map<String, dynamic>? data, String? sid}) async {
    final dio = HttpClientUtil.instance.createClientDio(config);
    try {
      return await dio.post(
        '${config.baseUrl}$path',
        data: data,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Cookie': 'SID=$sid'},
        ),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        _sidCache.remove(config.id);
      }
      rethrow;
    }
  }

  TorrentState _mapState(String rawState) {
    switch (rawState) {
      case 'downloading':
        return TorrentState.downloading;
      case 'seeding':
        return TorrentState.seeding;
      case 'pausedUP':
      case 'pausedDL':
        return TorrentState.paused;
      case 'checkingUP':
      case 'checkingDL':
        return TorrentState.checking;
      case 'queuedUP':
      case 'queuedDL':
        return TorrentState.queued;
      case 'stalledUP':
        return TorrentState.seeding;
      case 'stalledDL':
        return TorrentState.downloading;
      case 'metaDL':
        return TorrentState.metaDL;
      case 'error':
      case 'missingFiles':
        return TorrentState.error;
      default:
        return TorrentState.unknown;
    }
  }

  @override
  Future<bool> testConnection(ClientConfig config) async {
    final sid = await _login(config);
    return sid != null;
  }

  @override
  Future<List<Torrent>> getTorrents(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');

    final resp = await _get(config, AppConstants.qbTorrents, sid: sid);
    final rawData = resp.data;
    final List<dynamic> rawList = (rawData is List) ? rawData : [];
    final torrents = <Torrent>[];
    for (final json in rawList) {
      final m = (json is Map<String, dynamic>) ? json : <String, dynamic>{};
      final hash = m['hash'] as String? ?? '';
      final trackers = (m['tracker'] as String?) != null && (m['tracker'] as String).isNotEmpty
          ? [(m['tracker'] as String)]
          : <String>[];
      final trackerStatuses = <String>[];
      if (hash.isNotEmpty) {
        try {
          final trackerInfos = await getTrackers(config, hash);
          trackerStatuses.addAll(trackerInfos.map((tracker) => tracker.status));
          if (trackers.isEmpty) {
            trackers.addAll(trackerInfos.map((tracker) => tracker.url).where((url) => url.isNotEmpty));
          }
        } catch (_) {}
      }

      torrents.add(Torrent(
        id: hash,
        hash: hash,
        name: m['name'] as String? ?? 'Unknown',
        clientId: config.id,
        clientType: config.type,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        state: _mapState(m['state'] as String? ?? ''),
        downloadSpeed: (m['dlspeed'] as num?)?.toInt() ?? 0,
        uploadSpeed: (m['upspeed'] as num?)?.toInt() ?? 0,
        downloaded: (m['downloaded'] as num?)?.toInt() ?? 0,
        uploaded: (m['uploaded'] as num?)?.toInt() ?? 0,
        totalSize: (m['total_size'] as num?)?.toInt() ?? 0,
        ratio: (m['ratio'] as num?)?.toDouble() ?? 0,
        peersConnected: (m['num_leechs'] as num?)?.toInt() ?? 0,
        seedsConnected: (m['num_seeds'] as num?)?.toInt() ?? 0,
        peersTotal: (m['num_incomplete'] as num?)?.toInt() ?? 0,
        seedsTotal: (m['num_complete'] as num?)?.toInt() ?? 0,
        eta: (m['eta'] as num?)?.toInt() ?? 0,
        error: m['error'] as String?,
        savePath: m['save_path'] as String?,
        trackers: trackers,
        trackerStatuses: trackerStatuses,
        addedAt: (m['added_on'] as num?) != null
            ? DateTime.fromMillisecondsSinceEpoch((m['added_on'] as int) * 1000)
            : null,
        completedAt: (m['completion_on'] as num?) != null && (m['completion_on'] as int) > 0
            ? DateTime.fromMillisecondsSinceEpoch((m['completion_on'] as int) * 1000)
            : null,
      ));
    }
    return torrents;
  }

  @override
  Future<ClientStats> getStats(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');

    final transferResp =
        await _get(config, AppConstants.qbTransferInfo, sid: sid);
    final transfer = transferResp.data as Map<String, dynamic>;

    return ClientStats(
      clientId: config.id,
      clientName: config.name,
      type: config.type,
      online: true,
      downloadSpeed: (transfer['dl_info_speed'] as num?)?.toInt() ?? 0,
      uploadSpeed: (transfer['up_info_speed'] as num?)?.toInt() ?? 0,
      sizeOnDisk: 0,
    );
  }

  @override
  Future<int> getFreeSpace(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) return 0;
    try {
      final resp = await _get(config, '/api/v2/sync/maindata', sid: sid);
      final data = resp.data as Map<String, dynamic>? ?? {};
      final serverState = data['server_state'] as Map<String, dynamic>? ?? {};
      return (serverState['freeSpaceOnDisk'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<int>> getSpeedLimits(ClientConfig config) async {
    final sid = await _login(config);
    if (sid == null) return [0, 0];
    try {
      final dlResp = await _get(config, '/api/v2/transfer/downloadLimit', sid: sid);
      final dlData = dlResp.data as Map<String, dynamic>? ?? {};
      final dlLimit = (dlData['limit'] as num?)?.toInt() ?? 0;

      final ulResp = await _get(config, '/api/v2/transfer/uploadLimit', sid: sid);
      final ulData = ulResp.data as Map<String, dynamic>? ?? {};
      final ulLimit = (ulData['limit'] as num?)?.toInt() ?? 0;

      return [dlLimit, ulLimit];
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
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final dio = HttpClientUtil.instance.createClientDio(config);
    final data = <String, dynamic>{'urls': url};
    if (savePath != null) data['savepath'] = savePath;
    await dio.post(
      '${config.baseUrl}${AppConstants.qbTorrentAdd}',
      data: data,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Cookie': 'SID=$sid'},
      ),
    );
  }

  @override
  Future<void> addTorrentFile(ClientConfig config,
      {required String filePath, String? savePath}) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final dio = HttpClientUtil.instance.createClientDio(config);
    final formData = FormData.fromMap({
      'torrents': await MultipartFile.fromFile(filePath),
      if (savePath != null) 'savepath': savePath,
    });
    await dio.post(
      '${config.baseUrl}${AppConstants.qbTorrentAdd}',
      data: formData,
      options: Options(headers: {'Cookie': 'SID=$sid'}),
    );
  }

  @override
  Future<void> pauseTorrent(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentPause,
        data: {'hashes': hash}, sid: sid);
  }

  @override
  Future<void> resumeTorrent(ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentResume,
        data: {'hashes': hash}, sid: sid);
  }

  @override
  Future<void> deleteTorrent(ClientConfig config, String hash,
      {bool deleteFiles = false}) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, AppConstants.qbTorrentDelete,
        data: {
          'hashes': hash,
          'deleteFiles': deleteFiles ? 'true' : 'false'
        },
        sid: sid);
  }

  @override
  Future<List<TrackerInfo>> getTrackers(
      ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final resp = await _get(
        config, AppConstants.qbTorrentTrackers,
        params: {'hash': hash},
        sid: sid);
    final List<dynamic> rawList = resp.data;
    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return TrackerInfo(
        url: m['url'] as String? ?? '',
        status: m['msg'] as String? ?? '',
        peers: (m['num_peers'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TorrentFile>> getTorrentFiles(
      ClientConfig config, String hash) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    final resp = await _get(config, '/api/v2/torrents/files',
        params: {'hash': hash}, sid: sid);
    final List<dynamic> rawList = resp.data;
    return rawList.map((json) {
      final m = json as Map<String, dynamic>;
      return TorrentFile(
        name: m['name'] as String? ?? '',
        size: (m['size'] as num?)?.toInt() ?? 0,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
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
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/editTracker',
        data: {'hash': hash, 'origUrl': oldUrl, 'newUrl': newUrl},
        sid: sid);
  }

  @override
  Future<void> addTracker(
      ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/addTrackers',
        data: {'hash': hash, 'urls': trackerUrl}, sid: sid);
  }

  @override
  Future<void> removeTracker(
      ClientConfig config, String hash, String trackerUrl) async {
    final sid = await _login(config);
    if (sid == null) throw Exception('Login failed');
    await _post(config, '/api/v2/torrents/removeTrackers',
        data: {'hash': hash, 'urls': trackerUrl}, sid: sid);
  }
}
