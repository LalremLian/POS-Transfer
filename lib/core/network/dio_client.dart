import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../transfer/transfer_config.dart';
import 'auth_interceptor.dart';

Dio createDioClient({
  required AuthInterceptor authInterceptor,
  TransferConfig config = transferConfig,
  bool enableLogging = true,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: Duration(milliseconds: config.connectionTimeoutMs),
      sendTimeout: Duration(milliseconds: config.sendTimeoutMs),
      receiveTimeout: Duration(milliseconds: config.receiveTimeoutMs),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(authInterceptor);

  if (enableLogging || kDebugMode) {
    dio.interceptors.add(_ApiLogInterceptor());
  }

  return dio;
}

/// Comprehensive API logging interceptor for Android Logcat and DevTools.
class _ApiLogInterceptor extends Interceptor {
  void _log(String message) {
    // 1. debugPrint guarantees output to standard Logcat (under tag: flutter)
    debugPrint('[API] $message');
    // 2. dev.log routes to Dart VM service & Android Logcat (under tag/name: API)
    dev.log(message, name: 'API');
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final safeHeaders = Map<String, dynamic>.from(options.headers);
    if (safeHeaders.containsKey('Authorization')) {
      safeHeaders['Authorization'] = 'Bearer ***';
    }

    final fullUrl = options.uri.toString();
    final sb = StringBuffer();
    sb.writeln('─── REAL API REQUEST ───');
    sb.writeln('--> ${options.method} $fullUrl');
    if (safeHeaders.isNotEmpty) {
      sb.writeln('Headers: $safeHeaders');
    }
    if (options.queryParameters.isNotEmpty) {
      sb.writeln('QueryParams: ${options.queryParameters}');
    }
    if (options.data != null) {
      if (options.data is FormData) {
        final formData = options.data as FormData;
        final fields = formData.fields.map((e) => '${e.key}: ${e.value}').join(', ');
        final files = formData.files.map((e) => '${e.key}: ${e.value.filename}').join(', ');
        sb.writeln('Body (FormData): fields=[$fields], files=[$files]');
      } else {
        sb.writeln('Body: ${options.data}');
      }
    }
    sb.write('---------------------------');
    _log(sb.toString());

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final fullUrl = response.requestOptions.uri.toString();
    final statusCode = response.statusCode ?? 0;
    final statusMsg = response.statusMessage ?? '';

    final sb = StringBuffer();
    sb.writeln('─── REAL API RESPONSE ───');
    sb.writeln('<-- $statusCode $statusMsg $fullUrl');
    if (response.data != null) {
      final dataStr = response.data.toString();
      if (dataStr.length > 2000) {
        sb.writeln('Response Data: ${dataStr.substring(0, 2000)}... (truncated ${dataStr.length} chars)');
      } else {
        sb.writeln('Response Data: $dataStr');
      }
    }
    sb.write('----------------------------');
    _log(sb.toString());

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final fullUrl = err.requestOptions.uri.toString();
    final statusCode = err.response?.statusCode ?? 'NO_STATUS';

    final sb = StringBuffer();
    sb.writeln('─── REAL API ERROR ───');
    sb.writeln('<-- ERROR $statusCode $fullUrl');
    sb.writeln('Type: ${err.type}');
    sb.writeln('Message: ${err.message}');
    if (err.response?.data != null) {
      sb.writeln('Error Response Data: ${err.response?.data}');
    }
    sb.write('-------------------------');
    _log(sb.toString());

    handler.next(err);
  }
}

