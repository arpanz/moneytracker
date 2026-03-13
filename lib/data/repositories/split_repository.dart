import 'package:drift/drift.dart';

import '../../domain/models/split_model.dart';
import '../local/database_service.dart';

/// Repository for managing bill splits.
class SplitRepository {
  final DatabaseService _db;

  SplitRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  SplitModel _fromRow(Split row) => SplitModel(
        id: row.id,
        transactionId: row.transactionId,
        description: row.description,
        totalAmount: row.totalAmount,
        splitMethod: row.splitMethod,
        participants: SplitParticipant.listFromJson(row.participants),
        isFullySettled: row.isFullySettled,
        createdAt: row.createdAt,
      );

  SplitsCompanion _toCompanion(SplitModel s) => SplitsCompanion.insert(
        transactionId: Value(s.transactionId),
        description: s.description,
        totalAmount: s.totalAmount,
        splitMethod: Value(s.splitMethod),
        participants: Value(SplitParticipant.listToJson(s.participants)),
        isFullySettled: Value(s.isFullySettled),
        createdAt: s.createdAt,
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(SplitModel split) =>
      _d.into(_d.splits).insert(_toCompanion(split));

  Future<void> update(SplitModel split) async {
    await (_d.update(_d.splits)..where((s) => s.id.equals(split.id)))
        .write(SplitsCompanion(
      transactionId: Value(split.transactionId),
      description: Value(split.description),
      totalAmount: Value(split.totalAmount),
      splitMethod: Value(split.splitMethod),
      participants: Value(SplitParticipant.listToJson(split.participants)),
      isFullySettled: Value(split.isFullySettled),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.splits)..where((s) => s.id.equals(id))).go();
  }

  Future<SplitModel?> getById(int id) async {
    final row = await (_d.select(_d.splits)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<SplitModel>> getAll() async {
    final rows = await (_d.select(_d.splits)
          ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<SplitModel>> getUnsettled() async {
    final rows = await (_d.select(_d.splits)
          ..where((s) => s.isFullySettled.equals(false)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Stream<void> watchAll() =>
      _d.select(_d.splits).watch().map((_) {});
}
