import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transfers/domain/entities/transfer_entity.dart';
import '../../features/transfers/presentation/providers/transfer_providers.dart';
import 'background_transfer_service.dart';
import 'notification_service.dart';

/// Invisible widget that sits at the app root and reacts to transfer state
/// changes — starting/stopping the foreground service and firing notifications.
///
/// Sits above the router so it is always alive regardless of which screen
/// is visible. This is how transfers survive screen navigation.
class TransferServiceObserver extends ConsumerStatefulWidget {
  const TransferServiceObserver({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TransferServiceObserver> createState() =>
      _TransferServiceObserverState();
}

class _TransferServiceObserverState
    extends ConsumerState<TransferServiceObserver> {
  final _notif = NotificationService.instance;
  final _bg = BackgroundTransferService.instance;

  // Status tracking for lifecycle notifications (fired once per transition).
  final Map<String, TransferStatus> _lastStatus = {};

  // Per-transfer progress subscriptions for throttled progress notifications.
  final Map<String, StreamSubscription<TransferEntity>> _progressSubs = {};

  @override
  void dispose() {
    for (final sub in _progressSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Roster fires only on structural/status changes — not on every progress tick.
    ref.listen<AsyncValue<List<TransferEntity>>>(
      transferRosterProvider,
      (_, next) {
        final roster = next.valueOrNull ?? [];
        _onRosterChanged(roster);
      },
    );
    return widget.child;
  }

  void _onRosterChanged(List<TransferEntity> roster) {
    final active = roster.where((t) => t.isActive).toList();

    // 6.3/6.4 — Start/stop foreground service based on active count.
    if (active.isNotEmpty) {
      final first = active.firstWhere(
        (t) => t.status == TransferStatus.running,
        orElse: () => active.first,
      );
      final pct = (first.progress * 100).toInt();
      final statusText = first.status == TransferStatus.running
          ? '${first.fileName} — $pct%'
          : '${active.length} transfer${active.length == 1 ? '' : 's'} queued';
      _bg.startIfNeeded(activeCount: active.length, statusText: statusText);
    } else {
      _bg.stopIfIdle(0);
    }

    // 7.3 — Lifecycle notifications (started / completed / failed).
    for (final t in roster) {
      final prev = _lastStatus[t.id];
      if (prev != t.status) {
        _lastStatus[t.id] = t.status;
        _fireLifecycleNotification(t, prev);
      }
    }

    // 7.1 — Subscribe to progress updates for newly running transfers.
    final runningIds =
        active.where((t) => t.status == TransferStatus.running).map((t) => t.id).toSet();

    // Cancel subs for transfers no longer running.
    final toRemove = _progressSubs.keys
        .where((id) => !runningIds.contains(id))
        .toList();
    for (final id in toRemove) {
      _progressSubs.remove(id)?.cancel();
    }

    // Add subs for new running transfers.
    for (final id in runningIds) {
      if (_progressSubs.containsKey(id)) continue;
      final manager = ref.read(transferManagerProvider);
      _progressSubs[id] = manager.watch(id).listen((t) {
        if (t.status != TransferStatus.running) return;
        final pct = (t.progress * 100).toInt();
        // 7.4 — Throttling is handled inside notifyUploadProgress/notifyDownloadProgress.
        if (t.type == TransferType.upload) {
          _notif.notifyUploadProgress(t.id, t.fileName, pct);
        } else {
          _notif.notifyDownloadProgress(t.id, t.fileName, pct);
        }
      });
    }

    // Clean up tracking for removed transfers.
    final allIds = roster.map((t) => t.id).toSet();
    _lastStatus.removeWhere((id, _) => !allIds.contains(id));
  }

  // 7.3 + 7.5 — Lifecycle notifications fire immediately (no throttle).
  void _fireLifecycleNotification(TransferEntity t, TransferStatus? prev) {
    final isUpload = t.type == TransferType.upload;
    switch (t.status) {
      case TransferStatus.running:
        // Only fire "started" on the first transition into running.
        if (prev == null ||
            prev == TransferStatus.queued ||
            prev == TransferStatus.preparing) {
          isUpload
              ? _notif.notifyUploadStarted(t.id, t.fileName)
              : _notif.notifyDownloadStarted(t.id, t.fileName);
        }
      case TransferStatus.completed:
        // 7.5 — Always immediate.
        isUpload
            ? _notif.notifyUploadCompleted(t.id, t.fileName)
            : _notif.notifyDownloadCompleted(
                t.id, t.fileName, t.destinationPath);
      case TransferStatus.failed:
        // 7.5 — Always immediate.
        final reason = t.errorMessage ?? 'Unknown error';
        isUpload
            ? _notif.notifyUploadFailed(t.id, t.fileName, reason)
            : _notif.notifyDownloadFailed(t.id, t.fileName, reason);
      case TransferStatus.cancelled:
        _notif.cancel(t.id);
      default:
        break;
    }
  }
}
