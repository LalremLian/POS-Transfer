import '../entities/transfer_entity.dart';

abstract class TransferRepository {
  List<TransferEntity> loadAll();
  Future<void> save(TransferEntity transfer);
  Future<void> saveAll(List<TransferEntity> transfers);
  Future<void> delete(String id);
  Future<void> clearTerminal();
}
