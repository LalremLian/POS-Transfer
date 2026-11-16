import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../transfers/domain/entities/transfer_entity.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../providers/upload_providers.dart';
// ── File selection card ──────────────────────────────────────────────────

class FileSelectionCard extends StatelessWidget {
  const FileSelectionCard({required this.selection});
  final UploadSelection selection;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!selection.hasSelection) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.upload_file_outlined, size: 48, color: cs.outline),
              const SizedBox(height: 12),
              Text('No file selected',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Pick a CSV, image, video, or any file to upload',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.insert_drive_file_outlined,
                  color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selection.fileName!,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    '${FileUtils.formatBytes(selection.fileSize ?? 0)} · '
                        '${selection.mimeType ?? 'file'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active transfer section ───────────────────────────────────────────────

class ActiveTransferSection extends StatelessWidget {
  const ActiveTransferSection(
      {required this.transferAsync, required this.ref});
  final AsyncValue<TransferEntity> transferAsync;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return transferAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => ErrorBanner(message: e.toString()),
      data: (transfer) => _TransferProgressCard(
        transfer: transfer,
        manager: ref.read(transferManagerProvider),
        onStartNew: () {
          ref.read(uploadNotifierProvider.notifier).clearActive();
          ref.read(uploadNotifierProvider.notifier).clearSelection();
        },
      ),
    );
  }
}

class _TransferProgressCard extends StatelessWidget {
  const _TransferProgressCard({
    required this.transfer,
    required this.manager,
    required this.onStartNew,
  });
  final TransferEntity transfer;
  final TransferManager manager;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (transfer.progress * 100).clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(transfer.fileName,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                _StatusChip(status: transfer.status),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: transfer.progress, minHeight: 6),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${FileUtils.formatBytes(transfer.transferredBytes)} / '
                      '${FileUtils.formatBytes(transfer.totalBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text('${pct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              transfer.status == TransferStatus.completed
                  ? 'Completed'
                  : transfer.retryCount > 0
                  ? 'Retrying (${transfer.retryCount}) · '
                  '${FileUtils.formatSpeed(transfer.speedBytesPerSec)}'
                  : FileUtils.formatSpeed(transfer.speedBytesPerSec),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (transfer.errorMessage != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: transfer.errorMessage!),
            ],
            const SizedBox(height: 16),
            _ActionRow(
                transfer: transfer,
                manager: manager,
                onStartNew: onStartNew),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.transfer,
    required this.manager,
    required this.onStartNew,
  });
  final TransferEntity transfer;
  final TransferManager manager;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: switch (transfer.status) {
        TransferStatus.preparing || TransferStatus.running => [
          _ActionButton(
              icon: Icons.pause,
              label: 'Pause',
              onTap: () => manager.pause(transfer.id)),
          _ActionButton(
              icon: Icons.cancel,
              label: 'Cancel',
              destructive: true,
              onTap: () =>
                  _confirmCancel(context, manager.cancel, transfer.id)),
        ],
        TransferStatus.paused => [
          _ActionButton(
              icon: Icons.play_arrow,
              label: 'Resume',
              onTap: () => manager.resume(transfer.id)),
          _ActionButton(
              icon: Icons.cancel,
              label: 'Cancel',
              destructive: true,
              onTap: () =>
                  _confirmCancel(context, manager.cancel, transfer.id)),
        ],
        TransferStatus.failed || TransferStatus.cancelled => [
          _ActionButton(
              icon: Icons.refresh,
              label: 'Retry',
              onTap: () => manager.retry(transfer.id)),
          _ActionButton(
              icon: Icons.delete_outline,
              label: 'Remove',
              onTap: () {
                manager.removeCompleted(transfer.id);
                onStartNew();
              }),
        ],
        TransferStatus.completed => [
          _ActionButton(
              icon: Icons.add, label: 'New Upload', onTap: onStartNew),
        ],
        TransferStatus.queued => [
          _ActionButton(
              icon: Icons.cancel,
              label: 'Cancel',
              destructive: true,
              onTap: () =>
                  _confirmCancel(context, manager.cancel, transfer.id)),
        ],
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
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
      TransferStatus.preparing => ('Preparing', Colors.blue),
      TransferStatus.running   => ('Uploading', Colors.blue),
      TransferStatus.paused    => ('Paused', Colors.amber),
      TransferStatus.completed => ('Completed', Colors.green),
      TransferStatus.failed    => ('Failed', Colors.red),
      TransferStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                TextStyle(color: cs.onErrorContainer, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class LimitationNote extends StatelessWidget {
  const LimitationNote();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'The backend does not support resumable uploads. '
                  'Pausing cancels the request; resuming restarts from the beginning. '
                  'Downloads resume from the last byte.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmCancel(
    BuildContext context,
    Future<void> Function(String id) cancel,
    String id,
    ) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel upload?'),
      content:
      const Text('The upload will be stopped. You can retry it later.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel')),
      ],
    ),
  );
  if (ok == true) cancel(id);
}
