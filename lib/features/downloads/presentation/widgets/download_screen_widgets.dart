import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/file_utils.dart';
import '../../../transfers/domain/entities/transfer_entity.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../domain/entities/remote_file.dart';
import '../providers/download_providers.dart';

class RemoteFileCard extends ConsumerWidget {
  const RemoteFileCard({required this.file});
  final RemoteFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(transferRosterProvider).valueOrNull ?? [];
    final existing = roster.where((t) =>
    t.type == TransferType.download &&
        t.remoteFileName == file.name &&
        t.isActive);
    final activeTransfer = existing.isNotEmpty ? existing.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _fileIcon(file.type),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.originalName.isNotEmpty
                            ? file.originalName
                            : file.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${FileUtils.formatBytes(file.size)} · '
                            '${DateFormat('d MMM yyyy').format(file.uploadedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (activeTransfer == null)
                  _DownloadButton(file: file)
                else
                  _StatusChip(status: activeTransfer.status),
              ],
            ),
            if (activeTransfer != null) ...[
              const SizedBox(height: 10),
              _ActiveTransferRow(transferId: activeTransfer.id),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(String mime) {
    IconData icon;
    if (mime.startsWith('image/')) {
      icon = Icons.image_outlined;
    } else if (mime.startsWith('video/')) {
      icon = Icons.video_file_outlined;
    } else if (mime.contains('csv') || mime.contains('spreadsheet')) {
      icon = Icons.table_chart_outlined;
    } else if (mime.contains('pdf')) {
      icon = Icons.picture_as_pdf_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }
    return Icon(icon, size: 32);
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.file});
  final RemoteFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      onPressed: () =>
          ref.read(downloadNotifierProvider.notifier).startDownload(file),
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Download'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

// Active transfer progress

class _ActiveTransferRow extends ConsumerWidget {
  const _ActiveTransferRow({required this.transferId});
  final String transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferProvider(transferId));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) =>
          Text(e.toString(), style: const TextStyle(color: Colors.red, fontSize: 12)),
      data: (t) => _TransferProgress(transfer: t),
    );
  }
}

class _TransferProgress extends ConsumerWidget {
  const _TransferProgress({required this.transfer});
  final TransferEntity transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(transferManagerProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: transfer.status == TransferStatus.queued
                ? null
                : transfer.progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${FileUtils.formatBytes(transfer.transferredBytes)} / '
                  '${FileUtils.formatBytes(transfer.totalBytes)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              FileUtils.formatSpeed(transfer.speedBytesPerSec),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            Text('${(transfer.progress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (transfer.errorMessage != null)
          Text(transfer.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 6),
        _ActionBar(transfer: transfer, manager: manager),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.transfer, required this.manager});
  final TransferEntity transfer;
  final TransferManager manager;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: switch (transfer.status) {
        TransferStatus.running || TransferStatus.preparing => [
          _Btn(Icons.pause, 'Pause', () => manager.pause(transfer.id)),
          _Btn(Icons.cancel, 'Cancel', () => manager.cancel(transfer.id),
              danger: true),
        ],
        TransferStatus.paused => [
          _Btn(Icons.play_arrow, 'Resume',
                  () => manager.resume(transfer.id)),
          _Btn(Icons.cancel, 'Cancel', () => manager.cancel(transfer.id),
              danger: true),
        ],
        TransferStatus.failed || TransferStatus.cancelled => [
          _Btn(Icons.refresh, 'Retry', () => manager.retry(transfer.id)),
          _Btn(Icons.delete_outline, 'Remove',
                  () => manager.removeCompleted(transfer.id)),
        ],
        TransferStatus.completed => [
          _Btn(Icons.check, 'Done',
                  () => manager.removeCompleted(transfer.id)),
        ],
        _ => [],
      },
    );
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
      ),
    );
  }
}

// Status chip

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TransferStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TransferStatus.queued    => ('Queued', Colors.grey),
      TransferStatus.preparing => ('Starting', Colors.blue),
      TransferStatus.running   => ('Downloading', Colors.blue),
      TransferStatus.paused    => ('Paused', Colors.amber),
      TransferStatus.completed => ('Done', Colors.green),
      TransferStatus.failed    => ('Failed', Colors.red),
      TransferStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Empty / error ─────────────────────────────────────────────────────────

class EmptyView extends StatelessWidget {
  const EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 56),
          SizedBox(height: 12),
          Text('No files uploaded yet'),
          SizedBox(height: 6),
          Text('Upload a file first, then download it here.',
              style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}