import 'package:flutter/material.dart';

/// Upload screen — full implementation added in Phase 5.
class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_outlined, size: 64),
            SizedBox(height: 16),
            Text('Upload module — coming in Phase 5'),
          ],
        ),
      ),
    );
  }
}
