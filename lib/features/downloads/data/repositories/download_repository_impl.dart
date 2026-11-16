import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/remote_file.dart';
import '../../domain/repositories/download_repository.dart';

class DownloadRepositoryImpl implements DownloadRepository {
  DownloadRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<RemoteFile>> fetchFiles() async {
    final resp = await _dio.get<Map<String, dynamic>>(ApiConstants.getFiles);
    final data = resp.data ?? {};
    if (data['success'] == false) {
      throw ApiException(data['error']?.toString() ?? 'Failed to fetch files');
    }
    final raw = data['files'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RemoteFile.fromJson)
        .toList();
  }

  @override
  Future<void> deleteFile(String fileName) async {
    final resp = await _dio.delete<Map<String, dynamic>>(
      '/delete',
      queryParameters: {ApiConstants.fileParam: fileName},
    );
    final data = resp.data ?? {};
    if (resp.statusCode != 200 || data['success'] == false) {
      throw ApiException(
        data['error']?.toString() ?? 'Delete failed',
        statusCode: resp.statusCode,
      );
    }
  }

  // Stream download
  @override
  Future<DownloadStreamResult> streamFile({
    required String fileName,
    required String destinationPartPath,
    required int startBytes,
    required void Function(int received, int total) onProgress,
    required void Function(void Function() abort) onCancelRegister,
  }) async {
    final cancelToken = CancelToken();
    onCancelRegister(() {
      if (!cancelToken.isCancelled) cancelToken.cancel();
    });

    final headers = <String, dynamic>{};
    if (startBytes > 0) {
      headers['Range'] = 'bytes=$startBytes-';
    }

    Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        ApiConstants.downloadFile,
        queryParameters: {ApiConstants.fileParam: fileName},
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          validateStatus: (s) => s != null && (s == 200 || s == 206 || s == 416),
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const TransferCancelledException();
      }
      rethrow;
    }

    final statusCode = response.statusCode ?? 0;

    // 416 = Range Not Satisfiable: the .part file is at or beyond EOF.
    // Treat this as already complete — the finalization step verifies.
    if (statusCode == 416) {
      return DownloadStreamResult(
        totalBytes: startBytes,
        resumed: false,
        etag: response.headers.value('etag'),
      );
    }

    final resumed = statusCode == 206;
    final etag = response.headers.value('etag');

    // Parse Content-Length / Content-Range to get total file size.
    int totalBytes = 0;
    if (resumed) {
      // Content-Range: bytes start-end/total
      final cr = response.headers.value('content-range');
      if (cr != null) {
        final slash = cr.lastIndexOf('/');
        if (slash >= 0) {
          totalBytes = int.tryParse(cr.substring(slash + 1)) ?? 0;
        }
      }
    }
    if (totalBytes == 0) {
      totalBytes = int.tryParse(
            response.headers.value('content-length') ?? '',
          ) ??
          0;
      if (resumed) totalBytes += startBytes;
    }

    // If server returned 200 when we sent a Range header, it ignored the
    // Range — we must overwrite the .part file, not append to it.
    final openMode = (resumed && startBytes > 0)
        ? FileMode.append
        : FileMode.write;

    final file = File(destinationPartPath);
    final sink = file.openWrite(mode: openMode);
    int received = startBytes;

    try {
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          throw const TransferCancelledException();
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, totalBytes > 0 ? totalBytes : received);
      }
      await sink.flush();
      await sink.close();
    } on TransferCancelledException {
      await sink.flush();
      await sink.close();
      rethrow; // preserve .part for resume
    } catch (e) {
      await sink.close();
      rethrow;
    }

    // Stream ended cleanly — treat received as the authoritative total so
    // progress always reaches 100% regardless of Content-Length precision.
    final finalTotal = totalBytes > 0 ? totalBytes : received;
    onProgress(received, received); // force 100%

    return DownloadStreamResult(
      totalBytes: finalTotal > 0 ? finalTotal : received,
      resumed: resumed,
      etag: etag,
    );
  }
}
