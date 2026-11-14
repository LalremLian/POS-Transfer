import 'dart:io';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../constants/app_constants.dart';

/// Utility helpers for file name and path operations.
/// Never exposes user paths in error messages.
abstract class FileUtils {
  FileUtils._();

  // ── Naming ────────────────────────────────────────────────────────────────

  /// Returns the `.part` temporary filename for a given final filename.
  static String toPartPath(String finalPath) => '$finalPath${AppConstants.tempFileSuffix}';

  /// Returns the final path for a completed `.part` file.
  static String fromPartPath(String partPath) =>
      partPath.endsWith(AppConstants.tempFileSuffix)
          ? partPath.substring(0, partPath.length - AppConstants.tempFileSuffix.length)
          : partPath;

  /// Returns true if the file at [path] is a `.part` temporary file.
  static bool isPartFile(String path) => path.endsWith(AppConstants.tempFileSuffix);

  /// Generates a safe filename avoiding path traversal.
  /// Strips directory separators and null bytes.
  static String sanitize(String filename) {
    return p.basename(filename)
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll('\x00', '');
  }

  /// Returns a collision-safe path by appending _(n) before the extension.
  static Future<String> resolveCollision(String directory, String filename) async {
    final safe = sanitize(filename);
    var candidate = p.join(directory, safe);
    if (!await File(candidate).exists()) return candidate;

    final ext = p.extension(safe);
    final base = p.basenameWithoutExtension(safe);
    var counter = 1;
    while (true) {
      candidate = p.join(directory, '${base}_($counter)$ext');
      if (!await File(candidate).exists()) return candidate;
      counter++;
      if (counter > 999) break; // Safety cap
    }
    return p.join(directory, '${base}_${DateTime.now().millisecondsSinceEpoch}$ext');
  }

  // ── Mime type ─────────────────────────────────────────────────────────────

  static String mimeTypeFor(String filename) {
    return lookupMimeType(filename) ?? 'application/octet-stream';
  }

  // ── Size formatting ───────────────────────────────────────────────────────

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '— KB/s';
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  // ── Storage check ─────────────────────────────────────────────────────────

  /// Returns available bytes on the filesystem containing [directory].
  /// Returns null if unavailable (non-Android or permission denied).
  static Future<int?> availableBytes(String directory) async {
    try {
      // StatFs is Android-only. Use dart:io's statvfs via Dart FFI
      // is complex; for now we use a best-effort approach via Directory stat.
      // A proper implementation would use a platform channel.
      // This is a placeholder that always returns null (safe — callers handle null).
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Temp file helpers ─────────────────────────────────────────────────────

  /// Returns all `.part` files in [directory].
  static Future<List<File>> listPartFiles(Directory directory) async {
    if (!await directory.exists()) return [];
    return directory
        .listSync()
        .whereType<File>()
        .where((f) => isPartFile(f.path))
        .toList();
  }
}
