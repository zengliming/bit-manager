import 'package:flutter/foundation.dart';
import '../models/client_config.dart';
import '../services/service_factory.dart';
import '../utils/http_client.dart';
import '../utils/storage.dart';

class ClientProvider extends ChangeNotifier {
  List<ClientConfig> _clients = [];
  final Map<String, bool> _onlineStatus = {};
  final Map<String, String> _errorMessages = {};
  bool _loading = false;

  List<ClientConfig> get clients => List.unmodifiable(_clients);
  List<ClientConfig> get activeClients =>
      _clients.where((c) => c.isActive).toList();
  Map<String, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);
  Map<String, String> get errorMessages => Map.unmodifiable(_errorMessages);
  bool get loading => _loading;

  /// 从本地存储加载客户端配置
  Future<void> loadClients() async {
    _loading = true;

    try {
      final storage = await LocalStorage.getInstance();
      final rawList = await storage.getJsonList('clients');
      _clients = rawList.map((json) => ClientConfig.fromJson(json)).toList();

      for (final client in _clients) {
        final pwd = await storage.getPassword(client.id);
        if (pwd != null) {
          client.password = pwd;
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveClients() async {
    final storage = await LocalStorage.getInstance();
    final jsonList = _clients.map((c) {
      if (c.password != null) {
        storage.savePassword(c.id, c.password!);
      }
      return c.toJson();
    }).toList();
    await storage.saveJsonList('clients', jsonList);
  }

  Future<void> addClient(ClientConfig config) async {
    _clients.add(config);
    await _saveClients();
    HttpClientUtil.instance.clearClientDioCache();
    notifyListeners();
  }

  Future<void> updateClient(String id, ClientConfig updated) async {
    final index = _clients.indexWhere((c) => c.id == id);
    if (index != -1) {
      _clients[index] = updated;
      await _saveClients();
      HttpClientUtil.instance.clearClientDioCache();
      notifyListeners();
    }
  }

  Future<void> deleteClient(String id) async {
    _clients.removeWhere((c) => c.id == id);
    _onlineStatus.remove(id);
    _errorMessages.remove(id);
    final storage = await LocalStorage.getInstance();
    await storage.deletePassword(id);
    await _saveClients();
    HttpClientUtil.instance.clearClientDioCache();
    notifyListeners();
  }

  Future<bool> testConnection(ClientConfig config) async {
    try {
      final service = ServiceFactory.getService(config.type);
      final ok = await service.testConnection(config);
      if (ok) {
        _onlineStatus[config.id] = true;
        _errorMessages.remove(config.id);
      } else {
        _onlineStatus[config.id] = false;
        _errorMessages[config.id] = 'Connection failed';
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _onlineStatus[config.id] = false;
      _errorMessages[config.id] = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshAllStatus() async {
    for (final client in _clients) {
      if (client.isActive) {
        await testConnection(client);
      }
    }
  }

  bool isOnline(String clientId) => _onlineStatus[clientId] ?? false;
  String? getError(String clientId) => _errorMessages[clientId];
}
