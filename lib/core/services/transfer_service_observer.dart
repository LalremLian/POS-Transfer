import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transfers/domain/entities/transfer_entity.dart';
import '../../features/transfers/presentation/providers/transfer_providers.dart';
import '../../app/di/providers.dart';
import 'background_transfer_service.dart';
import 'notification_service.dart';

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

  final Map<String, TransferStatus> _lastStatus = {};
  final Map<String, StreamSubscription<TransferEntity>> _progressSubs = {};

  // connectivity
  StreamSubscription<bool>? _connectivitySub;
  bool _wasOnline = true;

  @override
  void initState() {
    super.initState();
    _startConnectivityMonitoring();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    for (final sub in _progressSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  // Connectivity
  void _startConnectivityMonitoring() {
    final networkInfo = ref.read(networkInfoProvider);

    // Set initial state.
    networkInfo.isConnected.then((online) {
      _wasOnline = online;
      if (mounted) {
        ref.read(connectivityStatusProvider.notifier).state = online;
      }
    });

    _connectivitySub = networkInfo.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      ref.read(connectivityStatusProvider.notifier).state = online;

      if (!online && _wasOnline) {
        // Went offline: pause all running transfers.
        _onWentOffline();
      } else if (online && !_wasOnline) {
        // Back online: resume paused transfers that were auto-paused.
        _onBackOnline();
      }
      _wasOnline = online;
    });
  }

  void _onWentOffline() {
    final manager = ref.read(transferManagerProvider);
    final roster = ref.read(transferRosterProvider).valueOrNull ?? [];
    for (final t in roster) {
      if (t.status == TransferStatus.running ||
          t.status == TransferStatus.preparing) {
        // Tag the transfer so we know we auto-paused it (not the user).
        _autoPausedIds.add(t.id);
        manager.pause(t.id);
      }
    }
  }

  void _onBackOnline() {
    final manager = ref.read(transferManagerProvider);
    // Resume only transfers that WE auto-paused, not user-paused ones.
    for (final id in List<String>.from(_autoPausedIds)) {
      _autoPausedIds.remove(id);
      manager.resume(id);
    }
  }

  // Track which transfers were auto-paused by connectivity loss.
  final Set<String> _autoPausedIds = {};

  // Roster changes
  @override
  Widget build(BuildContext context) {
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

    // Start/stop foreground service.
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

    // Phase 7.3 — Lifecycle notifications.
    for (final t in roster) {
      final prev = _lastStatus[t.id];
      if (prev != t.status) {
        _lastStatus[t.id] = t.status;
        _fireLifecycleNotification(t, prev);
      }
    }

    // Progress subscriptions for running transfers.
    final runningIds = active
        .where((t) => t.status == TransferStatus.running)
        .map((t) => t.id)
        .toSet();

    final toRemove =
        _progressSubs.keys.where((id) => !runningIds.contains(id)).toList();
    for (final id in toRemove) {
      _progressSubs.remove(id)?.cancel();
    }

    for (final id in runningIds) {
      if (_progressSubs.containsKey(id)) continue;
      final manager = ref.read(transferManagerProvider);
      _progressSubs[id] = manager.watch(id).listen((t) {
        if (t.status != TransferStatus.running) return;
        final pct = (t.progress * 100).toInt();
        if (t.type == TransferType.upload) {
          _notif.notifyUploadProgress(t.id, t.fileName, pct);
        } else {
          _notif.notifyDownloadProgress(t.id, t.fileName, pct);
        }
      });
    }

    // Clean up tracking & cancel notifications for removed transfers.
    final allIds = roster.map((t) => t.id).toSet();
    final removedIds =
        _lastStatus.keys.where((id) => !allIds.contains(id)).toList();
    for (final id in removedIds) {
      _lastStatus.remove(id);
      _notif.cancel(id);
    }
    _autoPausedIds.removeWhere((id) => !allIds.contains(id));
  }

  // Lifecycle notifications fire immediately (no throttle).
  void _fireLifecycleNotification(TransferEntity t, TransferStatus? prev) {
    final isUpload = t.type == TransferType.upload;
    switch (t.status) {
      case TransferStatus.running:
        if (prev == null ||
            prev == TransferStatus.queued ||
            prev == TransferStatus.preparing) {
          isUpload
              ? _notif.notifyUploadStarted(t.id, t.fileName)
              : _notif.notifyDownloadStarted(t.id, t.fileName);
        }
      case TransferStatus.completed:
        isUpload
            ? _notif.notifyUploadCompleted(t.id, t.fileName)
            : _notif.notifyDownloadCompleted(
                t.id, t.fileName, t.destinationPath);
      case TransferStatus.failed:
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
