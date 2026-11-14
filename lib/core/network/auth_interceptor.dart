import 'package:dio/dio.dart';

import '../services/storage_service.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final StorageService _storage;

  static const _noAuthPaths = {'/token', '/register'};

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;

    if (_noAuthPaths.any((p) => path.startsWith(p))) {
      return handler.next(options);
    }

    final token = await _storage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }
}
