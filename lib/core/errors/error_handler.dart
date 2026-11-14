import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'exceptions.dart';
import 'failures.dart';

final _log = Logger();

Failure mapExceptionToFailure(Object error, [StackTrace? stack]) {
  if (error is TransferCancelledException) {
    return const TransferCancelledFailure();
  }

  if (error is InsufficientStorageException) {
    return const InsufficientStorageFailure();
  }

  if (error is ChecksumException) {
    return const ChecksumFailure();
  }

  if (error is RateLimitException) {
    return RateLimitFailure(retryAfterSeconds: error.retryAfterSeconds);
  }

  if (error is FileTooLargeException) {
    return const FileTooLargeFailure();
  }

  if (error is UnauthorizedException) {
    return const UnauthorizedFailure();
  }

  if (error is NotFoundException) {
    return const NotFoundFailure();
  }

  if (error is ApiException) {
    return _fromStatusCode(error.statusCode, error.message);
  }

  if (error is ServerException) {
    return _fromStatusCode(error.statusCode, error.message);
  }

  if (error is NetworkException) {
    return NetworkFailure(error.message);
  }

  if (error is DioException) {
    return _fromDioException(error);
  }

  if (error is io.SocketException) {
    return const ConnectionFailure();
  }

  if (error is io.HandshakeException) {
    return const ConnectionFailure('TLS handshake failed');
  }

  _log.e('Unhandled exception → UnknownFailure', error: error, stackTrace: stack);
  return const UnknownFailure();
}

Failure _fromDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const TimeoutFailure();

    case DioExceptionType.connectionError:
      return const ConnectionFailure();

    case DioExceptionType.cancel:
      return const TransferCancelledFailure();

    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      final serverMsg = _extractErrorMessage(e.response);
      return _fromStatusCode(statusCode, serverMsg);

    case DioExceptionType.unknown:
    case DioExceptionType.badCertificate:
    case DioExceptionType.transformTimeout:
      if (e.error is io.SocketException) return const ConnectionFailure();
      return UnknownFailure(e.message ?? 'Unknown network error');
  }
}

Failure _fromStatusCode(int? code, String? message) {
  final msg = message ?? 'Server error';
  return switch (code) {
    400 => ServerFailure(msg, statusCode: 400),
    401 => const UnauthorizedFailure(),
    403 => const ForbiddenFailure(),
    404 => const NotFoundFailure(),
    413 => const FileTooLargeFailure(),
    429 => const RateLimitFailure(),
    500 || 502 || 503 || 504 => ServerFailure(msg, statusCode: code),
    _ => ServerFailure(msg, statusCode: code),
  };
}

String? _extractErrorMessage(Response<dynamic>? response) {
  try {
    final data = response?.data;
    if (data is Map<String, dynamic>) {
      return data['error']?.toString() ?? data['message']?.toString();
    }
  } catch (_) {}
  return null;
}
