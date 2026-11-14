import 'dart:async';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/transfer/transfer_config.dart';
import 'transfer_entity.dart';
import 'transfer_queue.dart';
import '../repositories/transfer_repository.dart';

final _log = Logger();

typedef TransferExecutor = Future<void> Function(TransferEntity transfer);

class TransferManager {
  TransferManager({
    required TransferRepository repository,
    TransferConfig config = transferConfig,
  })  : _repo = repository,
        _config = config,
        _queue = TransferQueue(maxConcurrent: config.maxConcurrentTransfers);

  final TransferRepository _repo;
  final TransferConfig _config;
  final TransferQueue _queue;

  // Source of truth
  final Map<String, TransferEntity> _transfers = {};

  // Per-transfer streams (isolated state)
  final Map<String, StreamController<TransferEntity>> _controllers = {};

  // Roster stream (IDs / status / counts — NOT progress)
  final StreamController<List<TransferEntity>> _rosterController =
      StreamController<List<TransferEntity>>.broadcast();

  // Throttle bookkeeping
  final Map<String, DateTime> _lastUiEmit = {};
  final Map<String, DateTime> _lastPersist = {};

  // Executor hooks
  TransferExecutor? uploadExecutor;
  TransferExecutor? downloadExecutor;

  // Cancel hooks (Phase 4/5) — lets pause/cancel abort an in-flight request
  final Map<String, void Function()> _cancelCallbacks = {};

  // Streams the UI subscribes to

  /// Isolated stream for a single transfer (3.6). Yields the current value first,
  /// then every throttled update for THIS transfer only.
  Stream<TransferEntity> watch(String id) async* {
    final current = _transfers[id];
    if (current != null) yield current;
    yield* _ensureController(id).stream;
  }

  /// Global list stream (3.7). Emits only on structural / status changes, never
  /// on progress ticks, so the dashboard doesn't rebuild per-progress.
  Stream<List<TransferEntity>> watchAll() async* {
    yield _snapshot();
    yield* _rosterController.stream;
  }

  // Queries

  TransferEntity? get(String id) => _transfers[id];
  List<TransferEntity> get all => _snapshot();
  List<TransferEntity> get active =>
      _snapshot().where((t) => t.isActive).toList();

  List<TransferEntity> _snapshot() {
    final list = _transfers.values.toList();
    list.sort((a, b) {
      final at = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at); // newest first
    });
    return list;
  }

  // Restore on startup

  Future<void> restore() async {
    final persisted = _repo.loadAll();
    for (final t in persisted) {
      _transfers[t.id] = _reconcileOnStartup(t);
    }
    // Re-queue anything that was still queued when the app died.
    for (final t in _transfers.values) {
      if (t.status == TransferStatus.queued) {
        _queue.enqueuePending(t.id);
      }
    }
    _emitRoster();
    _tryStartNext();
    _log.i('Restored ${persisted.length} transfers '
        '(${_queue.pendingCount} re-queued)');
  }

  /// A transfer left running/preparing when the process died cannot be resumed
  /// (the HTTP request is gone). Mark it failed — never completed. Queued and
  /// paused states survive intact; queued ones are re-queued above.
  TransferEntity _reconcileOnStartup(TransferEntity t) {
    if (t.status == TransferStatus.running ||
        t.status == TransferStatus.preparing) {
      final failed = t.copyWith(
        status: TransferStatus.failed,
        errorMessage: 'Interrupted by app restart',
        completedAt: DateTime.now(),
      );
      _repo.save(failed);
      return failed;
    }
    return t;
  }

  // Enqueue (public API for the upload/download features)

  /// Enqueue an upload. Returns the transfer. If an active transfer for the same
  /// local file already exists, returns that one (duplicate prevention, 3.8).
  TransferEntity enqueueUpload({
    required String localFilePath,
    required String fileName,
    required int fileSize,
    String? destinationPath,
  }) {
    final dup = _findDuplicate(
      TransferType.upload,
      localFilePath: localFilePath,
    );
    if (dup != null) return dup;

    final entity = _create(
      type: TransferType.upload,
      fileName: fileName,
      fileSize: fileSize,
      localFilePath: localFilePath,
      destinationPath: destinationPath,
    );
    _startLifecycle(entity);
    return entity;
  }

  /// Enqueue a download. Duplicate prevention on remote filename + destination.
  TransferEntity enqueueDownload({
    required String remoteFileName,
    required String destinationPath,
    required int fileSize,
    String? localFilePath,
  }) {
    final dup = _findDuplicate(
      TransferType.download,
      remoteFileName: remoteFileName,
      destinationPath: destinationPath,
    );
    if (dup != null) return dup;

    final entity = _create(
      type: TransferType.download,
      fileName: remoteFileName,
      fileSize: fileSize,
      remoteFileName: remoteFileName,
      destinationPath: destinationPath,
      localFilePath: localFilePath,
    );
    _startLifecycle(entity);
    return entity;
  }

  TransferEntity _create({
    required TransferType type,
    required String fileName,
    required int fileSize,
    String? remoteFileName,
    String? localFilePath,
    String? destinationPath,
  }) {
    return TransferEntity(
      id: const Uuid().v4(),
      fileName: fileName,
      fileSize: fileSize,
      totalBytes: fileSize,
      type: type,
      status: TransferStatus.queued,
      startedAt: DateTime.now(),
      remoteFileName: remoteFileName,
      localFilePath: localFilePath,
      destinationPath: destinationPath,
    );
  }

  void _startLifecycle(TransferEntity entity) {
    _transfers[entity.id] = entity;
    _queue.enqueuePending(entity.id);
    _persistImmediate(entity);
    _emitTransfer(entity); // immediate — creation is a lifecycle change
    _emitRoster();
    _tryStartNext();
  }

  // Duplicate prevention

  TransferEntity? _findDuplicate(
    TransferType type, {
    String? localFilePath,
    String? remoteFileName,
    String? destinationPath,
  }) {
    for (final t in _transfers.values) {
      if (!t.isActive || t.type != type) continue;
      if (type == TransferType.upload && t.localFilePath == localFilePath) {
        return t;
      }
      if (type == TransferType.download &&
          t.remoteFileName == remoteFileName &&
          t.destinationPath == destinationPath) {
        return t;
      }
    }
    return null;
  }

  // Concurrency scheduling

  void _tryStartNext() {
    while (_queue.hasCapacity) {
      final id = _queue.pendingIds.isEmpty ? null : _queue.pendingIds.first;
      if (id == null) break;
      final transfer = _transfers[id]!;
      final executor = transfer.type == TransferType.upload
          ? uploadExecutor
          : downloadExecutor;
      // No executor registered yet (Phase 3) → leave it queued. Nothing runs
      // and no progress is faked. Phase 4/5 assigns the executors.
      if (executor == null) break;
      _queue.occupyNext();
      _setStatus(id, TransferStatus.preparing);
      _execute(transfer, executor);
    }
  }

  Future<void> _execute(TransferEntity transfer, TransferExecutor executor) async {
    try {
      await executor(transfer);
    } catch (e, s) {
      _log.e('Transfer ${transfer.id} executor threw', error: e, stackTrace: s);
      // Backstop: only fail if the executor didn't already resolve the status
      // (e.g. it threw before calling markCompleted/markFailed).
      final current = _transfers[transfer.id];
      if (current != null &&
          (current.status == TransferStatus.preparing ||
              current.status == TransferStatus.running)) {
        markFailed(transfer.id, 'Transfer failed unexpectedly');
      }
    } finally {
      unregisterCancelCallback(transfer.id);
    }
  }

  // Actions

  /// Pause a running transfer (cancels the in-flight request via the hook,
  /// keeps the partial file/metadata). Queued transfers are removed from the
  /// pending list. Resume restarts uploads from zero (backend has no resumable
  /// upload); downloads resume from the last byte.
  Future<void> pause(String id) async {
    final t = _transfers[id];
    if (t == null) return;
    if (t.status == TransferStatus.preparing ||
        t.status == TransferStatus.running) {
      _cancelCallbacks[id]?.call();
      _setStatus(id, TransferStatus.paused);
      _releaseSlot(id);
    } else if (t.status == TransferStatus.queued) {
      _queue.removeFromPending(id);
      _setStatus(id, TransferStatus.paused);
    }
    _tryStartNext();
  }

  Future<void> resume(String id) async {
    final t = _transfers[id];
    if (t == null || t.status != TransferStatus.paused) return;
    _setStatus(id, TransferStatus.queued);
    _queue.enqueuePending(id);
    _emitRoster();
    _tryStartNext();
  }

  Future<void> cancel(String id) async {
    final t = _transfers[id];
    if (t == null) return;
    if (t.status == TransferStatus.preparing ||
        t.status == TransferStatus.running) {
      _cancelCallbacks[id]?.call();
    }
    _queue.removeFromPending(id);
    _releaseSlot(id);
    _setStatus(
      id,
      TransferStatus.cancelled,
      errorMessage: 'Cancelled by user',
    );
    _tryStartNext();
  }

  /// Retry a failed/cancelled transfer. Resets progress and re-queues.
  Future<void> retry(String id) async {
    final t = _transfers[id];
    if (t == null) return;
    if (t.status != TransferStatus.failed &&
        t.status != TransferStatus.cancelled) {
      return;
    }
    final retried = t.copyWith(
      status: TransferStatus.queued,
      retryCount: t.retryCount + 1,
      errorMessage: null,
      transferredBytes: 0,
      speedBytesPerSec: 0,
      completedAt: null,
      startedAt: DateTime.now(),
    );
    _transfers[id] = retried;
    _persistImmediate(retried);
    _emitTransfer(retried);
    _queue.enqueuePending(id);
    _emitRoster();
    _tryStartNext();
  }

  /// Remove a terminal transfer from history. No-op for active transfers.
  Future<void> removeCompleted(String id) async {
    final t = _transfers[id];
    if (t == null || !t.isTerminal) return;
    _transfers.remove(id);
    await _repo.delete(id);
    _controllers[id]?.add(t.copyWith()); // let watchers see removal via roster
    _controllers[id]?.close();
    _controllers.remove(id);
    _lastUiEmit.remove(id);
    _lastPersist.remove(id);
    _emitRoster();
  }

  Future<void> clearAllTerminal() async {
    final toRemove =
        _transfers.values.where((t) => t.isTerminal).map((t) => t.id).toList();
    for (final id in toRemove) {
      _transfers.remove(id);
      _controllers[id]?.close();
      _controllers.remove(id);
      _lastUiEmit.remove(id);
      _lastPersist.remove(id);
    }
    await _repo.clearTerminal();
    _emitRoster();
  }

  // Progress reporting

  /// Update progress for a running transfer. Throttles UI emission (500 ms)
  /// and persistence (5 s) so frequent Dio callbacks don't flood Riverpod or
  /// the database. Status changes always emit immediately (use _setStatus).
  void updateProgress(
    String id, {
    required int transferredBytes,
    int? totalBytes,
    double? speedBytesPerSec,
  }) {
    final t = _transfers[id];
    if (t == null) return;
    final updated = t.copyWith(
      transferredBytes: transferredBytes,
      totalBytes: totalBytes ?? t.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? t.speedBytesPerSec,
    );
    _transfers[id] = updated;

    final now = DateTime.now();
    final lastUi = _lastUiEmit[id];
    if (lastUi == null ||
        now.difference(lastUi) >=
            Duration(milliseconds: _config.uiProgressIntervalMs)) {
      _lastUiEmit[id] = now;
      _emitTransfer(updated);
    }
    _maybePersist(updated);
  }

  // Public state mutators

  /// Mark a transfer as actively running (preparing → running).
  void markRunning(String id) {
    final t = _transfers[id];
    if (t == null) return;
    if (t.status != TransferStatus.preparing &&
        t.status != TransferStatus.queued &&
        t.status != TransferStatus.running) {
      return;
    }
    final updated = t.copyWith(status: TransferStatus.running);
    _transfers[id] = updated;
    _lastUiEmit[id] = DateTime.now();
    _emitTransfer(updated);
    _persistImmediate(updated);
    _emitRoster();
  }

  /// Mark a transfer completed. Saves remote file info + releases the slot.
  void markCompleted(
    String id, {
    String? remoteFileName,
    int? remoteFileSize,
    String? localChecksum,
  }) {
    final t = _transfers[id];
    if (t == null) return;
    // Use actualSize as the authoritative byte count so progress always
    // shows 100% — the header totalBytes can differ slightly from actual.
    final finalSize = (remoteFileSize != null && remoteFileSize > 0)
        ? remoteFileSize
        : (t.totalBytes > 0 ? t.totalBytes : t.transferredBytes);
    final updated = t.copyWith(
      status: TransferStatus.completed,
      remoteFileName: remoteFileName ?? t.remoteFileName,
      totalBytes: finalSize,
      transferredBytes: finalSize, // always 100%
      speedBytesPerSec: 0,
      localChecksum: localChecksum ?? t.localChecksum,
      completedAt: DateTime.now(),
    );
    _transfers[id] = updated;
    _lastUiEmit[id] = DateTime.now();
    _emitTransfer(updated); // immediate — completion is a lifecycle change
    _persistImmediate(updated);
    _emitRoster();
    _releaseSlot(id);
    _tryStartNext();
  }

  /// Mark a transfer permanently failed. Releases the slot.
  void markFailed(String id, String errorMessage) {
    final t = _transfers[id];
    if (t == null) return;
    if (t.isTerminal) return; // already resolved
    final updated = t.copyWith(
      status: TransferStatus.failed,
      errorMessage: errorMessage,
      completedAt: DateTime.now(),
      speedBytesPerSec: 0,
    );
    _transfers[id] = updated;
    _lastUiEmit[id] = DateTime.now();
    _emitTransfer(updated);
    _persistImmediate(updated);
    _emitRoster();
    _releaseSlot(id);
    _tryStartNext();
  }

  /// Bump the retry counter during automatic backoff retry. Keeps status
  /// running so the UI can show "Retrying (n/3)…".
  void markRetrying(String id) {
    final t = _transfers[id];
    if (t == null) return;
    final updated = t.copyWith(
      status: TransferStatus.running,
      retryCount: t.retryCount + 1,
      speedBytesPerSec: 0,
    );
    _transfers[id] = updated;
    _lastUiEmit[id] = DateTime.now();
    _emitTransfer(updated);
    _persistImmediate(updated);
    _emitRoster();
  }

  // Internal state mutators

  void _setStatus(String id, TransferStatus status, {String? errorMessage}) {
    final t = _transfers[id];
    if (t == null) return;
    final isTerminalChange = status == TransferStatus.completed ||
        status == TransferStatus.failed ||
        status == TransferStatus.cancelled;
    final updated = t.copyWith(
      status: status,
      errorMessage: errorMessage,
      completedAt: isTerminalChange ? DateTime.now() : t.completedAt,
    );
    _transfers[id] = updated;
    _lastUiEmit[id] = DateTime.now();
    _emitTransfer(updated); // status changes are always immediate
    _persistImmediate(updated);
    _emitRoster(); // status changes are structural → roster re-groups
  }

  void _releaseSlot(String id) {
    _queue.release(id);
  }

  // Persistence

  /// Immediate write — used for creation, status changes, terminal results.
  void _persistImmediate(TransferEntity t) {
    _lastPersist[t.id] = DateTime.now();
    _repo.save(t);
  }

  /// Throttled write — used during progress. Writes at most once per
  /// `metadataPersistIntervalMs`. Always preserves the latest known state.
  void _maybePersist(TransferEntity t) {
    final now = DateTime.now();
    final last = _lastPersist[t.id];
    if (last == null ||
        now.difference(last) >=
            Duration(milliseconds: _config.metadataPersistIntervalMs)) {
      _lastPersist[t.id] = now;
      _repo.save(t);
    }
  }

  // Stream emission

  StreamController<TransferEntity> _ensureController(String id) {
    return _controllers.putIfAbsent(
      id,
      () => StreamController<TransferEntity>.broadcast(),
    );
  }

  void _emitTransfer(TransferEntity t) {
    _ensureController(t.id).add(t);
  }

  void _emitRoster() {
    if (!_rosterController.isClosed) {
      _rosterController.add(_snapshot());
    }
  }

  // Cancel hook registration

  void registerCancelCallback(String id, void Function() cancel) =>
      _cancelCallbacks[id] = cancel;

  void unregisterCancelCallback(String id) => _cancelCallbacks.remove(id);

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    _rosterController.close();
  }
}
