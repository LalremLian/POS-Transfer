import 'package:flutter/material.dart';

/// Transfer history screen — full implementation added in Phase 9.
class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer History')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_outlined, size: 64),
            SizedBox(height: 16),
            Text('Transfer history — coming in Phase 9'),
          ],
        ),
      ),
    );
  }
}
