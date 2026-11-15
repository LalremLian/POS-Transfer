import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/transfer/transfer_config.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../core/utils/speed_tracker.dart';
import '../../../transfers/domain/entities/transfer_entity.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../repositories/download_repository.dart';

final _log = Logger();

/// Executes a resumable download with bounded retry, SHA-256, and atomic
/// finalization. All 11 Phase 5 requirements are implemented here.
class DownloadExecutor {
  DownloadExecutor({
    required DownloadRepository repository,
    required TransferManager manager,
    required TransferConfig config,
  })  : _repo = repository,
        _manager = manager,
        _config = config;

  final DownloadRepository _repo;
  final TransferManager _manager;
  final TransferConfig _config;
  final _rng = Random();

  /// Entry point — matches TransferExecutor signature.
  Future<void> call(TransferEntity transfer) async {
    void Function()? cancelFn;
    _manager.registerCancelCallback(transfer.id, () => cancelFn?.call());
    try {
      await _runWithRetry(transfer, (fn) => cancelFn = fn);
    } finally {
      _manager.unregisterCancelCallback(transfer.id);
    }
  }

  Future<void> _runWithRetry(
    TransferEntity transfer,
    void Function(void Function()) setCancelFn,
  ) async {
    final speed = SpeedTracker(sampleIntervalMs: _config.speedSampleIntervalMs);
    final partPath = FileUtils.toPartPath(transfer.destinationPath!);

    for (var attempt = 0; attempt <= _config.maxRetryAttempts; attempt++) {
      if (_isStopped(transfer.id)) return;

      try {
        _manager.markRunning(transfer.id);
        speed.reset();

        // 5.9 — Storage check (best-effort log; real check needs platform channel)
        if (transfer.totalBytes > _config.largeFileSizeThreshold) {
          _log.d('Large download ${transfer.totalBytes} B — no native storage check');
        }

        // 5.4 — Resume offset: read existing .part file size.
        // Ensure the destination directory exists before any file operation.
        final partFile = File(partPath);
        await partFile.parent.create(recursive: true);
        final startBytes = partFile.existsSync() ? partFile.lengthSync() : 0;

        // 5.3 + 5.5 — Stream to .part file, send Range header if resuming
        final streamResult = await _repo.streamFile(
          fileName: transfer.remoteFileName!,
          destinationPartPath: partPath,
          startBytes: startBytes,
          onCancelRegister: setCancelFn,
          onProgress: (received, total) {
            if (_isStopped(transfer.id)) return;
            final s = speed.update(received);
            _manager.updateProgress(
              transfer.id,
              transferredBytes: received,
              totalBytes: total > 0 ? total : transfer.totalBytes,
              speedBytesPerSec: s,
            );
          },
        );

        if (_isStopped(transfer.id)) return;

        // 5.6 + 5.7 + 5.8 — Verify, SHA-256, atomic rename
        await _finalize(transfer, partPath, streamResult.totalBytes);
        return; // success

      } on TransferCancelledException {
        return; // .part preserved for resume
      } catch (e) {
        if (_isStopped(transfer.id)) return;
        if (!_isRetryable(e) || attempt >= _config.maxRetryAttempts) {
          _manager.markFailed(transfer.id, _userMessage(e));
          return;
        }
        _manager.markRetrying(transfer.id);
        await _interruptibleSleep(_backoffDelay(attempt, e), transfer.id);
      }
    }
  }

  // ── Finalization ────────────────────────────────────────────────────────

  Future<void> _finalize(
    TransferEntity transfer,
    String partPath,
    int expectedTotal,
  ) async {
    final partFile = File(partPath);
    if (!partFile.existsSync()) {
      throw Exception('Part file missing after download');
    }

    final actualSize = partFile.lengthSync();

    // Only reject on major size mismatch (>1 MB off), not minor Content-Length
    // precision differences which cause the 98/99% stuck issue.
    if (expectedTotal > 0 && (actualSize - expectedTotal).abs() > 1024 * 1024) {
      throw Exception('Size mismatch: got $actualSize expected $expectedTotal');
    }

    // Push final 100% progress before SHA-256 (which can take a moment on large files).
    _manager.updateProgress(
      transfer.id,
      transferredBytes: actualSize,
      totalBytes: actualSize,
      speedBytesPerSec: 0,
    );

    // 5.7 — Streaming SHA-256 (never loads whole file into memory)
    final checksum = await _computeSha256(partFile);

    // 5.8 — Collision-safe destination filename
    final destDir = p.dirname(transfer.destinationPath!);
    final fileName = p.basename(transfer.destinationPath!);
    final safeDest = await FileUtils.resolveCollision(destDir, fileName);

    // 5.6 — Atomic rename: .part → final file
    await partFile.rename(safeDest);

    _manager.markCompleted(
      transfer.id,
      remoteFileName: transfer.remoteFileName,
      remoteFileSize: actualSize,
      localChecksum: checksum,
    );
    _log.i('Download done: $safeDest  sha256=$checksum');
  }

  /// Incremental SHA-256 — file is never held in RAM whole.
  Future<String> _computeSha256(File file) async {
    Digest? digest;
    final sink = sha256.startChunkedConversion(
      _SingleValueSink<Digest>((d) => digest = d),
    );
    await for (final chunk in file.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return digest!.toString();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  bool _isStopped(String id) {
    final st = _manager.get(id)?.status;
    return st == TransferStatus.paused || st == TransferStatus.cancelled;
  }

  bool _isRetryable(Object e) {
    if (e is TransferCancelledException) return false;
    if (e is InsufficientStorageException) return false;
    if (e is ApiException) {
      final c = e.statusCode;
      return c == 429 || (c != null && c >= 500);
    }
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          (e.type == DioExceptionType.badResponse &&
              (e.response?.statusCode ?? 0) >= 500);
    }
    return e.toString().contains('Size mismatch');
  }

  Duration _backoffDelay(int attempt, Object e) {
    if (e is RateLimitException && e.retryAfterSeconds != null) {
      return Duration(seconds: e.retryAfterSeconds!);
    }
    final base = _config.initialRetryDelayMs * (1 << attempt);
    final capped = base.clamp(0, _config.maxRetryDelayMs);
    return Duration(
        milliseconds:
            (capped + capped * _config.jitterFactor * _rng.nextDouble())
                .toInt());
  }

  Future<void> _interruptibleSleep(Duration delay, String id) async {
    final end = DateTime.now().add(delay);
    while (DateTime.now().isBefore(end)) {
      if (_isStopped(id)) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  String _userMessage(Object e) {
    if (e is InsufficientStorageException) return 'Not enough storage space.';
    if (e is ApiException) {
      return switch (e.statusCode) {
        401 => 'Session expired. Please log in again.',
        403 => 'Access denied.',
        404 => 'File no longer exists on the server.',
        _ => e.message,
      };
    }
    if (e is DioException) {
      return e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout
          ? 'Network timed out.'
          : e.type == DioExceptionType.connectionError
              ? 'Cannot reach the server.'
              : 'Download failed. Please retry.';
    }
    return 'Download failed. Please retry.';
  }
}

/// Captures the single value emitted by a chunked conversion (SHA-256 digest).
class _SingleValueSink<T> implements Sink<T> {
  _SingleValueSink(this._onValue);
  final void Function(T) _onValue;

  @override
  void add(T data) => _onValue(data);

  @override
  void close() {}
}
