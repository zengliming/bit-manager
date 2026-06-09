import 'package:dio/dio.dart';
import '../models/client_config.dart';

class HttpClientUtil {
  static HttpClientUtil? _instance;
  late Dio _dio;

  /// 生成缓存键（baseUrl + timeout），确保不同超时配置的 Dio 实例不会互相复用
  String _clientDioCacheKey(ClientConfig config) =>
      '${config.baseUrl}|timeout=${config.timeoutSeconds}';

  /// 按连接配置（baseUrl + timeout）缓存的客户端 Dio 实例，复用连接池
  final Map<String, Dio> _clientDioCache = {};

  HttpClientUtil._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {'User-Agent': 'BitManager/1.0'},
    ));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[HTTP] $obj'),
    ));
  }

  static HttpClientUtil get instance {
    _instance ??= HttpClientUtil._();
    return _instance!;
  }

  Dio get dio => _dio;

  /// 获取或创建为特定客户端配置的 Dio 实例（按连接配置缓存复用）
  /// 同一个客户端地址+超时共享连接池，避免重复 TLS 握手
  Dio createClientDio(ClientConfig config) {
    return _clientDioCache.putIfAbsent(
      _clientDioCacheKey(config),
      () => Dio(BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: Duration(seconds: config.timeoutSeconds),
        receiveTimeout: Duration(seconds: config.timeoutSeconds + 5),
        sendTimeout: Duration(seconds: config.timeoutSeconds + 5),
        headers: {'User-Agent': 'BitManager/1.0'},
      )),
    );
  }

  /// 清除客户端 Dio 缓存（客户端配置变更时调用）
  void clearClientDioCache() {
    _clientDioCache.clear();
  }
}
