import 'dart:math';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/transfer/transfer_config.dart';
import '../../../../core/utils/speed_tracker.dart';
import '../../../transfers/domain/entities/transfer_entity.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../repositories/upload_repository.dart';

final _log = Logger();

class UploadExecutor {
  UploadExecutor({
    required UploadRepository repository,
    required TransferManager manager,
    required TransferConfig config,
  })  : _repo = repository,
        _manager = manager,
        _config = config;

  final UploadRepository _repo;
  final TransferManager _manager;
  final TransferConfig _config;
  final _random = Random();

  /// Entry point — matches the `TransferExecutor` function type.
  Future<void> call(TransferEntity transfer) async {
    final cancelToken = CancelToken();
    _manager.registerCancelCallback(
      transfer.id,
      () {
        if (!cancelToken.isCancelled) cancelToken.cancel();
      },
    );
    try {
      await _runWithRetry(transfer, cancelToken);
    } finally {
      _manager.unregisterCancelCallback(transfer.id);
    }
  }

  Future<void> _runWithRetry(TransferEntity transfer, CancelToken cancelToken) async {
    final speed = SpeedTracker(sampleIntervalMs: _config.speedSampleIntervalMs);

    for (var attempt = 0; attempt <= _config.maxRetryAttempts; attempt++) {
      // Honour a user pause/cancel that arrived before this attempt.
      if (_isUserStopped(transfer.id)) return;

      try {
        _manager.markRunning(transfer.id);
        speed.reset();
        final result = await _repo.upload(
          filePath: transfer.localFilePath!,
          fileName: transfer.fileName,
          onProgress: (sent, total) {
            final s = speed.update(sent);
            if (total > 0) {
              _manager.updateProgress(
                transfer.id,
                transferredBytes: sent,
                totalBytes: total,
                speedBytesPerSec: s,
              );
            } else {
              _manager.updateProgress(
                transfer.id,
                transferredBytes: sent,
                speedBytesPerSec: s,
              );
            }
          },
          cancelToken: cancelToken,
        );
        _manager.markCompleted(
          transfer.id,
          remoteFileName: result.name,
          remoteFileSize: result.size,
        );
        return;
      } on TransferCancelledException {
        // Pause/cancel mid-request — the manager already set the status.
        return;
      } catch (e) {
        if (_isUserStopped(transfer.id)) return;

        final retryable = _isRetryable(e);
        final exhausted = attempt >= _config.maxRetryAttempts;

        if (!retryable || exhausted) {
          _manager.markFailed(transfer.id, _userMessage(e));
          _log.w('Upload ${transfer.id} failed after $attempt attempts', error: e);
          return;
        }

        // Retry: surface it, back off, then loop.
        _manager.markRetrying(transfer.id);
        final delay = _backoffDelay(attempt, e);
        await _interruptibleSleep(delay, transfer.id);
        _log.i('Upload ${transfer.id} retry ${attempt + 1}/${_config.maxRetryAttempts} '
            'in ${delay.inMilliseconds}ms');
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool _isUserStopped(String id) {
    final st = _manager.get(id)?.status;
    return st == TransferStatus.paused || st == TransferStatus.cancelled;
  }

  /// Transient errors retry; permanent ones fail immediately
  bool _isRetryable(Object error) {
    if (error is TransferCancelledException) return false;
    if (error is FileNotFoundException) return false;
    if (error is RateLimitException) return true;
    if (error is ApiException) {
      final code = error.statusCode;
      return code == 429 || (code != null && code >= 500);
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return code == 429 || (code != null && code >= 500);
        case DioExceptionType.cancel:
          return false;
        case DioExceptionType.badCertificate:
          return false;
        case DioExceptionType.unknown:
        case DioExceptionType.transformTimeout:
          // Treat as a transient network issue unless it's clearly not.
          return error.error is! FileNotFoundException;
      }
    }
    return false;
  }

  /// Exponential backoff with jitter, capped at `maxRetryDelayMs`.
  /// Honours Retry-After for HTTP 429.
  Duration _backoffDelay(int attempt, Object error) {
    if (error is RateLimitException && error.retryAfterSeconds != null) {
      return Duration(seconds: error.retryAfterSeconds!);
    }
    final base = _config.initialRetryDelayMs * (1 << attempt);
    final capped = base.clamp(0, _config.maxRetryDelayMs);
    final jitter = capped * _config.jitterFactor * _random.nextDouble();
    return Duration(milliseconds: (capped + jitter).toInt());
  }

  /// Sleep that bails out if the user pauses/cancels during the backoff window.
  Future<void> _interruptibleSleep(Duration delay, String id) async {
    final end = DateTime.now().add(delay);
    while (DateTime.now().isBefore(end)) {
      if (_isUserStopped(id)) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Friendly, token-free message for the UI.
  String _userMessage(Object error) {
    if (error is RateLimitException) {
      final s = error.retryAfterSeconds;
      return s != null ? 'Too many requests. Retry in ${s}s.' : 'Too many requests. Please wait.';
    }
    if (error is FileNotFoundException) return 'Selected file no longer exists';
    if (error is ApiException) {
      return switch (error.statusCode) {
        401 => 'Session expired. Please log in again.',
        403 => 'You are not allowed to upload this file.',
        404 => 'Upload endpoint not found.',
        413 => 'File is too large for the server.',
        415 => 'This file type is not allowed by the server.',
        _ => error.message,
      };
    }
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Network timed out. Check your connection.';
        case DioExceptionType.connectionError:
          return 'Cannot reach the server. Check your connection.';
        default:
          return 'Upload failed. Please try again.';
      }
    }
    return 'Upload failed. Please try again.';
  }
}
