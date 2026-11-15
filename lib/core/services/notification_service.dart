import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';
import '../transfer/transfer_config.dart';

final _log = Logger();

const _payloadUpload = 'upload';
const _payloadDownload = 'download';

typedef NotificationTapCallback = void Function(String route);

/// Centralized notification service — flutter_local_notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  final Map<String, DateTime> _lastProgressNotif = {};

  NotificationTapCallback? _tapCallback;

  // If a tap arrives before the router is wired or auth resolves, queue payload here.
  String? _pendingRoute;

  /// Returns and clears any pending payload string queued from a notification tap.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Register the navigation callback. Call this once the router is ready.
  /// If a tap arrived before this call, it navigates immediately.
  void setTapCallback(NotificationTapCallback callback) {
    _tapCallback = callback;
    // Drain any tap that arrived before the router was ready.
    final pending = _pendingRoute;
    if (pending != null) {
      _pendingRoute = null;
      callback(pending);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
    );

    await _createChannels();

    // Check if the app was cold-launched by tapping a notification.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload ?? '';
      if (payload.isNotEmpty) {
        // Router not ready yet — queue it. setTapCallback or redirect will drain it.
        _pendingRoute = payload;
      }
    }

    _initialized = true;
    _log.d('NotificationService initialised');
  }

  void _onTap(NotificationResponse details) {
    final payload = details.payload ?? '';
    if (payload.isEmpty) return;
    _pendingRoute = payload;
    final cb = _tapCallback;
    if (cb != null) {
      cb(payload);
      _pendingRoute = null;
    }
  }

  Future<void> _createChannels() async {
    const uploadChannel = AndroidNotificationChannel(
      AppConstants.uploadChannelId,
      AppConstants.uploadChannelName,
      description: 'File upload progress and results',
      importance: Importance.defaultImportance,
    );
    const downloadChannel = AndroidNotificationChannel(
      AppConstants.downloadChannelId,
      AppConstants.downloadChannelName,
      description: 'File download progress and results',
      importance: Importance.defaultImportance,
    );
    const serviceChannel = AndroidNotificationChannel(
      AppConstants.serviceChannelId,
      AppConstants.serviceChannelName,
      description: 'Background transfer service',
      importance: Importance.low,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(uploadChannel);
    await android?.createNotificationChannel(downloadChannel);
    await android?.createNotificationChannel(serviceChannel);
  }

  // Upload

  void notifyUploadStarted(String id, String fileName) {
    _show(
      id: _notifId(id),
      title: 'Uploading',
      body: fileName,
      channelId: AppConstants.uploadChannelId,
      channelName: AppConstants.uploadChannelName,
      ongoing: true,
      progress: 0,
      payload: _payloadUpload,
    );
  }

  void notifyUploadProgress(String transferId, String fileName, int percent,
      {TransferConfig config = transferConfig}) {
    if (_isThrottled(transferId, config)) return;
    _show(
      id: _notifId(transferId),
      title: 'Uploading $fileName',
      body: '$percent%',
      channelId: AppConstants.uploadChannelId,
      channelName: AppConstants.uploadChannelName,
      ongoing: true,
      progress: percent,
      payload: _payloadUpload,
    );
  }

  void notifyUploadCompleted(String id, String fileName) {
    _lastProgressNotif.remove(id);
    _show(
      id: _notifId(id),
      title: 'Upload complete',
      body: fileName,
      channelId: AppConstants.uploadChannelId,
      channelName: AppConstants.uploadChannelName,
      ongoing: false,
      progress: 100,
      payload: _payloadUpload,
    );
  }

  void notifyUploadFailed(String id, String fileName, String reason) {
    _lastProgressNotif.remove(id);
    _show(
      id: _notifId(id),
      title: 'Upload failed',
      body: '$fileName — $reason',
      channelId: AppConstants.uploadChannelId,
      channelName: AppConstants.uploadChannelName,
      ongoing: false,
      payload: _payloadUpload,
    );
  }

  // Download

  void notifyDownloadStarted(String id, String fileName) {
    _show(
      id: _notifId(id),
      title: 'Downloading',
      body: fileName,
      channelId: AppConstants.downloadChannelId,
      channelName: AppConstants.downloadChannelName,
      ongoing: true,
      progress: 0,
      payload: _payloadDownload,
    );
  }

  void notifyDownloadProgress(String transferId, String fileName, int percent,
      {TransferConfig config = transferConfig}) {
    if (_isThrottled(transferId, config)) return;
    _show(
      id: _notifId(transferId),
      title: 'Downloading $fileName',
      body: '$percent%',
      channelId: AppConstants.downloadChannelId,
      channelName: AppConstants.downloadChannelName,
      ongoing: true,
      progress: percent,
      payload: _payloadDownload,
    );
  }

  void notifyDownloadCompleted(String id, String fileName, String? savePath) {
    _lastProgressNotif.remove(id);
    _show(
      id: _notifId(id),
      title: 'Download complete',
      body: savePath != null ? '$fileName saved' : fileName,
      channelId: AppConstants.downloadChannelId,
      channelName: AppConstants.downloadChannelName,
      ongoing: false,
      progress: 100,
      payload: _payloadDownload,
    );
  }

  void notifyDownloadFailed(String id, String fileName, String reason) {
    _lastProgressNotif.remove(id);
    _show(
      id: _notifId(id),
      title: 'Download failed',
      body: '$fileName — $reason',
      channelId: AppConstants.downloadChannelId,
      channelName: AppConstants.downloadChannelName,
      ongoing: false,
      payload: _payloadDownload,
    );
  }

  void cancel(String transferId) {
    _lastProgressNotif.remove(transferId);
    _plugin.cancel(_notifId(transferId));
  }

  Future<void> cancelAll() async {
    _lastProgressNotif.clear();
    await _plugin.cancelAll();
  }

  // Internal

  bool _isThrottled(String id, TransferConfig config) {
    final now = DateTime.now();
    final last = _lastProgressNotif[id];
    if (last != null &&
        now.difference(last).inMilliseconds < config.notificationIntervalMs) {
      return true;
    }
    _lastProgressNotif[id] = now;
    return false;
  }

  void _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    bool ongoing = false,
    int? progress,
    String? payload,
  }) {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      ongoing: ongoing,
      autoCancel: !ongoing,
      onlyAlertOnce: true,
      showProgress: progress != null,
      maxProgress: 100,
      progress: progress ?? 0,
      importance: ongoing ? Importance.low : Importance.defaultImportance,
      priority: ongoing ? Priority.low : Priority.defaultPriority,
    );

    _plugin
        .show(id, title, body, NotificationDetails(android: androidDetails),
            payload: payload)
        .catchError((e) => _log.w('Notification show failed: $e'));
  }

  int _notifId(String transferId) => transferId.hashCode.abs() % 100000;
}
