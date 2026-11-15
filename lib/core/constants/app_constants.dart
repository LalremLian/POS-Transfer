class AppConstants {
  AppConstants._();

  // App identity
  static const String appName = 'POS Transfer';
  static const String appVersion = '1.0.0';

  // Secure storage keys
  static const String tokenKey = 'auth_token';
  static const String usernameKey = 'auth_username';
  static const String tokenExpiryKey = 'auth_token_expiry';

  // SharedPreferences keys
  static const String transfersKey = 'transfers_v1';
  static const String settingsKey = 'app_settings_v1';

  // Notification channel IDs
  static const String uploadChannelId = 'pos_uploads';
  static const String uploadChannelName = 'File Uploads';
  static const String downloadChannelId = 'pos_downloads';
  static const String downloadChannelName = 'File Downloads';
  static const String serviceChannelId = 'pos_transfer_service';
  static const String serviceChannelName = 'Transfer Service';

  // Foreground service notification
  static const int serviceNotificationId = 1;

  // Transfer directions
  static const String tempFileSuffix = '.part';

  // Download directory name
  static const String downloadDirName = 'PosTransfer';

  // Worker task names
  static const String recoveryTaskName = 'pos_transfer_recovery';
}
