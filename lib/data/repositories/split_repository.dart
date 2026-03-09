import 'package:isar/isar.dart';

import '../../domain/models/split_model.dart';
import '../local/database_service.dart';

/// Repository for managing split expenses.
///
/// Provides CRUD operations, settlement tracking, balance calculations
/// (who owes whom), and a real-time watch stream.
class SplitRepository {
  final DatabaseService _db;

  SplitRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new split and returns its auto-generated id.
  Future<int> add(SplitModel split) async {
    return _isar.writeTxn(() async {
      return _isar.splitModels.put(split);
    });
  }

  /// Updates an existing split in-place.
  Future<void> update(SplitModel split) async {
    await _isar.writeTxn(() async {
      await _isar.splitModels.put(split);
    });
  }

  /// Deletes a split by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.splitModels.delete(id);
    });
  }

  /// Retrieves a single split by id, or null if not found.
  Future<SplitModel?> getById(int id) async {
    return _isar.splitModels.get(id);
  }

  /// Returns all splits ordered by creation date (newest first).
  Future<List<SplitModel>> getAll() async {
    return _isar.splitModels
        .where()
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns all splits that are not yet fully settled.
  Future<List<SplitModel>> getUnsettled() async {
    return _isar.splitModels
        .where()
        .isFullySettledEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ── SETTLEMENT ───────────────────────────────────────────────────────────

  /// Marks a specific participant as settled within a split.
  ///
  /// If all participants are now settled, the split is automatically
  /// marked as fully settled.
  Future<void> settleParticipant(
    int splitId,
    String participantName,
  ) async {
    await _isar.writeTxn(() async {
      final split = await _isar.splitModels.get(splitId);
      if (split == null) return;

      // Find the participant and mark as settled
      final updatedParticipants = split.participants.map((p) {
        if (p.name.toLowerCase() == participantName.toLowerCase()) {
          p.isSettled = true;
        }
        return p;
      }).toList();

      split.participants = updatedParticipants;

      // Check if all participants are now settled
      final allSettled = split.participants.every((p) => p.isSettled);
      if (allSettled) {
        split.isFullySettled = true;
      }

      await _isar.splitModels.put(split);
    });
  }

  // ── BALANCE CALCULATIONS ─────────────────────────────────────────────────

  /// Calculates outstanding balances for each participant across all
  /// unsettled splits.
  ///
  /// Returns a map of participant name -> total amount they still owe.
  /// Positive values mean the participant owes money; negative values
  /// would indicate they are owed (though typically the "you" participant
  /// is tracked separately by the UI layer).
  Future<Map<String, double>> getBalances() async {
    final unsettled = await getUnsettled();
    final balances = <String, double>{};

    for (final split in unsettled) {
      for (final participant in split.participants) {
        if (!participant.isSettled) {
          balances[participant.name] =
              (balances[participant.name] ?? 0.0) + participant.amount;
        }
      }
    }

    return balances;
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire split collection for any changes.
  Stream<void> watchAll() {
    return _isar.splitModels.watchLazy();
  }
}
