import '../entities/remote_file.dart';

abstract class DownloadRepository {
  /// Fetch the list of remote files owned by the authenticated user.
  Future<List<RemoteFile>> fetchFiles();

  /// Delete a remote file.
  Future<void> deleteFile(String fileName);

  /// Stream a file from the server to [destinationPartPath].
  /// Resumes from [startBytes] if > 0 (HTTP Range request).
  /// [onProgress] receives (receivedBytes, totalBytes).
  /// [cancelToken] is a [void Function()] that aborts the stream.
  Future<DownloadStreamResult> streamFile({
    required String fileName,
    required String destinationPartPath,
    required int startBytes,
    required void Function(int received, int total) onProgress,
    required void Function(void Function() abort) onCancelRegister,
  });
}

/// Result of a successful stream operation.
class DownloadStreamResult {
  const DownloadStreamResult({
    required this.totalBytes,
    required this.resumed,
    this.etag,
  });

  final int totalBytes;
  final bool resumed; // true if server returned 206
  final String? etag;
}
