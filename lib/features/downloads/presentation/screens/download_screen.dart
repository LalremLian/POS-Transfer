import 'package:flutter/material.dart';

/// Download screen — full implementation added in Phase 6.
class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_for_offline_outlined, size: 64),
            SizedBox(height: 16),
            Text('Download module — coming in Phase 6'),
          ],
        ),
      ),
    );
  }
}
