import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus {
  queued,
  preparing,
  running,
  paused,
  completed,
  failed,
  cancelled,
}

class TransferEntity extends Equatable {
  const TransferEntity({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.type,
    required this.status,
    this.transferredBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.remoteFileName,
    this.localFilePath,
    this.destinationPath,
    this.retryCount = 0,
    this.expectedChecksum,
    this.localChecksum,
    this.metadata = const {},
  });

  final String id;
  final String fileName;
  final int fileSize;
  final TransferType type;
  final TransferStatus status;
  final int transferredBytes;
  final int totalBytes;
  final double speedBytesPerSec;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final String? remoteFileName;
  final String? localFilePath;
  final String? destinationPath;
  final int retryCount;
  final String? expectedChecksum;
  final String? localChecksum;
  final Map<String, dynamic> metadata;

  /// Progress as 0.0–1.0, clamped.
  double get progress =>
      totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// States that count as "still in flight" for duplicate-prevention.
  bool get isActive =>
      status == TransferStatus.queued ||
      status == TransferStatus.preparing ||
      status == TransferStatus.running ||
      status == TransferStatus.paused;

  bool get isTerminal =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.cancelled;

  /// Stable identity used to prevent duplicate scheduling of active transfers.
  String get dedupKey {
    return switch (type) {
      TransferType.upload => 'upload:${localFilePath ?? fileName}',
      TransferType.download =>
        'download:${remoteFileName ?? fileName}:${destinationPath ?? ''}',
    };
  }

  TransferEntity copyWith({
    String? id,
    String? fileName,
    int? fileSize,
    TransferType? type,
    TransferStatus? status,
    int? transferredBytes,
    int? totalBytes,
    double? speedBytesPerSec,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    String? remoteFileName,
    String? localFilePath,
    String? destinationPath,
    int? retryCount,
    String? expectedChecksum,
    String? localChecksum,
    Map<String, dynamic>? metadata,
  }) {
    return TransferEntity(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      type: type ?? this.type,
      status: status ?? this.status,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      remoteFileName: remoteFileName ?? this.remoteFileName,
      localFilePath: localFilePath ?? this.localFilePath,
      destinationPath: destinationPath ?? this.destinationPath,
      retryCount: retryCount ?? this.retryCount,
      expectedChecksum: expectedChecksum ?? this.expectedChecksum,
      localChecksum: localChecksum ?? this.localChecksum,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id, fileName, fileSize, type, status, transferredBytes, totalBytes,
        speedBytesPerSec, startedAt, completedAt, errorMessage, remoteFileName,
        localFilePath, destinationPath, retryCount, expectedChecksum,
        localChecksum,
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'type': type.name,
        'status': status.name,
        'transferredBytes': transferredBytes,
        'totalBytes': totalBytes,
        'speedBytesPerSec': speedBytesPerSec,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'errorMessage': errorMessage,
        'remoteFileName': remoteFileName,
        'localFilePath': localFilePath,
        'destinationPath': destinationPath,
        'retryCount': retryCount,
        'expectedChecksum': expectedChecksum,
        'localChecksum': localChecksum,
        'metadata': metadata,
      };

  factory TransferEntity.fromJson(Map<String, dynamic> json) {
    return TransferEntity(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      type: TransferType.values.byName(
        (json['type'] as String?) ?? 'upload',
      ),
      status: TransferStatus.values.byName(
        (json['status'] as String?) ?? 'queued',
      ),
      transferredBytes: (json['transferredBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSec: (json['speedBytesPerSec'] as num?)?.toDouble() ?? 0,
      startedAt: _parseDate(json['startedAt']),
      completedAt: _parseDate(json['completedAt']),
      errorMessage: json['errorMessage'] as String?,
      remoteFileName: json['remoteFileName'] as String?,
      localFilePath: json['localFilePath'] as String?,
      destinationPath: json['destinationPath'] as String?,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      expectedChecksum: json['expectedChecksum'] as String?,
      localChecksum: json['localChecksum'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  static DateTime? _parseDate(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
}
