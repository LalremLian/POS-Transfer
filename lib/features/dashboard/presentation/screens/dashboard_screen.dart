import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

/// Dashboard screen — full implementation added in Phase 9.
/// This stub provides the routing target so the app compiles.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref
        .watch(authNotifierProvider)
        .valueOrNull
        ?.token
        ?.username ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Transfer'),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Log out'),
                  ],
                ),
              ),
            ],
            onSelected: (v) {
              if (v == 'logout') {
                ref.read(authNotifierProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_sync_rounded, size: 64),
            const SizedBox(height: 16),
            Text(
              'Welcome, $username',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Transfer engine initializing…'),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Files'),
                  onPressed: () => context.go(Routes.upload),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Download Files'),
                  onPressed: () => context.go(Routes.download),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
