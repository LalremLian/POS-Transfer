import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_token.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: AuthRemoteDataSourceImpl(ref.watch(dioProvider)),
    storageService: ref.watch(storageServiceProvider),
  );
});

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(authRepositoryProvider).restoreSession();
    return AuthState(token: token);
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final token = await ref.read(authRepositoryProvider).login(username, password);
      state = AsyncValue.data(AuthState(token: token));
    } on AuthFailure catch (e) {
      state = AsyncValue.data(AuthState(error: e.message));
    } on Failure catch (e) {
      state = AsyncValue.data(AuthState(error: e.message));
    } catch (_) {
      state = AsyncValue.data(const AuthState(error: 'An unexpected error occurred'));
    }
  }

  Future<void> register(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final token = await ref.read(authRepositoryProvider).register(username, password);
      state = AsyncValue.data(AuthState(token: token));
    } on Failure catch (e) {
      state = AsyncValue.data(AuthState(error: e.message));
    } catch (_) {
      state = AsyncValue.data(const AuthState(error: 'Registration failed'));
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(AuthState());
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
