import 'package:flutter/foundation.dart';

@immutable
class TransferConfig {
  const TransferConfig({
    this.maxConcurrentTransfers = 3,
    this.maxRetryAttempts = 3,
    this.initialRetryDelayMs = 1000,
    this.maxRetryDelayMs = 30000,
    this.jitterFactor = 0.3,
    this.connectionTimeoutMs = 30000,
    this.sendTimeoutMs = 60000,
    this.receiveTimeoutMs = 60000,
    this.uiProgressIntervalMs = 500,
    this.notificationIntervalMs = 2000,
    this.metadataPersistIntervalMs = 5000,
    this.downloadStreamChunkSize = 65536, // 64 KB
    this.largeFileSizeThreshold = 10 * 1024 * 1024, // 10 MB
    this.storageCheckPaddingBytes = 5 * 1024 * 1024, // 5 MB safety buffer
    this.speedSampleIntervalMs = 1000,
    // Reserved for future backend-supported chunked uploads:
    this.uploadChunkSize = 0, // 0 = not used (single multipart request)
  });

  // Concurrency
  /// Maximum number of transfers (upload + download combined) running at once.
  final int maxConcurrentTransfers;

  // Retry & backoff
  final int maxRetryAttempts;
  final int initialRetryDelayMs;
  final int maxRetryDelayMs;

  /// Fraction of calculated delay added as random jitter (0–1).
  final double jitterFactor;

  // Timeouts
  final int connectionTimeoutMs;
  final int sendTimeoutMs;
  final int receiveTimeoutMs;

  // UI / notification throttling
  /// Minimum ms between state emissions for a single transfer's progress.
  final int uiProgressIntervalMs;

  /// Minimum ms between notification updates during active transfers.
  final int notificationIntervalMs;

  /// Minimum ms between metadata persistence writes during transfers.
  final int metadataPersistIntervalMs;

  // File I/O
  /// Bytes read per streaming chunk when writing download data to disk.
  final int downloadStreamChunkSize;

  /// Files above this size trigger a pre-download storage availability check.
  final int largeFileSizeThreshold;

  /// Extra free-space buffer required beyond the file size.
  final int storageCheckPaddingBytes;

  // Speed calculation
  final int speedSampleIntervalMs;

  // Future: chunked uploads (backend not yet supported)
  /// Chunk size for future resumable uploads.  0 = feature not active.
  final int uploadChunkSize;

  /// Whether the backend has been verified to support chunked uploads.
  /// Must be `true` before the chunked upload path is ever activated.
  bool get chunkedUploadSupported => uploadChunkSize > 0;

  TransferConfig copyWith({
    int? maxConcurrentTransfers,
    int? maxRetryAttempts,
    int? initialRetryDelayMs,
    int? maxRetryDelayMs,
    double? jitterFactor,
    int? connectionTimeoutMs,
    int? sendTimeoutMs,
    int? receiveTimeoutMs,
    int? uiProgressIntervalMs,
    int? notificationIntervalMs,
    int? metadataPersistIntervalMs,
    int? downloadStreamChunkSize,
    int? largeFileSizeThreshold,
    int? storageCheckPaddingBytes,
    int? speedSampleIntervalMs,
    int? uploadChunkSize,
  }) {
    return TransferConfig(
      maxConcurrentTransfers:
          maxConcurrentTransfers ?? this.maxConcurrentTransfers,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      initialRetryDelayMs: initialRetryDelayMs ?? this.initialRetryDelayMs,
      maxRetryDelayMs: maxRetryDelayMs ?? this.maxRetryDelayMs,
      jitterFactor: jitterFactor ?? this.jitterFactor,
      connectionTimeoutMs: connectionTimeoutMs ?? this.connectionTimeoutMs,
      sendTimeoutMs: sendTimeoutMs ?? this.sendTimeoutMs,
      receiveTimeoutMs: receiveTimeoutMs ?? this.receiveTimeoutMs,
      uiProgressIntervalMs: uiProgressIntervalMs ?? this.uiProgressIntervalMs,
      notificationIntervalMs:
          notificationIntervalMs ?? this.notificationIntervalMs,
      metadataPersistIntervalMs:
          metadataPersistIntervalMs ?? this.metadataPersistIntervalMs,
      downloadStreamChunkSize:
          downloadStreamChunkSize ?? this.downloadStreamChunkSize,
      largeFileSizeThreshold:
          largeFileSizeThreshold ?? this.largeFileSizeThreshold,
      storageCheckPaddingBytes:
          storageCheckPaddingBytes ?? this.storageCheckPaddingBytes,
      speedSampleIntervalMs:
          speedSampleIntervalMs ?? this.speedSampleIntervalMs,
      uploadChunkSize: uploadChunkSize ?? this.uploadChunkSize,
    );
  }
}

/// The app-wide singleton configuration instance.
const transferConfig = TransferConfig();
