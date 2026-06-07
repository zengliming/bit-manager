import '../models/client_config.dart';
import 'torrent_client.dart';
import 'qbittorrent_service.dart';
import 'transmission_service.dart';

class ServiceFactory {
  static final Map<ClientType, ITorrentClientService> _services = {};

  static ITorrentClientService getService(ClientType type) {
    if (!_services.containsKey(type)) {
      _services[type] = _createService(type);
    }
    return _services[type]!;
  }

  static ITorrentClientService _createService(ClientType type) {
    switch (type) {
      case ClientType.qBittorrent:
        return QBittorrentService();
      case ClientType.transmission:
        return TransmissionService();
    }
  }

  /// 清空缓存（测试用）
  static void reset() => _services.clear();
}
