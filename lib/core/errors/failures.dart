import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];

  @override
  String toString() => '$runtimeType: $message';
}

// Network
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'Request timed out']);
}

class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = 'Connection failed']);
}

// Server
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired. Please log in again.']);
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure([super.message = 'Access denied']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found']);
}

class FileTooLargeFailure extends Failure {
  const FileTooLargeFailure([super.message = 'File is too large for the server']);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure({
    String message = 'Too many requests. Please wait.',
    this.retryAfterSeconds,
  }) : super(message);
  final int? retryAfterSeconds;

  @override
  List<Object?> get props => [message, retryAfterSeconds];
}

// Transfer
class TransferFailure extends Failure {
  const TransferFailure(super.message);
}

class TransferCancelledFailure extends Failure {
  const TransferCancelledFailure([super.message = 'Transfer cancelled']);
}

class DuplicateTransferFailure extends Failure {
  const DuplicateTransferFailure([super.message = 'Transfer already in progress']);
}

class InsufficientStorageFailure extends Failure {
  const InsufficientStorageFailure([
    super.message = 'Not enough storage space for this download',
  ]);
}

class ChecksumFailure extends Failure {
  const ChecksumFailure([super.message = 'File integrity check failed']);
}

class PartialDownloadCorruptedFailure extends Failure {
  const PartialDownloadCorruptedFailure([
    super.message = 'Partial download is corrupted and cannot be resumed',
  ]);
}

// File / Storage
class FileNotFoundFailure extends Failure {
  const FileNotFoundFailure([super.message = 'File not found']);
}

class FileAccessFailure extends Failure {
  const FileAccessFailure([super.message = 'Cannot access file']);
}

class InvalidFileFailure extends Failure {
  const InvalidFileFailure([super.message = 'Invalid or unreadable file']);
}

class UnsupportedFileTypeFailure extends Failure {
  const UnsupportedFileTypeFailure([super.message = 'This file type is not allowed by the server']);
}

// Auth
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Invalid username or password']);
}

// Unknown Error
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred']);
}
