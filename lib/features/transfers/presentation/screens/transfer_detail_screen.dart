import 'package:flutter/material.dart';

/// Transfer detail screen — full implementation added in Phase 9.
class TransferDetailScreen extends StatelessWidget {
  const TransferDetailScreen({super.key, required this.transferId});
  final String transferId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer Details')),
      body: Center(
        child: Text('Transfer $transferId — full detail coming in Phase 9'),
      ),
    );
  }
}
