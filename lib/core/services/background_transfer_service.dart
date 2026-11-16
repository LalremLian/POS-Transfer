import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:logger/logger.dart';

import '../constants/app_constants.dart';

final _log = Logger();

class BackgroundTransferService {
  BackgroundTransferService._();
  static final BackgroundTransferService instance =
      BackgroundTransferService._();

  bool _serviceRunning = false;

  /// Call once at app startup, before runApp.
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.serviceChannelId,
        channelName: AppConstants.serviceChannelName,
        channelDescription: 'Shown while file transfers are running in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Tick every 2 s so the notification stays updated.
        eventAction: ForegroundTaskEventAction.repeat(2000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _log.d('BackgroundTransferService initialised');
  }

  /// Start or update the foreground service.
  Future<void> startIfNeeded({
    required int activeCount,
    String? statusText,
  }) async {
    final title = activeCount == 1
        ? 'POS Transfer active'
        : 'POS Transfer — $activeCount active';
    final body =
        statusText ?? 'File transfers are running in the background';

    if (_serviceRunning) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
      );
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: AppConstants.serviceNotificationId,
      notificationTitle: title,
      notificationText: body,
      callback: _transferTaskCallback,
    );

    _serviceRunning = result is ServiceRequestSuccess;
    if (_serviceRunning) {
      _log.d('Foreground service started ($activeCount active)');
    } else if (result is ServiceRequestFailure) {
      _log.w('Foreground service start failed: ${result.error}');
    }
  }

  /// Stop the service when no transfers are active.
  Future<void> stopIfIdle(int activeCount) async {
    if (!_serviceRunning || activeCount > 0) return;
    final result = await FlutterForegroundTask.stopService();
    _serviceRunning = false;
    if (result is ServiceRequestFailure) {
      _log.w('Foreground service stop failed: ${result.error}');
    } else {
      _log.d('Foreground service stopped (no active transfers)');
    }
  }

  /// Request Android 13+ POST_NOTIFICATIONS permission.
  Future<bool> requestNotificationPermission() async {
    final perm = await FlutterForegroundTask.requestNotificationPermission();
    return perm == NotificationPermission.granted;
  }
}

/// Top-level entry point required by flutter_foreground_task.
/// Must be a top-level function annotated with @pragma.
@pragma('vm:entry-point')
void _transferTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TransferTaskHandler());
}

class _TransferTaskHandler extends TaskHandler {
  /// Called when the foreground service starts.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // The actual transfer work runs in the main Dart isolate via
    // TransferManager. This handler's only purpose is to keep the
    // foreground service alive.
    _log.d('Foreground task started (starter: $starter)');
  }

  /// Called on the repeat interval (every 2 s). Void — no async needed.
  @override
  void onRepeatEvent(DateTime timestamp) {
    // No-op: TransferManager in the main isolate manages all state.
  }

  /// Called when the service is destroyed.
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    _log.d('Foreground task destroyed');
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationDismissed() {}
}
