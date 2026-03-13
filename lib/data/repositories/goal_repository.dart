import 'package:drift/drift.dart';

import '../../domain/models/goal_model.dart';
import '../local/database_service.dart';

/// Repository for managing savings goals.
class GoalRepository {
  final DatabaseService _db;

  GoalRepository(this._db);

  AppDatabase get _d => _db.db;

  // ── Mapping ──────────────────────────────────────────────────────────────

  GoalModel _fromRow(Goal row) => GoalModel(
        id: row.id,
        name: row.name,
        targetAmount: row.targetAmount,
        currentAmount: row.currentAmount,
        deadline: row.deadline,
        icon: row.icon,
        color: row.color,
        linkedAccountId: row.linkedAccountId,
        isCompleted: row.isCompleted,
        createdAt: row.createdAt,
        contributions: GoalContribution.listFromJson(row.contributions),
      );

  GoalsCompanion _toCompanion(GoalModel g) => GoalsCompanion.insert(
        name: g.name,
        targetAmount: g.targetAmount,
        currentAmount: Value(g.currentAmount),
        deadline: Value(g.deadline),
        icon: Value(g.icon),
        color: Value(g.color),
        linkedAccountId: Value(g.linkedAccountId),
        isCompleted: Value(g.isCompleted),
        createdAt: g.createdAt,
        contributions: Value(GoalContribution.listToJson(g.contributions)),
      );

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<int> add(GoalModel goal) =>
      _d.into(_d.goals).insert(_toCompanion(goal));

  Future<void> update(GoalModel goal) async {
    await (_d.update(_d.goals)..where((g) => g.id.equals(goal.id)))
        .write(GoalsCompanion(
      name: Value(goal.name),
      targetAmount: Value(goal.targetAmount),
      currentAmount: Value(goal.currentAmount),
      deadline: Value(goal.deadline),
      icon: Value(goal.icon),
      color: Value(goal.color),
      linkedAccountId: Value(goal.linkedAccountId),
      isCompleted: Value(goal.isCompleted),
      contributions: Value(GoalContribution.listToJson(goal.contributions)),
    ));
  }

  Future<void> delete(int id) async {
    await (_d.delete(_d.goals)..where((g) => g.id.equals(id))).go();
  }

  Future<GoalModel?> getById(int id) async {
    final row = await (_d.select(_d.goals)..where((g) => g.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<GoalModel>> getAll() async {
    final rows = await (_d.select(_d.goals)
          ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<GoalModel>> getActive() async {
    final rows = await (_d.select(_d.goals)
          ..where((g) => g.isCompleted.equals(false)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> addContribution(
    int goalId,
    double amount, {
    String? note,
  }) async {
    final goal = await getById(goalId);
    if (goal == null) return;
    final contribution = GoalContribution(
      amount: amount,
      date: DateTime.now(),
      note: note,
    );
    final updated = [...goal.contributions, contribution];
    final newAmount = goal.currentAmount + amount;
    final isCompleted = newAmount >= goal.targetAmount;
    await (_d.update(_d.goals)..where((g) => g.id.equals(goalId))).write(
      GoalsCompanion(
        currentAmount: Value(newAmount),
        isCompleted: Value(isCompleted),
        contributions: Value(GoalContribution.listToJson(updated)),
      ),
    );
  }

  Future<double> getTotalSaved() async {
    final goals = await getAll();
    double total = 0.0;
    for (var g in goals) {
      total += g.currentAmount;
    }
    return total;
  }

  Stream<void> watchAll() =>
      _d.select(_d.goals).watch().map((_) {});
}
