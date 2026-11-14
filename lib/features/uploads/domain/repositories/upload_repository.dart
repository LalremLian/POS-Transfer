import 'package:dio/dio.dart';

import '../entities/upload_result.dart';

abstract class UploadRepository {
  Future<UploadResult> upload({
    required String filePath,
    required String fileName,
    required void Function(int sentBytes, int totalBytes) onProgress,
    CancelToken? cancelToken,
  });
}
