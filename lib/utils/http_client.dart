import 'package:dio/dio.dart';
import '../models/client_config.dart';

class HttpClientUtil {
  static HttpClientUtil? _instance;
  late Dio _dio;

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

  /// 创建一个为特定客户端配置的 Dio 实例（含超时设置）
  Dio createClientDio(ClientConfig config) {
    return Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: Duration(seconds: config.timeoutSeconds),
      receiveTimeout: Duration(seconds: config.timeoutSeconds + 5),
      sendTimeout: Duration(seconds: config.timeoutSeconds + 5),
      headers: {'User-Agent': 'BitManager/1.0'},
    ));
  }
}
