import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transfer_providers.dart';
import '../widgets/transfer_screen_widgets.dart';

class TransferDetailScreen extends ConsumerWidget {
  const TransferDetailScreen({super.key, required this.transferId});
  final String transferId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transferProvider(transferId));

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Details')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (t) => DetailBody(transfer: t),
      ),
    );
  }
}

