import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

final _log = Logger();

class StorageService {
  StorageService(this._secure);

  final FlutterSecureStorage _secure;

  Future<void> saveToken(String token) async {
    try {
      await _secure.write(key: AppConstants.tokenKey, value: token);
    } catch (e) {
      _log.e('Failed to persist token', error: e);
      rethrow;
    }
  }

  Future<String?> getToken() async {
    try {
      return await _secure.read(key: AppConstants.tokenKey);
    } catch (e) {
      _log.e('Failed to read token', error: e);
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _secure.delete(key: AppConstants.tokenKey);
    } catch (e) {
      _log.e('Failed to delete token', error: e);
    }
  }

  Future<void> saveUsername(String username) async {
    try {
      await _secure.write(key: AppConstants.usernameKey, value: username);
    } catch (e) {
      _log.e('Failed to persist username', error: e);
    }
  }

  Future<String?> getUsername() async {
    try {
      return await _secure.read(key: AppConstants.usernameKey);
    } catch (e) {
      _log.e('Failed to read username', error: e);
      return null;
    }
  }

  Future<void> saveTokenExpiry(DateTime expiry) async {
    try {
      await _secure.write(
        key: AppConstants.tokenExpiryKey,
        value: expiry.toIso8601String(),
      );
    } catch (e) {
      _log.e('Failed to persist token expiry', error: e);
    }
  }

  Future<DateTime?> getTokenExpiry() async {
    try {
      final raw = await _secure.read(key: AppConstants.tokenExpiryKey);
      return raw != null ? DateTime.tryParse(raw) : null;
    } catch (e) {
      _log.e('Failed to read token expiry', error: e);
      return null;
    }
  }

  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    final expiry = await getTokenExpiry();
    if (expiry == null) return true; // No expiry stored → assume valid
    return DateTime.now().isBefore(expiry);
  }

  Future<void> clearAll() async {
    try {
      await _secure.deleteAll();
    } catch (e) {
      _log.e('Failed to clear secure storage', error: e);
    }
  }
}
