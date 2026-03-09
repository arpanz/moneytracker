import 'package:isar/isar.dart';

import '../../domain/models/goal_model.dart';
import '../local/database_service.dart';

/// Repository for managing savings goals and their contributions.
///
/// Provides CRUD operations, active/completed filtering, contribution
/// tracking, and a real-time watch stream.
class GoalRepository {
  final DatabaseService _db;

  GoalRepository(this._db);

  Isar get _isar => _db.isar;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Inserts a new goal and returns its auto-generated id.
  Future<int> add(GoalModel goal) async {
    return _isar.writeTxn(() async {
      return _isar.goalModels.put(goal);
    });
  }

  /// Updates an existing goal in-place.
  Future<void> update(GoalModel goal) async {
    await _isar.writeTxn(() async {
      await _isar.goalModels.put(goal);
    });
  }

  /// Deletes a goal by its id.
  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.goalModels.delete(id);
    });
  }

  /// Retrieves a single goal by id, or null if not found.
  Future<GoalModel?> getById(int id) async {
    return _isar.goalModels.get(id);
  }

  /// Returns all goals ordered by creation date (newest first).
  Future<List<GoalModel>> getAll() async {
    return _isar.goalModels
        .where()
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ── FILTERED QUERIES ─────────────────────────────────────────────────────

  /// Returns all goals that are not yet completed.
  Future<List<GoalModel>> getActive() async {
    return _isar.goalModels
        .where()
        .isCompletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Returns all goals that have been completed.
  Future<List<GoalModel>> getCompleted() async {
    return _isar.goalModels
        .where()
        .isCompletedEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();
  }

  // ── CONTRIBUTIONS ────────────────────────────────────────────────────────

  /// Adds a monetary contribution to a goal.
  ///
  /// Updates [currentAmount], appends the contribution to the list,
  /// and auto-marks the goal as completed if the target is reached.
  Future<void> addContribution(
    int goalId,
    double amount, {
    String? note,
  }) async {
    await _isar.writeTxn(() async {
      final goal = await _isar.goalModels.get(goalId);
      if (goal == null) return;

      final contribution = GoalContribution()
        ..amount = amount
        ..date = DateTime.now()
        ..note = note;

      goal.contributions = [...goal.contributions, contribution];
      goal.currentAmount += amount;

      // Auto-complete when target is reached
      if (goal.currentAmount >= goal.targetAmount) {
        goal.isCompleted = true;
      }

      await _isar.goalModels.put(goal);
    });
  }

  // ── AGGREGATES ────────────────────────────────────────────────────────────

  /// Calculates the total saved across all active (non-completed) goals.
  Future<double> getTotalSaved() async {
    final goals = await getActive();
    return goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount);
  }

  // ── REAL-TIME STREAM ─────────────────────────────────────────────────────

  /// Watches the entire goal collection for any changes.
  Stream<void> watchAll() {
    return _isar.goalModels.watchLazy();
  }
}
