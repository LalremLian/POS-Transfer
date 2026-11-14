import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/token_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<TokenResponseModel> login(String username, String password);
  Future<TokenResponseModel> register(String username, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<TokenResponseModel> login(
    String username,
    String password,
  ) async {
    return _postAuth(ApiConstants.token, username, password);
  }

  @override
  Future<TokenResponseModel> register(
    String username,
    String password,
  ) async {
    return _postAuth(ApiConstants.register, username, password);
  }

  Future<TokenResponseModel> _postAuth(
    String endpoint,
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        endpoint,
        data: FormData.fromMap({
          'username': username,
          'password': password,
        }),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('Empty response from server');
      }

      final success = data['success'] as bool? ?? false;
      if (!success) {
        final error = data['error']?.toString() ?? 'Authentication failed';
        final statusCode = response.statusCode ?? 401;
        if (statusCode == 401) {
          throw const UnauthorizedException('Invalid username or password');
        }
        throw ApiException(error, statusCode: statusCode);
      }

      return TokenResponseModel.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const UnauthorizedException('Invalid username or password');
      }
      throw mapExceptionToFailure(e);
    }
  }
}
