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

// Manager
final transferManagerProvider = Provider<TransferManager>((ref) {
  final manager = TransferManager(
    repository: ref.watch(transferRepositoryProvider),
    config: ref.watch(transferConfigProvider),
  );

  // Wire upload executor.
  final uploadExecutor = UploadExecutor(
    repository: ref.watch(uploadRepositoryProvider),
    manager: manager,
    config: ref.watch(transferConfigProvider),
  );
  manager.uploadExecutor = uploadExecutor.call;

  // Wire download executor.
  final downloadExecutor = DownloadExecutor(
    repository: ref.watch(downloadRepositoryProvider),
    manager: manager,
    config: ref.watch(transferConfigProvider),
  );
  manager.downloadExecutor = downloadExecutor.call;

  ref.onDispose(manager.dispose);
  manager.restore();
  return manager;
});

// Per-transfer isolated stream
final transferProvider =
    StreamProvider.family<TransferEntity, String>((ref, id) {
  return ref.watch(transferManagerProvider).watch(id);
});

// Global roster
final transferRosterProvider = StreamProvider<List<TransferEntity>>((ref) {
  return ref.watch(transferManagerProvider).watchAll();
});

// Derived counts
final activeTransfersProvider = Provider<List<TransferEntity>>((ref) {
  return (ref.watch(transferRosterProvider).valueOrNull ?? [])
      .where((t) => t.isActive)
      .toList();
});

final completedTransfersProvider = Provider<List<TransferEntity>>((ref) {
  return (ref.watch(transferRosterProvider).valueOrNull ?? [])
      .where((t) => t.status == TransferStatus.completed)
      .toList();
});

final failedTransfersProvider = Provider<List<TransferEntity>>((ref) {
  return (ref.watch(transferRosterProvider).valueOrNull ?? [])
      .where((t) => t.status == TransferStatus.failed)
      .toList();
});

final transferCountsProvider = Provider<TransferCounts>((ref) {
  return TransferCounts.from(
      ref.watch(transferRosterProvider).valueOrNull ?? []);
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

  final int active, queued, paused, completed, failed, total;

  factory TransferCounts.from(List<TransferEntity> roster) {
    var active = 0, queued = 0, paused = 0, completed = 0, failed = 0;
    for (final t in roster) {
      switch (t.status) {
        case TransferStatus.queued:
          queued++;
          active++;
        case TransferStatus.preparing:
        case TransferStatus.running:
          active++;
        case TransferStatus.paused:
          paused++;
          active++;
        case TransferStatus.completed:
          completed++;
        case TransferStatus.failed:
          failed++;
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

// Connectivity status provider
final connectivityStatusProvider = StateProvider<bool>((ref) {
  return true;
});
