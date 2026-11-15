import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../transfers/domain/entities/transfer_entity.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../../transfers/presentation/widgets/transfer_card.dart';

/// Full dashboard — live transfer counts + active/queued/completed lists (8.1).
/// Each TransferCard subscribes to its own isolated stream so progress on one
/// never rebuilds the others (8.2).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username =
        ref.watch(authNotifierProvider).valueOrNull?.token?.username ?? '';
    final counts = ref.watch(transferCountsProvider);
    final rosterAsync = ref.watch(transferRosterProvider);
    final cs = Theme.of(context).colorScheme;

    // Connectivity banner (Phase 9)
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
          // ── Offline banner (Phase 9) ────────────────────────────────
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
                // ── Greeting ─────────────────────────────────────────────
                Text('Welcome, $username',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('File transfer manager',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
                const SizedBox(height: 20),

                // ── Stat chips ─────────────────────────────────────────
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(
                        icon: Icons.sync,
                        label: 'Active',
                        value: counts.active,
                        color: cs.primary),
                    _StatChip(
                        icon: Icons.queue,
                        label: 'Queued',
                        value: counts.queued,
                        color: cs.tertiary),
                    _StatChip(
                        icon: Icons.check_circle_outline,
                        label: 'Done',
                        value: counts.completed,
                        color: Colors.green),
                    _StatChip(
                        icon: Icons.error_outline,
                        label: 'Failed',
                        value: counts.failed,
                        color: cs.error),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Quick actions ─────────────────────────────────────
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

                // ── Transfer list ─────────────────────────────────────
                rosterAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (roster) {
                    if (roster.isEmpty) return const _EmptyState();

                    // Active + paused at the top, then completed, then cancelled.
                    final active =
                        roster.where((t) => t.isActive).toList();
                    final done = roster
                        .where((t) => t.status == TransferStatus.completed)
                        .toList();
                    final failed = roster
                        .where((t) =>
                            t.status == TransferStatus.failed ||
                            t.status == TransferStatus.cancelled)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (active.isNotEmpty) ...[
                          _SectionLabel('Active (${active.length})'),
                          const SizedBox(height: 8),
                          _TransferList(ids: active.map((t) => t.id).toList()),
                          const SizedBox(height: 20),
                        ],
                        if (done.isNotEmpty) ...[
                          _SectionLabel('Completed (${done.length})'),
                          const SizedBox(height: 8),
                          _TransferList(ids: done.map((t) => t.id).toList()),
                          const SizedBox(height: 20),
                        ],
                        if (failed.isNotEmpty) ...[
                          _SectionLabel('Failed / Cancelled (${failed.length})'),
                          const SizedBox(height: 8),
                          _TransferList(
                              ids: failed.map((t) => t.id).toList()),
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

/// Renders a list of TransferCards — each card isolated, no cross-rebuilds.
class _TransferList extends StatelessWidget {
  const _TransferList({required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: ids.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => TransferCard(transferId: ids[i]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text('$value',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_sync_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            const Text('No transfers yet'),
            const SizedBox(height: 4),
            Text('Upload or download a file to begin.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
