import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../widgets/dashboard_screen_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username =
        ref.watch(authNotifierProvider).valueOrNull?.token?.username ?? '';
    final counts = ref.watch(transferCountsProvider);
    final rosterAsync = ref.watch(transferRosterProvider);
    final cs = Theme.of(context).colorScheme;

    // Connectivity banner
    final isOnline = ref.watch(connectivityStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Transfer'),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text('Log out'),
                ]),
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
      body: Column(
        children: [
          // Offline banner
          if (!isOnline)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off,
                        size: 18, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Text('No internet connection',
                        style: TextStyle(color: cs.onErrorContainer)),
                  ],
                ),
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Greeting
                Text('Welcome, $username',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('File transfer manager',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
                const SizedBox(height: 20),

                // Responsive Stat chips
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
                    final items = [
                      (Icons.sync, 'Active', counts.active, cs.primary),
                      (Icons.queue, 'Queued', counts.queued, cs.tertiary),
                      (Icons.check_circle_outline, 'Done', counts.completed, Colors.green),
                      (Icons.error_outline, 'Failed', counts.failed, cs.error),
                    ];

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 48,
                      ),
                      itemBuilder: (context, index) {
                        final (icon, label, val, color) = items[index];
                        return StatChip(
                          icon: icon,
                          label: label,
                          value: val,
                          color: color,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Quick actions
                FilledButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Files'),
                  onPressed: () => context.go(Routes.upload),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_for_offline),
                  label: const Text('Browse & Download'),
                  onPressed: () => context.go(Routes.download),
                ),
                const SizedBox(height: 28),

                // Transfer list
                rosterAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => ErrorState(message: e.toString()),
                  data: (roster) {
                    if (roster.isEmpty) return const EmptyState();

                    // Active transfers at the top.
                    final active =
                        roster.where((t) => t.isActive).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (active.isNotEmpty) ...[
                          SectionLabel('Active (${active.length})'),
                          const SizedBox(height: 8),
                          TransferList(ids: active.map((t) => t.id).toList()),
                          const SizedBox(height: 20),
                        ],
                        TextButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('Full history'),
                          onPressed: () => context.go(Routes.history),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


