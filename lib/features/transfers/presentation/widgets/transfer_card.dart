import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_manager.dart';
import '../providers/transfer_providers.dart';

class TransferCard extends ConsumerWidget {
  const TransferCard({super.key, required this.transferId});
  final String transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferProvider(transferId));
    return async.when(
      loading: () => const _CardShell(child: LinearProgressIndicator()),
      error: (e, _) => _CardShell(
        child: Text('Error: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
      data: (t) => _TransferCardContent(transfer: t),
    );
  }
}

class _TransferCardContent extends ConsumerWidget {
  const _TransferCardContent({required this.transfer});
  final TransferEntity transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(transferManagerProvider);
    final cs = Theme.of(context).colorScheme;
    final isUpload = transfer.type == TransferType.upload;
    final pct = (transfer.progress * 100).clamp(0.0, 100.0);

    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(
                isUpload ? Icons.upload_file_outlined : Icons.download_for_offline_outlined,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer.fileName,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(status: transfer.status),
            ],
          ),

          // Progress bar (only while active)
          if (transfer.isActive) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: transfer.status == TransferStatus.queued
                    ? null // indeterminate while queued
                    : transfer.progress,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FileUtils.formatBytes(transfer.transferredBytes)}'
                  ' / ${FileUtils.formatBytes(transfer.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (transfer.speedBytesPerSec > 0)
                  Text(
                    FileUtils.formatSpeed(transfer.speedBytesPerSec),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                Text(
                  '${pct.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],

          // Completed: show size and checksum hint
          if (transfer.status == TransferStatus.completed) ...[
            const SizedBox(height: 4),
            Text(
              FileUtils.formatBytes(transfer.totalBytes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],

          // Error message
          if (transfer.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              transfer.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 10),

          // Action row
          Row(
            children: [
              ..._actions(context, manager),
              const Spacer(),
              // Details button
              TextButton(
                onPressed: () => context.push(Routes.detailPath(transfer.id)),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, TransferManager manager) {
    return switch (transfer.status) {
      TransferStatus.running || TransferStatus.preparing => [
          _Btn(Icons.pause, 'Pause', () => manager.pause(transfer.id)),
          _Btn(Icons.cancel_outlined, 'Cancel',
              () => manager.cancel(transfer.id),
              danger: true),
        ],
      TransferStatus.queued => [
          _Btn(Icons.cancel_outlined, 'Cancel',
              () => manager.cancel(transfer.id),
              danger: true),
        ],
      TransferStatus.paused => [
          _Btn(Icons.play_arrow, 'Resume', () => manager.resume(transfer.id)),
          _Btn(Icons.cancel_outlined, 'Cancel',
              () => manager.cancel(transfer.id),
              danger: true),
        ],
      TransferStatus.failed || TransferStatus.cancelled => [
          _Btn(Icons.refresh, 'Retry', () => manager.retry(transfer.id)),
          _Btn(Icons.delete_outline, 'Remove',
              () => manager.removeCompleted(transfer.id)),
        ],
      TransferStatus.completed => [
          _Btn(Icons.delete_outline, 'Remove',
              () => manager.removeCompleted(transfer.id)),
        ],
    };
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.label, this.onTap, {this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide(color: color.withAlpha(80)),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransferStatus.queued    => ('Queued', Colors.grey),
      TransferStatus.preparing => ('Starting', Colors.blue),
      TransferStatus.running   => ('Active', Colors.blue),
      TransferStatus.paused    => ('Paused', Colors.amber),
      TransferStatus.completed => ('Done', Colors.green),
      TransferStatus.failed    => ('Failed', Colors.red),
      TransferStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
