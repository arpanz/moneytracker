import 'package:isar/isar.dart';

part 'budget_model.g.dart';

/// Represents a spending budget for a specific category.
@collection
class BudgetModel {
  Id id = Isar.autoIncrement;

  @Index()
  late String category;

  late double limitAmount;

  /// 0 = weekly, 1 = monthly, 2 = yearly
  late int period;

  late DateTime startDate;

  late bool isActive;

  late DateTime createdAt;

  /// Composite index on [category, period] for unique budget lookups.
  @Index(composite: [CompositeIndex('period')])
  String get compositeCategoryPeriod => category;

  BudgetModel()
      : period = 1,
        isActive = true,
        createdAt = DateTime.now();
}
