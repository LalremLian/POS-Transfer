import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Eagerly initialize SharedPreferences so the sync provider can serve it.
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        // Override the unimplemented provider with the actual instance.
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const PosTransferApp(),
    ),
  );
}
