import '../../../../core/services/local_database_service.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/repositories/transfer_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  TransferRepositoryImpl(this._db);

  final LocalDatabaseService _db;

  @override
  List<TransferEntity> loadAll() {
    return _db.loadAllTransfers().map(TransferEntity.fromJson).toList();
  }

  @override
  Future<void> save(TransferEntity transfer) async {
    final all = _db.loadAllTransfers();
    final idx = all.indexWhere((m) => m['id'] == transfer.id);
    final map = transfer.toJson();
    if (idx >= 0) {
      all[idx] = map;
    } else {
      all.add(map);
    }
    await _db.saveAllTransfers(all);
  }

  @override
  Future<void> saveAll(List<TransferEntity> transfers) async {
    await _db.saveAllTransfers(transfers.map((t) => t.toJson()).toList());
  }

  @override
  Future<void> delete(String id) async {
    final all = _db.loadAllTransfers()..removeWhere((m) => m['id'] == id);
    await _db.saveAllTransfers(all);
  }

  /// Removes completed + cancelled entries. Keeps failed ones so the user can still retry them.
  @override
  Future<void> clearTerminal() async {
    final all = _db.loadAllTransfers()
      ..removeWhere(
        (m) =>
            m['status'] == TransferStatus.completed.name ||
            m['status'] == TransferStatus.cancelled.name,
      );
    await _db.saveAllTransfers(all);
  }
}
