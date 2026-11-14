import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/upload_result.dart';
import '../../domain/repositories/upload_repository.dart';

class UploadRepositoryImpl implements UploadRepository {
  UploadRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UploadResult> upload({
    required String filePath,
    required String fileName,
    required void Function(int sentBytes, int totalBytes) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Validate the source file exists before touching the network.
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileNotFoundException('Selected file no longer exists');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.uploadFile,
        data: formData,
        onSendProgress: onProgress,
        cancelToken: cancelToken,
        // Allow 4xx bodies through so we can read the structured error.
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } on DioException catch (e) {
      // Cancel is expected during pause/cancel — rethrow as a typed signal.
      if (e.type == DioExceptionType.cancel) {
        throw const TransferCancelledException();
      }
      rethrow;
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data ?? const {};

    // Rate limited → respect Retry-After when the server provides it.
    if (statusCode == 429) {
      final retryAfterRaw = response.headers.value('retry-after');
      final retryAfterSeconds = int.tryParse(retryAfterRaw ?? '');
      throw RateLimitException(retryAfterSeconds: retryAfterSeconds);
    }

    // Non-success responses carry {success:false, error:"..."}.
    if (statusCode >= 400 || data['success'] == false) {
      final message = (data['error'] as String?) ?? 'Upload failed';
      throw ApiException(message, statusCode: statusCode);
    }

    final fileObj = data['file'];
    if (fileObj is! Map<String, dynamic>) {
      throw const ApiException('Malformed upload response');
    }

    return UploadResult(
      id: (fileObj['id'] as num?)?.toInt() ?? 0,
      name: fileObj['name'] as String? ?? fileName,
      originalName: fileObj['original_name'] as String? ?? fileName,
      size: (fileObj['size'] as num?)?.toInt() ?? 0,
      type: fileObj['type'] as String? ?? '',
      uploadedAt:
          DateTime.tryParse(fileObj['uploaded_at'] as String? ?? '') ??
          DateTime.now(),
      url: fileObj['url'] as String? ?? '',
    );
  }
}
