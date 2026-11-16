import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/providers.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../transfers/domain/entities/transfer_manager.dart';
import '../../../transfers/presentation/providers/transfer_providers.dart';
import '../../data/repositories/upload_repository_impl.dart';
import '../../domain/repositories/upload_repository.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepositoryImpl(ref.watch(dioProvider));
});

// Upload screen state
class UploadSelection {
  const UploadSelection({
    this.filePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.activeTransferId,
    this.isPicking = false,
    this.error,
  });

  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? activeTransferId;
  final bool isPicking;
  final String? error;

  bool get hasSelection => filePath != null && fileName != null;

  UploadSelection copyWith({
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? activeTransferId,
    bool? isPicking,
    String? error,
    bool clearError = false,
    bool clearSelection = false,
    bool clearActiveTransfer = false,
  }) {
    return UploadSelection(
      filePath: clearSelection ? null : (filePath ?? this.filePath),
      fileName: clearSelection ? null : (fileName ?? this.fileName),
      fileSize: clearSelection ? null : (fileSize ?? this.fileSize),
      mimeType: clearSelection ? null : (mimeType ?? this.mimeType),
      activeTransferId: clearActiveTransfer
          ? null
          : (activeTransferId ?? this.activeTransferId),
      isPicking: isPicking ?? this.isPicking,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UploadNotifier extends Notifier<UploadSelection> {
  @override
  UploadSelection build() => const UploadSelection();

  TransferManager get _manager => ref.read(transferManagerProvider);

  Future<void> pickFile() async {
    state = state.copyWith(isPicking: true, clearError: true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        state = state.copyWith(isPicking: false);
        return;
      }
      final f = result.files.first;
      if (f.path == null) {
        state = state.copyWith(
          isPicking: false,
          error: 'Could not read the selected file',
        );
        return;
      }
      state = state.copyWith(
        filePath: f.path,
        fileName: f.name,
        fileSize: f.size,
        mimeType: FileUtils.mimeTypeFor(f.name),
        isPicking: false,
        clearActiveTransfer: true,
        clearError: true,
      );
    } catch (_) {
      state = state.copyWith(
        isPicking: false,
        error: 'Could not pick a file',
      );
    }
  }

  /// Start the upload. Returns the transfer id (also stored in state).
  String? startUpload() {
    if (!state.hasSelection) {
      state = state.copyWith(error: 'Pick a file first');
      return null;
    }
    final transfer = _manager.enqueueUpload(
      localFilePath: state.filePath!,
      fileName: state.fileName!,
      fileSize: state.fileSize ?? 0,
    );
    state = state.copyWith(
      activeTransferId: transfer.id,
      clearError: true,
    );
    return transfer.id;
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelection: true,
      clearActiveTransfer: true,
      clearError: true,
    );
  }

  void clearActive() {
    state = state.copyWith(clearActiveTransfer: true, clearError: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final uploadNotifierProvider =
    NotifierProvider<UploadNotifier, UploadSelection>(UploadNotifier.new);
