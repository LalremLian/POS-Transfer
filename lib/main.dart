import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di/providers.dart';
import 'core/services/background_transfer_service.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background service must be initialised before runApp.
  await BackgroundTransferService.initialize();

  // Initialize local notifications.
  // The tap callback is wired after the router is available (in app.dart).
  // We initialize here without a callback first so channels are created;
  // the callback is set via NotificationService.setTapCallback() once the
  // router is ready.
  await NotificationService.instance.initialize();

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: WithForegroundTask(child: const PosTransferApp()),
    ),
  );
}
