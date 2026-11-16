import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/di/providers.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../domain/entities/remote_file.dart';
import '../../domain/repositories/download_repository.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepositoryImpl(ref.watch(dioProvider));
});

// Remote file list
final remoteFilesProvider = AsyncNotifierProvider<RemoteFilesNotifier, List<RemoteFile>>(
  RemoteFilesNotifier.new,
);

class RemoteFilesNotifier extends AsyncNotifier<List<RemoteFile>> {
  @override
  Future<List<RemoteFile>> build() async {
    return ref.watch(downloadRepositoryProvider).fetchFiles();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(downloadRepositoryProvider).fetchFiles(),
    );
  }

  Future<void> deleteFile(String fileName) async {
    await ref.read(downloadRepositoryProvider).deleteFile(fileName);
    await refresh();
  }
}

// Download screen state
class DownloadNotifier extends Notifier<DownloadScreenState> {
  @override
  DownloadScreenState build() => const DownloadScreenState();

  TransferManager get _manager => ref.read(transferManagerProvider);

  Future<String?> startDownload(RemoteFile file) async {
    // Build the local destination path and ensure the directory exists.
    final baseDir = await getApplicationDocumentsDirectory();
    final dlDir = p.join(baseDir.path, 'PosTransfer');
    await Directory(dlDir).create(recursive: true);
    final destPath = p.join(dlDir, file.originalName.isNotEmpty ? file.originalName : file.name);

    final transfer = _manager.enqueueDownload(
      remoteFileName: file.name,
      destinationPath: destPath,
      fileSize: file.size,
    );

    state = state.copyWith(
      activeIds: {...state.activeIds, transfer.id},
    );
    return transfer.id;
  }

  void removeActiveId(String id) {
    state = state.copyWith(
      activeIds: {...state.activeIds}..remove(id),
    );
  }
}

final downloadNotifierProvider =
    NotifierProvider<DownloadNotifier, DownloadScreenState>(DownloadNotifier.new);

class DownloadScreenState {
  const DownloadScreenState({this.activeIds = const {}});

  final Set<String> activeIds;

  DownloadScreenState copyWith({Set<String>? activeIds}) =>
      DownloadScreenState(activeIds: activeIds ?? this.activeIds);
}
