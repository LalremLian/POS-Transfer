import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notification_service.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/downloads/presentation/screens/download_screen.dart';
import '../../features/transfers/presentation/screens/transfer_detail_screen.dart';
import '../../features/transfers/presentation/screens/transfer_history_screen.dart';
import '../../features/uploads/presentation/screens/upload_screen.dart';

abstract class Routes {
  static const splash         = '/splash';
  static const login          = '/login';
  static const dashboard      = '/dashboard';
  static const upload         = '/upload';
  static const download       = '/download';
  static const history        = '/history';
  static const transferDetail = '/transfers/:id';

  static String detailPath(String id) => '/transfers/$id';

  static String payloadToRoute(String payload) {
    return switch (payload) {
      'upload'   => upload,
      'download' => download,
      'history'  => history,
      _          => payload.startsWith('/') ? payload : dashboard,
    };
  }
}

// Router provider

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authNotifier = ref.read(authNotifierProvider);
      final current = state.matchedLocation;
      final onSplash = current == Routes.splash;
      final onLogin = current == Routes.login;

      // While the session restore Future is in-flight, hold on the splash
      // screen. This prevents the brief login-screen flash on cold start.
      if (authNotifier.isLoading) {
        return onSplash ? null : Routes.splash;
      }

      final isAuth = authNotifier.valueOrNull?.isAuthenticated ?? false;

      // Session resolved → leave splash/login for destination.
      if (isAuth) {
        if (onSplash || onLogin) {
          final pendingPayload = NotificationService.instance.consumePendingRoute();
          if (pendingPayload != null) {
            return Routes.payloadToRoute(pendingPayload);
          }
          return Routes.dashboard;
        }
        return null;
      }

      // Not authenticated → login (unless already there).
      return onLogin ? null : Routes.login;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.upload,
            builder: (_, __) => const UploadScreen(),
          ),
          GoRoute(
            path: Routes.download,
            builder: (_, __) => const DownloadScreen(),
          ),
          GoRoute(
            path: Routes.history,
            builder: (_, __) => const TransferHistoryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.transferDetail,
        builder: (_, state) => TransferDetailScreen(
          transferId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => _ErrorPage(state.error),
  );
});

// Auth-change listenable for GoRouter.refreshListenable

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

// Shell with bottom navigation

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child});
  final Widget child;

  static const _tabs = [
    (icon: Icons.dashboard_outlined,          label: 'Dashboard', path: Routes.dashboard),
    (icon: Icons.upload_file_outlined,         label: 'Upload',    path: Routes.upload),
    (icon: Icons.download_for_offline_outlined,label: 'Download',  path: Routes.download),
    (icon: Icons.history_outlined,             label: 'History',   path: Routes.history),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => loc.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx < 0 ? 0 : idx,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage(this.error);
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go(Routes.dashboard),
          child: const Text('Go to Dashboard'),
        ),
      ),
    );
  }
}
