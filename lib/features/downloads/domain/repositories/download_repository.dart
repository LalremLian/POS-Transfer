import '../entities/remote_file.dart';

abstract class DownloadRepository {
  Future<List<RemoteFile>> fetchFiles();
  Future<void> deleteFile(String fileName);

  /// Stream a file from the server to destinationPartPath.
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
