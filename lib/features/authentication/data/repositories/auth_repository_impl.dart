import '../../../../core/errors/error_handler.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/auth_token.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.storageService,
  });

  final AuthRemoteDataSource remoteDataSource;
  final StorageService storageService;

  @override
  Future<AuthToken> login(String username, String password) async {
    try {
      final model = await remoteDataSource.login(username, password);
      final token = model.toDomain();
      await _persistToken(token);
      return token;
    } on UnauthorizedException {
      throw const AuthFailure('Invalid username or password');
    } on Failure {
      rethrow;
    } catch (e, s) {
      throw mapExceptionToFailure(e, s);
    }
  }

  @override
  Future<AuthToken> register(String username, String password) async {
    try {
      final model = await remoteDataSource.register(username, password);
      final token = model.toDomain();
      await _persistToken(token);
      return token;
    } on Failure {
      rethrow;
    } catch (e, s) {
      throw mapExceptionToFailure(e, s);
    }
  }

  @override
  Future<void> logout() async {
    await storageService.clearAll();
  }

  @override
  Future<AuthToken?> restoreSession() async {
    final isValid = await storageService.isTokenValid();
    if (!isValid) return null;

    final rawToken = await storageService.getToken();
    final username = await storageService.getUsername();
    final expiry = await storageService.getTokenExpiry();

    if (rawToken == null || username == null || expiry == null) return null;

    return AuthToken(
      token: rawToken,
      tokenType: 'Bearer',
      username: username,
      userId: 0, // User ID not critical for session restore
      expiresAt: expiry,
    );
  }

  Future<void> _persistToken(AuthToken token) async {
    await Future.wait([
      storageService.saveToken(token.token),
      storageService.saveUsername(token.username),
      storageService.saveTokenExpiry(token.expiresAt),
    ]);
  }
}
