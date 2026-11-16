import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_manager.dart';
import '../providers/transfer_providers.dart';
import '../widgets/transfer_card.dart';

class TransferHistoryScreen extends ConsumerStatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  ConsumerState<TransferHistoryScreen> createState() =>
      _TransferHistoryScreenState();
}

class _TransferHistoryScreenState
    extends ConsumerState<TransferHistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(transferRosterProvider);
    final manager = ref.read(transferManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear completed',
            onPressed: () => _confirmClearAll(context, manager),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: _Filter.values
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1),

          // ── List ──────────────────────────────────────────────────
          Expanded(
            child: rosterAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (roster) {
                final filtered = _applyFilter(roster);
                if (filtered.isEmpty) {
                  return _EmptyState(filter: _filter);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      TransferCard(transferId: filtered[i].id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TransferEntity> _applyFilter(List<TransferEntity> roster) {
    return switch (_filter) {
      _Filter.all       => roster,
      _Filter.uploads   => roster.where((t) => t.type == TransferType.upload).toList(),
      _Filter.downloads => roster.where((t) => t.type == TransferType.download).toList(),
      _Filter.active    => roster.where((t) => t.isActive).toList(),
      _Filter.completed => roster.where((t) => t.status == TransferStatus.completed).toList(),
      _Filter.failed    => roster.where((t) =>
          t.status == TransferStatus.failed ||
          t.status == TransferStatus.cancelled).toList(),
    };
  }

  Future<void> _confirmClearAll(
      BuildContext context, TransferManager manager) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed?'),
        content: const Text(
            'Remove all completed and cancelled transfers from history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await manager.clearAllTerminal();
  }
}

enum _Filter {
  all('All'),
  uploads('Uploads'),
  downloads('Downloads'),
  active('Active'),
  completed('Completed'),
  failed('Failed');

  const _Filter(this.label);
  final String label;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            filter == _Filter.all
                ? 'No transfers yet'
                : 'No ${filter.label.toLowerCase()} found',
          ),
        ],
      ),
    );
  }
}
