import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../downloads/domain/entities/download_executor.dart';
import '../../../downloads/presentation/providers/download_providers.dart';
import '../../../uploads/domain/entities/upload_executor.dart';
import '../../../uploads/presentation/providers/upload_providers.dart';
import '../../data/repositories/transfer_repository_impl.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_manager.dart';
import '../../domain/repositories/transfer_repository.dart';

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  return TransferRepositoryImpl(ref.watch(localDatabaseServiceProvider));
});

// Manager (single, lifecycle-independent, NOT autoDispose)

final transferManagerProvider = Provider<TransferManager>((ref) {
  final manager = TransferManager(
    repository: ref.watch(transferRepositoryProvider),
    config: ref.watch(transferConfigProvider),
  );

  final uploadExecutor = UploadExecutor(
    repository: ref.watch(uploadRepositoryProvider),
    manager: manager,
    config: ref.watch(transferConfigProvider),
  );
  manager.uploadExecutor = uploadExecutor.call;

  // Wire download executor (Phase 5).
  final downloadExecutor = DownloadExecutor(
    repository: ref.watch(downloadRepositoryProvider),
    manager: manager,
    config: ref.watch(transferConfigProvider),
  );
  manager.downloadExecutor = downloadExecutor.call;

  ref.onDispose(manager.dispose);
  // Restore persisted state once on creation. Runs async; streams populate
  // the UI when it completes. This keeps the manager decoupled from main.dart.
  manager.restore();
  return manager;
});

// Per-transfer isolated stream

final transferProvider =
    StreamProvider.family<TransferEntity, String>((ref, id) {
  final manager = ref.watch(transferManagerProvider);
  return manager.watch(id);
});

// Global roster
//
// Emits the full list but ONLY on structural / status changes — never on
// progress ticks. The dashboard watches this to build the list + counts
// without rebuilding on every progress callback.

final transferRosterProvider = StreamProvider<List<TransferEntity>>((ref) {
  final manager = ref.watch(transferManagerProvider);
  return manager.watchAll();
});

// Derived lists / counts (read from roster → rebuild on status change only)

final activeTransfersProvider = Provider<List<TransferEntity>>((ref) {
  final roster = ref.watch(transferRosterProvider).valueOrNull ?? const [];
  return roster.where((t) => t.isActive).toList();
});

final queuedTransfersProvider = Provider<List<TransferEntity>>((ref) {
  final roster = ref.watch(transferRosterProvider).valueOrNull ?? const [];
  return roster.where((t) => t.status == TransferStatus.queued).toList();
});

final completedTransfersProvider = Provider<List<TransferEntity>>((ref) {
  final roster = ref.watch(transferRosterProvider).valueOrNull ?? const [];
  return roster
      .where((t) => t.status == TransferStatus.completed)
      .toList();
});

final failedTransfersProvider = Provider<List<TransferEntity>>((ref) {
  final roster = ref.watch(transferRosterProvider).valueOrNull ?? const [];
  return roster.where((t) => t.status == TransferStatus.failed).toList();
});

/// Aggregate counts for the dashboard header.
final transferCountsProvider = Provider<TransferCounts>((ref) {
  final roster = ref.watch(transferRosterProvider).valueOrNull ?? const [];
  return TransferCounts.from(roster);
});

class TransferCounts {
  const TransferCounts({
    required this.active,
    required this.queued,
    required this.paused,
    required this.completed,
    required this.failed,
    required this.total,
  });

  final int active;
  final int queued;
  final int paused;
  final int completed;
  final int failed;
  final int total;

  factory TransferCounts.from(List<TransferEntity> roster) {
    var active = 0, queued = 0, paused = 0, completed = 0, failed = 0;
    for (final t in roster) {
      switch (t.status) {
        case TransferStatus.queued:
          queued++;
          active++;
          break;
        case TransferStatus.preparing:
        case TransferStatus.running:
          active++;
          break;
        case TransferStatus.paused:
          paused++;
          active++;
          break;
        case TransferStatus.completed:
          completed++;
          break;
        case TransferStatus.failed:
          failed++;
          break;
        case TransferStatus.cancelled:
          break;
      }
    }
    return TransferCounts(
      active: active,
      queued: queued,
      paused: paused,
      completed: completed,
      failed: failed,
      total: roster.length,
    );
  }
}
