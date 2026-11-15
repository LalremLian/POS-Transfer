import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/auth_interceptor.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_info.dart';
import '../../core/services/local_database_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/transfer/transfer_config.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override at startup'),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  ),
);

final connectivityProvider = Provider<Connectivity>(
  (_) => Connectivity(),
);

// Services

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(ref.watch(secureStorageProvider)),
);

final localDatabaseServiceProvider = Provider<LocalDatabaseService>(
  (ref) => LocalDatabaseService(ref.watch(sharedPreferencesProvider)),
);

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfoImpl(ref.watch(connectivityProvider)),
);

// Networking

final authInterceptorProvider = Provider<AuthInterceptor>(
  (ref) => AuthInterceptor(ref.watch(storageServiceProvider)),
);

final dioProvider = Provider<Dio>(
  (ref) => createDioClient(
    authInterceptor: ref.watch(authInterceptorProvider),
    config: ref.watch(transferConfigProvider),
  ),
);

// Config

final transferConfigProvider = Provider<TransferConfig>(
  (_) => transferConfig,
);
