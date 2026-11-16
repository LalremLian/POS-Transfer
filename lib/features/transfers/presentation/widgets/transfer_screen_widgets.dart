import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_manager.dart';
import '../providers/transfer_providers.dart';
import '../widgets/transfer_card.dart';

class DetailBody extends ConsumerWidget {
  const DetailBody({required this.transfer});
  final TransferEntity transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(transferManagerProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live progress card — isolated rebuild
        TransferCard(transferId: transfer.id),
        const SizedBox(height: 20),

        // ── File info ────────────────────────────────────────────────
        _Section(
          title: 'File',
          rows: [
            _Row('Name', transfer.fileName),
            _Row('Size', FileUtils.formatBytes(transfer.totalBytes)),
            if (transfer.remoteFileName != null)
              _Row('Remote name', transfer.remoteFileName!),
            if (transfer.localFilePath != null)
              _Row('Local path', transfer.localFilePath!),
            if (transfer.destinationPath != null)
              _Row('Destination', transfer.destinationPath!),
          ],
        ),
        const SizedBox(height: 16),

        // ── Transfer info ────────────────────────────────────────────
        _Section(
          title: 'Transfer',
          rows: [
            _Row('Type', transfer.type == TransferType.upload ? 'Upload' : 'Download'),
            _Row('Status', _statusLabel(transfer.status)),
            if (transfer.startedAt != null)
              _Row('Started', AppDateUtils.formatDateTime(transfer.startedAt!)),
            if (transfer.completedAt != null)
              _Row('Completed', AppDateUtils.formatDateTime(transfer.completedAt!)),
            if (transfer.startedAt != null && transfer.completedAt != null)
              _Row('Duration', AppDateUtils.formatDuration(
                  transfer.completedAt!.difference(transfer.startedAt!))),
            _Row('Retry count', '${transfer.retryCount}'),
          ],
        ),
        const SizedBox(height: 16),

        // ── Integrity ────────────────────────────────────────────────
        if (transfer.localChecksum != null) ...[
          _Section(
            title: 'Integrity',
            rows: [
              _Row(
                'SHA-256 (local)',
                transfer.localChecksum!,
                monospace: true,
                copyable: true,
              ),
              const _InfoRow(
                'Note: This is a locally calculated digest. '
                    'Server-side verification requires a backend checksum endpoint '
                    'which is not currently available.',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Error ────────────────────────────────────────────────────
        if (transfer.errorMessage != null) ...[
          _Section(
            title: 'Error',
            rows: [_Row('Message', transfer.errorMessage!)],
          ),
          const SizedBox(height: 16),
        ],

        // ── Actions ──────────────────────────────────────────────────
        if (!transfer.isTerminal || transfer.status == TransferStatus.failed)
          _ActionsRow(transfer: transfer, manager: manager),
      ],
    );
  }

  String _statusLabel(TransferStatus s) {
    return switch (s) {
      TransferStatus.queued    => 'Queued',
      TransferStatus.preparing => 'Preparing',
      TransferStatus.running   => 'Running',
      TransferStatus.paused    => 'Paused',
      TransferStatus.completed => 'Completed',
      TransferStatus.failed    => 'Failed',
      TransferStatus.cancelled => 'Cancelled',
    };
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.transfer, required this.manager});
  final TransferEntity transfer;
  final TransferManager manager;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: switch (transfer.status) {
        TransferStatus.running || TransferStatus.preparing => [
          OutlinedButton.icon(
            onPressed: () => manager.pause(transfer.id),
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
          OutlinedButton.icon(
            onPressed: () => manager.cancel(transfer.id),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
          ),
        ],
        TransferStatus.paused => [
          FilledButton.icon(
            onPressed: () => manager.resume(transfer.id),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
          OutlinedButton.icon(
            onPressed: () => manager.cancel(transfer.id),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
          ),
        ],
        TransferStatus.failed || TransferStatus.cancelled => [
          FilledButton.icon(
            onPressed: () => manager.retry(transfer.id),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
        _ => [],
      },
    );
  }
}

// ── Reusable detail widgets ───────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Divider(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value,
      {this.monospace = false, this.copyable = false});
  final String label;
  final String value;
  final bool monospace;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: copyable
                  ? () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              }
                  : null,
              child: Text(
                value,
                style: monospace
                    ? const TextStyle(
                    fontFamily: 'monospace', fontSize: 11)
                    : Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                )),
          ),
        ],
      ),
    );
  }
}
