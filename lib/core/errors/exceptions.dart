class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Unauthorized']);
  final String message;
}

class NotFoundException implements Exception {
  const NotFoundException([this.message = 'Not found']);
  final String message;
}

class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Network unavailable']);
  final String message;
}

class TimeoutException implements Exception {
  const TimeoutException([this.message = 'Request timed out']);
  final String message;
}

class FileTooLargeException implements Exception {
  const FileTooLargeException([this.message = 'File too large']);
  final String message;
}

class RateLimitException implements Exception {
  const RateLimitException({
    this.message = 'Rate limited',
    this.retryAfterSeconds,
  });
  final String message;
  final int? retryAfterSeconds;
}

class StorageException implements Exception {
  const StorageException([this.message = 'Storage error']);
  final String message;
}

class InsufficientStorageException implements Exception {
  const InsufficientStorageException([
    this.message = 'Insufficient storage',
  ]);
  final String message;
}

class TransferCancelledException implements Exception {
  const TransferCancelledException([this.message = 'Cancelled']);
  final String message;
}

class FileNotFoundException implements Exception {
  const FileNotFoundException([this.message = 'File not found']);
  final String message;
}

class ChecksumException implements Exception {
  const ChecksumException([this.message = 'Checksum mismatch']);
  final String message;
}
