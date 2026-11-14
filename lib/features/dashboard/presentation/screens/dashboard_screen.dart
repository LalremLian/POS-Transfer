import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username =
        ref.watch(authNotifierProvider).valueOrNull?.token?.username ?? '';
    final counts = ref.watch(transferCountsProvider);
    final cs = Theme.of(context).colorScheme;

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, $username',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your file transfers',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),

          // Transfer summary
          const _SectionLabel('Transfer activity'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(
                icon: Icons.sync,
                label: 'Active',
                value: counts.active,
                color: cs.primary,
              ),
              _StatCard(
                icon: Icons.queue,
                label: 'Queued',
                value: counts.queued,
                color: cs.tertiary,
              ),
              _StatCard(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                value: counts.completed,
                color: Colors.green,
              ),
              _StatCard(
                icon: Icons.error_outline,
                label: 'Failed',
                value: counts.failed,
                color: cs.error,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Quick actions
          const _SectionLabel('Quick actions'),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Files'),
            onPressed: () => context.go(Routes.upload),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.download_for_offline),
            label: const Text('Download Files'),
            onPressed: () => context.go(Routes.download),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('Transfer History'),
            onPressed: () => context.go(Routes.history),
          ),

          const SizedBox(height: 24),
          if (counts.total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No transfers yet. Upload or download a file to begin.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
