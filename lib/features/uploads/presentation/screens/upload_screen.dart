import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../providers/upload_providers.dart';
import '../widgets/upload_screen_widgets.dart';

class UploadScreen extends ConsumerWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(uploadNotifierProvider);
    final activeId = selection.activeTransferId;
    final transferAsync =
        activeId == null ? null : ref.watch(transferProvider(activeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FileSelectionCard(selection: selection),
            const SizedBox(height: 16),

            if (!selection.hasSelection)
              FilledButton.icon(
                onPressed: selection.isPicking
                    ? null
                    : () => ref.read(uploadNotifierProvider.notifier).pickFile(),
                icon: selection.isPicking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file),
                label: Text(selection.isPicking ? 'Opening…' : 'Select File'),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: activeId == null
                          ? () => ref.read(uploadNotifierProvider.notifier).startUpload()
                          : null,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Start Upload'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: activeId != null
                        ? null
                        : () => ref.read(uploadNotifierProvider.notifier).clearSelection(),
                    icon: const Icon(Icons.close),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            if (activeId != null && transferAsync != null)
              ActiveTransferSection(transferAsync: transferAsync, ref: ref),

            if (selection.error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: selection.error!),
            ],

            const SizedBox(height: 32),
            const LimitationNote(),
          ],
        ),
      ),
    );
  }
}

