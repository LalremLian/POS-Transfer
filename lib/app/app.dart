import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/notification_service.dart';
import '../core/services/transfer_service_observer.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PosTransferApp extends ConsumerStatefulWidget {
  const PosTransferApp({super.key});

  @override
  ConsumerState<PosTransferApp> createState() => _PosTransferAppState();
}

class _PosTransferAppState extends ConsumerState<PosTransferApp> {
  bool _callbackWired = false;

  @override
  void initState() {
    super.initState();
    // Wire the notification tap callback once the first frame is built.
    // We do this once — the router instance is stable; auth redirects happen
    // inside GoRouter, not by replacing the router.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _wireNotificationCallback();
    });
  }

  void _wireNotificationCallback() {
    if (_callbackWired) return;
    NotificationService.instance.setTapCallback((payload) {
      final route = Routes.payloadToRoute(payload);
      ref.read(appRouterProvider).go(route);
    });
    _callbackWired = true;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return TransferServiceObserver(
      child: MaterialApp.router(
        title: 'POS Transfer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: router,
      ),
    );
  }
}
