import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class DioClient {
  DioClient._();

  static Dio create(SecureStorage storage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
        followRedirects: true,
        maxRedirects: 3,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await storage.getToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } catch (_) {}
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401) {
            try {
              await storage.deleteToken();
            } catch (_) {}
          }
          handler.next(err);
        },
      ),
    );

    return dio;
  }
}
