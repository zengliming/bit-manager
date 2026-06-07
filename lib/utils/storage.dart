import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一的本地存储封装
/// 明文配置使用 SharedPreferences，敏感信息（密码）使用 SecureStorage
class LocalStorage {
  static LocalStorage? _instance;
  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  bool _initialized = false;

  LocalStorage._();

  static Future<LocalStorage> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorage._();
      await _instance!._init();
    } else if (!_instance!._initialized) {
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // --- JSON 数组操作（用于客户端列表、RSS 源列表） ---

  Future<List<Map<String, dynamic>>> getJsonList(String key) async {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> saveJsonList(String key, List<Map<String, dynamic>> list) async {
    await _prefs.setString(key, jsonEncode(list));
  }

  // --- 密码存储 ---

  Future<void> savePassword(String clientId, String password) async {
    await _secure.write(key: 'pwd_$clientId', value: password);
  }

  Future<String?> getPassword(String clientId) async {
    return await _secure.read(key: 'pwd_$clientId');
  }

  Future<void> deletePassword(String clientId) async {
    await _secure.delete(key: 'pwd_$clientId');
  }

  // --- 简单键值 ---

  Future<String?> getString(String key) async => _prefs.getString(key);
  Future<void> setString(String key, String value) async => _prefs.setString(key, value);
  Future<int?> getInt(String key) async => _prefs.getInt(key);
  Future<void> setInt(String key, int value) async => _prefs.setInt(key, value);
  Future<bool?> getBool(String key) async => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) async => _prefs.setBool(key, value);
}
