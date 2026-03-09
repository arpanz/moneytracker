import 'package:isar/isar.dart';

part 'goal_model.g.dart';

/// Embedded object representing a single contribution toward a goal.
@embedded
class GoalContribution {
  late double amount;
  late DateTime date;
  String? note;

  GoalContribution();
}

/// Represents a savings goal with tracked contributions.
@collection
class GoalModel {
  Id id = Isar.autoIncrement;

  late String name;

  late double targetAmount;

  late double currentAmount;

  DateTime? deadline;

  /// FontAwesome icon name (e.g. 'piggy-bank', 'plane').
  late String icon;

  /// Color value stored as int.
  late int color;

  /// Optional link to an account for automatic tracking.
  String? linkedAccountId;

  @Index()
  late bool isCompleted;

  late DateTime createdAt;

  late List<GoalContribution> contributions;

  /// Computed progress as a fraction (0.0 to 1.0+).
  @ignore
  double get progress =>
      targetAmount > 0 ? currentAmount / targetAmount : 0.0;

  GoalModel()
      : currentAmount = 0.0,
        icon = 'piggy-bank',
        color = 0xFF7C3AED,
        isCompleted = false,
        contributions = [],
        createdAt = DateTime.now();
}
