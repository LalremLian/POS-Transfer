import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

final _log = Logger();

class LocalDatabaseService {
  LocalDatabaseService(this._prefs);

  final SharedPreferences _prefs;

  // Transfers

  /// Returns all persisted transfer maps. Never throws.
  List<Map<String, dynamic>> loadAllTransfers() {
    try {
      final raw = _prefs.getString(AppConstants.transfersKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      _log.e('Failed to load transfers from storage', error: e);
      return [];
    }
  }

  /// Persists the full list of transfer maps.
  Future<void> saveAllTransfers(List<Map<String, dynamic>> transfers) async {
    try {
      final encoded = jsonEncode(transfers);
      await _prefs.setString(AppConstants.transfersKey, encoded);
    } catch (e) {
      _log.e('Failed to save transfers to storage', error: e);
    }
  }

  /// Removes all persisted transfer data.
  Future<void> clearAllTransfers() async {
    try {
      await _prefs.remove(AppConstants.transfersKey);
    } catch (e) {
      _log.e('Failed to clear transfers from storage', error: e);
    }
  }

  // Settings

  Future<void> saveSetting(String key, String value) async {
    try {
      await _prefs.setString('setting_$key', value);
    } catch (e) {
      _log.e('Failed to save setting $key', error: e);
    }
  }

  String? getSetting(String key) {
    try {
      return _prefs.getString('setting_$key');
    } catch (e) {
      _log.e('Failed to read setting $key', error: e);
      return null;
    }
  }
}
