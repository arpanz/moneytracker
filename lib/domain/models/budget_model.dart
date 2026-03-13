/// Represents a spending budget for a specific category.
class BudgetModel {
  int id;

  String category;

  double limitAmount;

  /// 0 = weekly, 1 = monthly, 2 = yearly
  int period;

  DateTime startDate;

  bool isActive;

  DateTime createdAt;

  BudgetModel({
    this.id = 0,
    this.category = '',
    this.limitAmount = 0.0,
    this.period = 1,
    DateTime? startDate,
    this.isActive = true,
    DateTime? createdAt,
  })  : startDate = startDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();
}
